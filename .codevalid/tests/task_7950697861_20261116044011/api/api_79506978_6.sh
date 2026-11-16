#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
SKU="CVANON${SUFFIX}"
BODY=$(jq -nc --arg s "$SKU" '{sku:$s,name:"CV Anonymous Attempt",description:"should be blocked",priceCents:1500}')
NEW_ID=""
S=""

# Given
cv_step Given "a complete valid product with an unused code and a visitor with no credentials" $LINENO
cv_http GET "/api/products?q=${SKU}&limit=100" 200
PRE=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.total')
[ "$PRE" = "0" ] || cv_fail "expected code ${SKU} unused before the test got total=$PRE" $LINENO

# When
cv_step When "the anonymous visitor submits the product without signing in (no Authorization header, no cookie)" $LINENO
cv_http POST /api/products "$BODY"
S="$CV_HTTP_STATUS"
NEW_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty' 2>/dev/null || true)
echo "anonymous POST /api/products returned $S: $CV_HTTP_BODY"

# Then
cv_step Then "the submission is blocked, nothing is saved and the product is not in the catalog" $LINENO
cv_http GET "/api/products?q=${SKU}&limit=100" 200
T=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.total')
LISTED=$(printf '%s' "$CV_HTTP_BODY" | jq -c '[.data[] | {id,sku,name}]')
if [ -n "$NEW_ID" ]; then
  cv_http GET "/api/products/${NEW_ID}"
  [ "$CV_HTTP_STATUS" = "404" ] || cv_fail "expected anonymous product not saved, but GET /api/products/${NEW_ID} returned $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
fi
[ "$T" = "0" ] || cv_fail "expected anonymous product to be blocked, but POST returned $S and the catalog now lists it: $LISTED" $LINENO
case "$S" in 2??) cv_fail "expected anonymous submission to be blocked got $S" $LINENO ;; esac

# Cleanup
cv_step Cleanup "delete the product if it was saved anyway" $LINENO
if [ -n "$NEW_ID" ]; then cv_http DELETE "/api/products/${NEW_ID}" || true; fi

echo "CODEVALID_TEST_ASSERTION_OK:api_79506978_6"
