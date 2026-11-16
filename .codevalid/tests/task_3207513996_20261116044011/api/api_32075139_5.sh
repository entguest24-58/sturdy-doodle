#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
SKU="CVANON${SUFFIX}"
NEW_ID=""

# Given
cv_step Given "an anonymous visitor and a product code not in the catalog" $LINENO
cv_http GET "/api/products?q=${SKU}&limit=100"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 pre-checking catalog got $CV_HTTP_STATUS" $LINENO
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.total')" = "0" ] || cv_fail "expected code unused before the attempt" $LINENO

# When
cv_step When "the visitor without credentials tries to add a product" $LINENO
cv_http POST /api/products "$(jq -nc --arg s "$SKU" '{sku:$s,name:"CV Anonymous",description:"anonymous add",priceCents:100}')"
ADD_STATUS="$CV_HTTP_STATUS"; ADD_BODY="$CV_HTTP_BODY"
NEW_ID=$(printf '%s' "$ADD_BODY" | jq -r '.id // empty' 2>/dev/null || true)

# Then
cv_step Then "the add is refused and the product is not in the list" $LINENO
cv_http GET "/api/products?q=${SKU}&limit=100"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 listing products got $CV_HTTP_STATUS" $LINENO
N=$(printf '%s' "$CV_HTTP_BODY" | jq -r --arg s "$SKU" '[.data[] | select(.sku == $s)] | length')
if [ "$N" != "0" ]; then
  # remove the leaked product before failing
  [ -n "$NEW_ID" ] && cv_http DELETE "/api/products/${NEW_ID}"
  cv_fail "expected anonymous add refused and product absent; got HTTP $ADD_STATUS and $N product(s) with code $SKU in the public list (id $NEW_ID)" $LINENO
fi
case "$ADD_STATUS" in 2??) cv_fail "expected anonymous add refused got $ADD_STATUS" $LINENO ;; esac

# Cleanup
cv_step Cleanup "remove anything the attempt created" $LINENO
[ -n "$NEW_ID" ] && cv_http DELETE "/api/products/${NEW_ID}" || true

echo "CODEVALID_TEST_ASSERTION_OK:api_32075139_5"
