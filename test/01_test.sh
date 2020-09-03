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

echo "Proxy basic_auth"
assert "$(curl -so/dev/null http://localhost:10081/ -w '%{http_code}')" "401" "Permission denied expected"
assert "$(curl -so/dev/null http://user:wrongpass@localhost:10081/ -w '%{http_code}')" "401" "Permission denied expected"
assert "$(curl -s http://user:pass@localhost:10081/)" "02" "Authenticated, proper content"

echo "Proxy fall through"
assert "$(curl -s ${TEST_BASE}/)" "02" "Proper content"
assert "$(curl -s ${TEST_BASE}/01/)" "01" "Proper content"
assert "$(curl -s ${TEST_BASE}/02/)" "02" "Proper content"
assert "$(curl -s ${TEST_BASE}/01/02/)" "02" "Proper content"
assert "$(curl -s ${TEST_BASE}/01/03/)" "03" "Proper content"
assert "$(curl -s ${TEST_BASE}/02/03/)" "03" "Proper content"

echo "Proxy catch, relative redirect, add slash"
assert "$(curl -so/dev/null ${TEST_BASE}/01 -w '%{http_code}')" "307" "HTTP code"
assert "$(curl -sL ${TEST_BASE}/01)" "01" "Proper content"

echo "Proxy catch, external add slash redirect"
assert "$(curl -so/dev/null ${TEST_BASE}/02 -w '%{http_code}')" "307" "HTTP code"
assert "$(curl -sL ${TEST_BASE}/02)" "02" "Proper content when following redirect"

echo "Proxy catch, relative multi-redirect, add slash regex"
assert "$(curl -so/dev/null ${TEST_BASE}/01 -w '%{http_code}')" "307" "HTTP code"
assert "$(curl -sL ${TEST_BASE}/01/02/03/02/)" "02" "Proper content"
