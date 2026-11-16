#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
SKU_NOAUTH="CV10A-${SUFFIX}"
SKU_FORGED="CV10B-${SUFFIX}"
FORGED_TOKEN="eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJzdWIiOiJhdHRhY2tlciJ9.forged${SUFFIX}"
lc() { printf '%s' "$1" | tr 'A-Z' 'a-z'; }

# Given
cv_step Given "snapshot the catalog before the unauthenticated attempts" $LINENO
cv_http GET "/api/products?limit=1"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 listing catalog got $CV_HTTP_STATUS" $LINENO
TOTAL_BEFORE=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.total')
[ -n "$TOTAL_BEFORE" ] && [ "$TOTAL_BEFORE" != "null" ] || cv_fail "expected numeric total in catalog list got $CV_HTTP_BODY" $LINENO
BODY_A=$(jq -nc --arg sku "$SKU_NOAUTH" '{sku:$sku,name:"Unauth product",priceCents:100,stock:1}')
BODY_B=$(jq -nc --arg sku "$SKU_FORGED" '{sku:$sku,name:"Forged session product",priceCents:100,stock:1}')

# When
cv_step When "add products with no session and with a forged session" $LINENO
cv_http POST /api/products "$BODY_A"
STATUS_NOAUTH="$CV_HTTP_STATUS"
cv_http POST /api/products "$BODY_B" -H "Authorization: Bearer ${FORGED_TOKEN}" -H "Cookie: session=forged${SUFFIX}"
STATUS_FORGED="$CV_HTTP_STATUS"

# Then
cv_step Then "both attempts refused and the catalog is unchanged" $LINENO
cv_http GET "/api/products?q=$(lc "$SKU_NOAUTH")&limit=100"
N_A=$(printf '%s' "$CV_HTTP_BODY" | jq -r --arg s "$SKU_NOAUTH" '[.data[] | select(.sku == $s)] | length')
cv_http GET "/api/products?q=$(lc "$SKU_FORGED")&limit=100"
N_B=$(printf '%s' "$CV_HTTP_BODY" | jq -r --arg s "$SKU_FORGED" '[.data[] | select(.sku == $s)] | length')
cv_http GET "/api/products?limit=1"
TOTAL_AFTER=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.total')
case "$STATUS_NOAUTH" in 2*) cv_fail "expected unauthenticated catalog add to be refused got HTTP $STATUS_NOAUTH (product created: $N_A)" $LINENO ;; esac
case "$STATUS_FORGED" in 2*) cv_fail "expected forged-session catalog add to be refused got HTTP $STATUS_FORGED (product created: $N_B)" $LINENO ;; esac
[ "$N_A" = "0" ] || cv_fail "expected no product $SKU_NOAUTH in catalog got $N_A" $LINENO
[ "$N_B" = "0" ] || cv_fail "expected no product $SKU_FORGED in catalog got $N_B" $LINENO
[ "$TOTAL_AFTER" = "$TOTAL_BEFORE" ] || cv_fail "expected catalog total $TOTAL_BEFORE unchanged got $TOTAL_AFTER" $LINENO

# Cleanup
cv_step Cleanup "remove any product the refused attempts created" $LINENO
for S in "$SKU_NOAUTH" "$SKU_FORGED"; do
  cv_http GET "/api/products?q=$(lc "$S")&limit=100"
  for ID in $(printf '%s' "$CV_HTTP_BODY" | jq -r --arg s "$S" '.data[]? | select(.sku == $s) | .id'); do
    cv_http DELETE "/api/products/$ID"
  done
done

echo "CODEVALID_TEST_ASSERTION_OK:api_18522127_10"
