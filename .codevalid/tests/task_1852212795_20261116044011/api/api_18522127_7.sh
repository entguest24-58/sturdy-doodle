#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
SKU="CV7-${SUFFIX}"
NAME="Browse product ${SUFFIX}"
PRODUCT_ID=""

# Given
cv_step Given "a product exists in the catalog" $LINENO
cv_prereq "create a catalog product" $LINENO
BODY=$(jq -nc --arg sku "$SKU" --arg name "$NAME" '{sku:$sku,name:$name,priceCents:1999,currency:"USD",stock:5,category:"cv-browse"}')
cv_http POST /api/products "$BODY"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 creating catalog product got $CV_HTTP_STATUS" $LINENO
PRODUCT_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
[ -n "$PRODUCT_ID" ] || cv_fail "expected product id in create response got none" $LINENO

# When
cv_step When "visitor with no session browses the catalog" $LINENO
cv_http GET "/api/products?q=$(printf '%s' "$SKU" | tr 'A-Z' 'a-z')&limit=100"

# Then
cv_step Then "catalog contents are returned to the anonymous visitor" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected HTTP 200 browsing catalog without session got $CV_HTTP_STATUS" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e '.data | type == "array"' >/dev/null || cv_fail "expected catalog list in .data got $CV_HTTP_BODY" $LINENO
FOUND=$(printf '%s' "$CV_HTTP_BODY" | jq -r --arg id "$PRODUCT_ID" '[.data[] | select(.id == $id)] | length')
[ "$FOUND" = "1" ] || cv_fail "expected product $PRODUCT_ID in browsed catalog got $FOUND matches" $LINENO
GOT_NAME=$(printf '%s' "$CV_HTTP_BODY" | jq -r --arg id "$PRODUCT_ID" '.data[] | select(.id == $id) | .name')
[ "$GOT_NAME" = "$NAME" ] || cv_fail "expected product name '$NAME' got '$GOT_NAME'" $LINENO

# Cleanup
cv_step Cleanup "delete the catalog product" $LINENO
cv_http DELETE "/api/products/$PRODUCT_ID"

echo "CODEVALID_TEST_ASSERTION_OK:api_18522127_7"
