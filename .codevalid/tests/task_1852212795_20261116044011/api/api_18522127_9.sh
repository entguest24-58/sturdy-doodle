#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="cv9.${SUFFIX}@example.com"
PASSWORD="S3cret-Pass-${SUFFIX}"
CUSTOMER_ID=""
# returns 0 when the body holds neither the password value nor a password/hash field
no_password() {
  if printf '%s' "$1" | grep -qF "$PASSWORD"; then return 1; fi
  if printf '%s' "$1" | jq -e '[.. | objects | keys[] | ascii_downcase | select(test("password|hash"))] | length > 0' >/dev/null 2>&1; then return 1; fi
  return 0
}

# Given
cv_step Given "register a customer account with email and password" $LINENO
BODY=$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{firstName:"Cv",lastName:"Nine",email:$e,password:$p}')
cv_http POST /api/customers "$BODY"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 registering customer got $CV_HTTP_STATUS" $LINENO
REG_BODY="$CV_HTTP_BODY"
CUSTOMER_ID=$(printf '%s' "$REG_BODY" | jq -r '.id // empty')
[ -n "$CUSTOMER_ID" ] || cv_fail "expected customer id in registration response got none" $LINENO

# When
cv_step When "another client reads the customer account data" $LINENO
cv_http GET "/api/customers?email=${EMAIL}&limit=100"
LIST_STATUS="$CV_HTTP_STATUS"; LIST_BODY="$CV_HTTP_BODY"
cv_http GET "/api/customers/${CUSTOMER_ID}"
ONE_STATUS="$CV_HTTP_STATUS"; ONE_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "password is absent from every account response" $LINENO
no_password "$REG_BODY" || cv_fail "expected no password in registration response got: $(printf '%s' "$REG_BODY" | head -c 300)" $LINENO
[ "$LIST_STATUS" = "200" ] || cv_fail "expected 200 listing customers got $LIST_STATUS" $LINENO
N=$(printf '%s' "$LIST_BODY" | jq -r --arg id "$CUSTOMER_ID" '[.data[] | select(.id == $id)] | length')
[ "$N" = "1" ] || cv_fail "expected registered customer in GET /api/customers got $N" $LINENO
no_password "$LIST_BODY" || cv_fail "expected no password in GET /api/customers got: $(printf '%s' "$LIST_BODY" | head -c 300)" $LINENO
[ "$ONE_STATUS" = "200" ] || cv_fail "expected 200 reading customer got $ONE_STATUS" $LINENO
no_password "$ONE_BODY" || cv_fail "expected no password in GET /api/customers/:id got: $(printf '%s' "$ONE_BODY" | head -c 300)" $LINENO

# Cleanup
cv_step Cleanup "delete the customer account" $LINENO
cv_http DELETE "/api/customers/${CUSTOMER_ID}"

echo "CODEVALID_TEST_ASSERTION_OK:api_18522127_9"
