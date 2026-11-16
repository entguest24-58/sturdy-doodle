#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
SKU="CVDUP${SUFFIX}"
EMAIL="cvdup.${SUFFIX}@example.com"
ID=""; CUSTOMER_ID=""; DUP_ID=""

# Given
# The code defines no sign-in route; the user is registered as a customer (the only account type).
cv_step Given "a registered user and an existing product holding the code" $LINENO
cv_http POST /api/customers "$(jq -nc --arg e "$EMAIL" '{firstName:"Cv",lastName:"Dup",email:$e}')"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 registering user got $CV_HTTP_STATUS" $LINENO
CUSTOMER_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
cv_http POST /api/products "$(jq -nc --arg s "$SKU" '{sku:$s,name:"CV Original",description:"original",priceCents:500}')"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 creating original product got $CV_HTTP_STATUS" $LINENO
ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
[ -n "$ID" ] || cv_fail "expected original product id got none" $LINENO

# When
cv_step When "the user adds another product with the same code" $LINENO
cv_http POST /api/products "$(jq -nc --arg s "$SKU" '{sku:$s,name:"CV Duplicate",description:"duplicate",priceCents:700}')"
DUP_STATUS="$CV_HTTP_STATUS"; DUP_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "the add is refused and only one product holds the code" $LINENO
DUP_ID=$(printf '%s' "$DUP_BODY" | jq -r '.id // empty' 2>/dev/null || true)
case "$DUP_STATUS" in 4??) ;; *) cv_fail "expected 4xx refusing duplicate product code got $DUP_STATUS" $LINENO ;; esac
cv_http GET "/api/products?q=${SKU}&limit=100"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 listing products got $CV_HTTP_STATUS" $LINENO
N=$(printf '%s' "$CV_HTTP_BODY" | jq -r --arg s "$SKU" '[.data[] | select(.sku == $s)] | length')
[ "$N" = "1" ] || cv_fail "expected exactly 1 product with code $SKU got $N" $LINENO
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r --arg s "$SKU" '.data[] | select(.sku == $s) | .id')" = "$ID" ] || cv_fail "expected the original product to hold the code" $LINENO
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r --arg s "$SKU" '.data[] | select(.sku == $s) | .name')" = "CV Original" ] || cv_fail "expected original product name unchanged" $LINENO

# Cleanup
cv_step Cleanup "delete the products and the user" $LINENO
[ -n "$ID" ] && cv_http DELETE "/api/products/${ID}"
[ -n "$DUP_ID" ] && cv_http DELETE "/api/products/${DUP_ID}"
[ -n "$CUSTOMER_ID" ] && cv_http DELETE "/api/customers/${CUSTOMER_ID}"

echo "CODEVALID_TEST_ASSERTION_OK:api_32075139_4"
