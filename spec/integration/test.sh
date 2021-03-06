#!/bin/bash

# set -x

set -Euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
TEST_DIFF=""
OUTPUT=""
RECKON_CMD="env RUBYLIB=$SCRIPT_DIR/../../lib:$RUBYLIB reckon -v"

main () {
    trap test_fail EXIT

    if [[ $# -eq 1 ]]; then
        TESTS=$1/test_args
    else
        TESTS=$(find "$SCRIPT_DIR" -name 'test_args')
    fi

    echo > test.log

    for t in $TESTS; do
        OUTPUT_FILE=$(mktemp)
        TEST_DIR=$(dirname "$t")
        pushd "$TEST_DIR" >/dev/null || exit 1
        echo "$TEST_DIR Running..."
        TEST_CMD="$RECKON_CMD -o $OUTPUT_FILE $(cat test_args)"
        TEST_LOG=$(eval "$TEST_CMD" 2>&1)
        ERROR=0

        compare_output "$OUTPUT_FILE"

        popd >/dev/null || exit 1
        # have to save output after popd
        echo -e "\n\n======>$TEST_DIR" >> test.log
        echo -e "TEST_CMD\n$TEST_LOG" >> test.log

        if [[ $ERROR -ne 0 ]]; then
            exit 1
        fi
    done
}

test_fail () {
    STATUS=$?
    if [[ $STATUS -ne 0 ]]; then
        echo -e "FAILED!!!\n$TEST_DIFF\nTest output saved to $OUTPUT_FILE\n"
        exit $STATUS
    fi
}

compare_output_for () {
    OUTPUT_FILE=$1
    LEDGER=$2

    TEST_DIFF=$(diff -u <($LEDGER -f output.ledger r --date-format %F 2>&1) <($LEDGER -f "$OUTPUT_FILE" r --date-format %F 2>&1) )

    # ${#} is character length, test that there was no output from diff
    if [ ${#TEST_DIFF} -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

compare_output () {
    OUTPUT_FILE=$1

    for n in {ledger,hledger}; do
        echo -n "  - $n..."
        if compare_output_for "$OUTPUT_FILE" "$n"; then
            echo "SUCCESS!"
        else
            echo "FAILED!"
            ERROR=1
            return 0
        fi
    done
}

main "$@"
