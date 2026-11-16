#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
SKU="CVADD${SUFFIX}"
EMAIL="cvadd.${SUFFIX}@example.com"
ID=""; CUSTOMER_ID=""

# Given
# The code defines no sign-in route or auth middleware; the user is registered as a customer
# (the only account the app has) and the product code is checked to be unused.
cv_step Given "a registered user and a product code not yet in use" $LINENO
cv_http POST /api/customers "$(jq -nc --arg e "$EMAIL" '{firstName:"Cv",lastName:"Adder",email:$e}')"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 registering user got $CV_HTTP_STATUS" $LINENO
CUSTOMER_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
cv_http GET "/api/products?q=${SKU}&limit=100"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 pre-checking product code got $CV_HTTP_STATUS" $LINENO
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.total')" = "0" ] || cv_fail "expected product code unused got total $(printf '%s' "$CV_HTTP_BODY" | jq -r '.total')" $LINENO

# When
cv_step When "the user adds a product with name, description, price and code" $LINENO
cv_http POST /api/products "$(jq -nc --arg s "$SKU" '{sku:$s,name:"CV Added Product",description:"added by user",priceCents:1299}')"

# Then
cv_step Then "the product is in the list and opens by id with the given values" $LINENO
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 adding product got $CV_HTTP_STATUS: $(printf '%s' "$CV_HTTP_BODY" | head -c 300)" $LINENO
ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
[ -n "$ID" ] || cv_fail "expected product id in create response got none" $LINENO
cv_http GET "/api/products?q=${SKU}&limit=100"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 listing products got $CV_HTTP_STATUS" $LINENO
N=$(printf '%s' "$CV_HTTP_BODY" | jq -r --arg id "$ID" '[.data[] | select(.id == $id)] | length')
[ "$N" = "1" ] || cv_fail "expected new product in product list got $N" $LINENO
cv_http GET "/api/products/${ID}"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 opening product got $CV_HTTP_STATUS" $LINENO
B="$CV_HTTP_BODY"
[ "$(printf '%s' "$B" | jq -r '.name')" = "CV Added Product" ] || cv_fail "expected name 'CV Added Product' got $(printf '%s' "$B" | jq -r '.name')" $LINENO
[ "$(printf '%s' "$B" | jq -r '.description')" = "added by user" ] || cv_fail "expected description 'added by user' got $(printf '%s' "$B" | jq -r '.description')" $LINENO
[ "$(printf '%s' "$B" | jq -r '.priceCents')" = "1299" ] || cv_fail "expected priceCents 1299 got $(printf '%s' "$B" | jq -r '.priceCents')" $LINENO
[ "$(printf '%s' "$B" | jq -r '.sku')" = "$SKU" ] || cv_fail "expected sku $SKU got $(printf '%s' "$B" | jq -r '.sku')" $LINENO

# Cleanup
cv_step Cleanup "delete the product and the user" $LINENO
[ -n "$ID" ] && cv_http DELETE "/api/products/${ID}"
[ -n "$CUSTOMER_ID" ] && cv_http DELETE "/api/customers/${CUSTOMER_ID}"

echo "CODEVALID_TEST_ASSERTION_OK:api_32075139_3"
