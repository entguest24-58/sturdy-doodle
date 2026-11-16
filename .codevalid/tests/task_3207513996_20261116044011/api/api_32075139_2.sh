#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
SKU="CVGET${SUFFIX}"
ID=""

# Given
cv_step Given "a product exists in the catalog" $LINENO
cv_http POST /api/products "$(jq -nc --arg s "$SKU" '{sku:$s,name:"CV Get Product",description:"single product detail",priceCents:4999}')"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 creating product got $CV_HTTP_STATUS" $LINENO
ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
[ -n "$ID" ] || cv_fail "expected product id got none" $LINENO

# When
cv_step When "a visitor without credentials opens the product by id" $LINENO
cv_http GET "/api/products/${ID}"

# Then
cv_step Then "the product's name, description, price and code are returned" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 opening product anonymously got $CV_HTTP_STATUS" $LINENO
B="$CV_HTTP_BODY"
[ "$(printf '%s' "$B" | jq -r '.id')" = "$ID" ] || cv_fail "expected id $ID got $(printf '%s' "$B" | jq -r '.id')" $LINENO
[ "$(printf '%s' "$B" | jq -r '.name')" = "CV Get Product" ] || cv_fail "expected name 'CV Get Product' got $(printf '%s' "$B" | jq -r '.name')" $LINENO
[ "$(printf '%s' "$B" | jq -r '.description')" = "single product detail" ] || cv_fail "expected description got $(printf '%s' "$B" | jq -r '.description')" $LINENO
[ "$(printf '%s' "$B" | jq -r '.priceCents')" = "4999" ] || cv_fail "expected priceCents 4999 got $(printf '%s' "$B" | jq -r '.priceCents')" $LINENO
[ "$(printf '%s' "$B" | jq -r '.sku')" = "$SKU" ] || cv_fail "expected sku $SKU got $(printf '%s' "$B" | jq -r '.sku')" $LINENO

# Cleanup
cv_step Cleanup "delete the product" $LINENO
cv_http DELETE "/api/products/${ID}"

echo "CODEVALID_TEST_ASSERTION_OK:api_32075139_2"
