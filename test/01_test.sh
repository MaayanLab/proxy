#!/bin/sh

TEST_BASE=http://localhost:10080

assert() {
  RESULT=$1
  EXPECTATION=$2
  DESCRIPTION=$3

  if [ "${RESULT}" != "${EXPECTATION}" ]; then
    echo "  ERROR: ${DESCRIPTION}"
    echo "    ${RESULT} != ${EXPECTATION}"
  else
    echo "  OK: ${DESCRIPTION}"
  fi
}

echo "Proxy fall through"
assert "$(curl -s ${TEST_BASE}/)" "02" "Proper content"
assert "$(curl -s ${TEST_BASE}/01/)" "01" "Proper content"
assert "$(curl -s ${TEST_BASE}/02/)" "02" "Proper content"
assert "$(curl -s ${TEST_BASE}/01/02/)" "02" "Proper content"
assert "$(curl -s ${TEST_BASE}/01/03/)" "03" "Proper content"
assert "$(curl -s ${TEST_BASE}/02/03/)" "03" "Proper content"

echo "Proxy catch, relative redirect, add slash"
assert "$(curl -so/dev/null ${TEST_BASE}/01 -w '%{http_code}')" "302" "HTTP code"
assert "$(curl -sL ${TEST_BASE}/01)" "01" "Proper content"

echo "Proxy catch, external add slash redirect"
assert "$(curl -so/dev/null ${TEST_BASE}/02 -w '%{http_code}')" "302" "HTTP code"
assert "$(curl -sL ${TEST_BASE}/02)" "02" "Proper content when following redirect"

echo "Proxy catch, relative multi-redirect, add slash regex"
assert "$(curl -so/dev/null ${TEST_BASE}/01 -w '%{http_code}')" "302" "HTTP code"
assert "$(curl -sL ${TEST_BASE}/01/02/03/02/)" "02" "Proper content"
