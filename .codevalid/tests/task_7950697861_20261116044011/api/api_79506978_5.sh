#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
SKU="CVONE${SUFFIX}"
NAME="CV Single ${SUFFIX}"
DESC="Opened by id"
PRICE=1299
ID=""

# Given
cv_step Given "a saved product exists" $LINENO
cv_http POST /api/products "$(jq -nc --arg s "$SKU" --arg n "$NAME" --arg d "$DESC" --argjson p "$PRICE" '{sku:$s,name:$n,description:$d,priceCents:$p}')"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 creating product got $CV_HTTP_STATUS" $LINENO
ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
[ -n "$ID" ] || cv_fail "expected id in create response got none" $LINENO

# When
cv_step When "a visitor without credentials opens the product by its id" $LINENO
cv_http GET "/api/products/${ID}"
S="$CV_HTTP_STATUS"; BODY="$CV_HTTP_BODY"

# Then
cv_step Then "the product's name, description, price and code are returned" $LINENO
[ "$S" = "200" ] || cv_fail "expected 200 opening product anonymously got $S" $LINENO
GOT=$(printf '%s' "$BODY" | jq -c '{id,sku,name,description,priceCents}')
EXP=$(jq -nc --arg id "$ID" --arg s "$SKU" --arg n "$NAME" --arg d "$DESC" --argjson p "$PRICE" '{id:$id,sku:$s,name:$n,description:$d,priceCents:$p}')
[ "$GOT" = "$EXP" ] || cv_fail "expected $EXP got $GOT" $LINENO

# Cleanup
cv_step Cleanup "delete the created product" $LINENO
cv_http DELETE "/api/products/${ID}"

echo "CODEVALID_TEST_ASSERTION_OK:api_79506978_5"
