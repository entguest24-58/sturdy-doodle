#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
# The app defines no sign-in mechanism (no auth routes or middleware in src/), so the
# "signed-in user" is a plain API client: there is no credential to obtain.
SUFFIX="$(date +%s%N)"
SKU="CVADD${SUFFIX}"
NAME="CV Added Product ${SUFFIX}"
DESC="Added by api_79506978_1"
PRICE=4599
ID=""

# Given
cv_step Given "a product code not yet in the catalog" $LINENO
cv_http GET "/api/products?q=${SKU}&limit=100" 200
PRE=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.total')
[ "$PRE" = "0" ] || cv_fail "expected product code ${SKU} unused before the test got total=$PRE" $LINENO

# When
cv_step When "the user submits name, description, price and product code" $LINENO
cv_http POST /api/products "$(jq -nc --arg s "$SKU" --arg n "$NAME" --arg d "$DESC" --argjson p "$PRICE" '{sku:$s,name:$n,description:$d,priceCents:$p}')"
CREATE_STATUS="$CV_HTTP_STATUS"; CREATE_BODY="$CV_HTTP_BODY"
ID=$(printf '%s' "$CREATE_BODY" | jq -r '.id // empty' 2>/dev/null || true)

# Then
cv_step Then "the product is saved, listed in the catalog and opens by id with the submitted values" $LINENO
[ "$CREATE_STATUS" = "201" ] || cv_fail "expected 201 creating product got $CREATE_STATUS: $(printf '%s' "$CREATE_BODY" | head -c 300)" $LINENO
[ -n "$ID" ] || cv_fail "expected id in create response got none" $LINENO
cv_http GET "/api/products?q=${SKU}&limit=100" 200
N=$(printf '%s' "$CV_HTTP_BODY" | jq -r --arg id "$ID" '[.data[] | select(.id == $id)] | length')
[ "$N" = "1" ] || cv_fail "expected the new product once in the catalog list got $N" $LINENO
LISTED=$(printf '%s' "$CV_HTTP_BODY" | jq -c --arg id "$ID" '.data[] | select(.id == $id) | {sku,name,description,priceCents}')
EXP=$(jq -nc --arg s "$SKU" --arg n "$NAME" --arg d "$DESC" --argjson p "$PRICE" '{sku:$s,name:$n,description:$d,priceCents:$p}')
[ "$LISTED" = "$EXP" ] || cv_fail "expected listed product $EXP got $LISTED" $LINENO
cv_http GET "/api/products/${ID}" 200
GOT=$(printf '%s' "$CV_HTTP_BODY" | jq -c '{sku,name,description,priceCents}')
[ "$GOT" = "$EXP" ] || cv_fail "expected product by id $EXP got $GOT" $LINENO

# Cleanup
cv_step Cleanup "delete the created product" $LINENO
[ -n "$ID" ] && cv_http DELETE "/api/products/${ID}"

echo "CODEVALID_TEST_ASSERTION_OK:api_79506978_1"
