#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
# No sign-in mechanism exists in the app; the submitting user is a plain API client.
SUFFIX="$(date +%s%N)"
SKU="CVDUP${SUFFIX}"
ORIG=$(jq -nc --arg s "$SKU" '{sku:$s,name:"CV Original",description:"original product",priceCents:2000}')
ID=""

# Given
cv_step Given "a product with a given code is already in the catalog" $LINENO
cv_http POST /api/products "$ORIG"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 creating original product got $CV_HTTP_STATUS" $LINENO
ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
[ -n "$ID" ] || cv_fail "expected id for original product got none" $LINENO
ORIG_VIEW=$(printf '%s' "$CV_HTTP_BODY" | jq -c '{id,sku,name,description,priceCents}')

# When
cv_step When "the user submits another product with the same code" $LINENO
cv_http POST /api/products "$(jq -nc --arg s "$SKU" '{sku:$s,name:"CV Duplicate",description:"duplicate product",priceCents:5000}')"
DUP_STATUS="$CV_HTTP_STATUS"; DUP_BODY="$CV_HTTP_BODY"
DUP_ID=$(printf '%s' "$DUP_BODY" | jq -r '.id // empty' 2>/dev/null || true)

# Then
cv_step Then "the submission is rejected and only the unchanged original holds that code" $LINENO
case "$DUP_STATUS" in 4??) ;; *) cv_fail "expected 4xx rejecting duplicate code got $DUP_STATUS" $LINENO ;; esac
cv_http GET "/api/products?q=${SKU}&limit=100" 200
MATCH=$(printf '%s' "$CV_HTTP_BODY" | jq -c --arg s "$SKU" '[.data[] | select(.sku == $s) | {id,sku,name,description,priceCents}]')
[ "$MATCH" = "[$ORIG_VIEW]" ] || cv_fail "expected only the original [$ORIG_VIEW] with code $SKU got $MATCH" $LINENO
cv_http GET "/api/products/${ID}" 200
NOW=$(printf '%s' "$CV_HTTP_BODY" | jq -c '{id,sku,name,description,priceCents}')
[ "$NOW" = "$ORIG_VIEW" ] || cv_fail "expected original unchanged $ORIG_VIEW got $NOW" $LINENO

# Cleanup
cv_step Cleanup "delete the created products" $LINENO
cv_http DELETE "/api/products/${ID}"
[ -n "$DUP_ID" ] && cv_http DELETE "/api/products/${DUP_ID}" || true

echo "CODEVALID_TEST_ASSERTION_OK:api_79506978_3"
