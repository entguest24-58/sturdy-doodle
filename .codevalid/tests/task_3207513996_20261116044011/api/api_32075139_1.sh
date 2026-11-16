#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
TAG="cvlist${SUFFIX}"
ID1=""; ID2=""

# Given
cv_step Given "the catalog holds two products tagged with a unique code prefix" $LINENO
cv_prereq "create product 1" $LINENO
cv_http POST /api/products "$(jq -nc --arg s "${TAG}-A" '{sku:$s,name:"CV List A",description:"first",priceCents:1000}')"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 creating product A got $CV_HTTP_STATUS" $LINENO
ID1=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
[ -n "$ID1" ] || cv_fail "expected id for product A got none" $LINENO
cv_prereq "create product 2" $LINENO
cv_http POST /api/products "$(jq -nc --arg s "${TAG}-B" '{sku:$s,name:"CV List B",description:"second",priceCents:2500}')"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 creating product B got $CV_HTTP_STATUS" $LINENO
ID2=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
[ -n "$ID2" ] || cv_fail "expected id for product B got none" $LINENO

# When
cv_step When "a visitor without credentials lists the products" $LINENO
cv_http GET "/api/products?limit=100"
LIST_STATUS="$CV_HTTP_STATUS"; LIST_BODY="$CV_HTTP_BODY"
cv_http GET "/api/products?q=${TAG}&limit=100"
Q_STATUS="$CV_HTTP_STATUS"; Q_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "the list is returned with no sign-in and contains both products" $LINENO
[ "$LIST_STATUS" = "200" ] || cv_fail "expected 200 listing products anonymously got $LIST_STATUS" $LINENO
printf '%s' "$LIST_BODY" | jq -e '.data | type == "array"' >/dev/null || cv_fail "expected .data array in list got: $(printf '%s' "$LIST_BODY" | head -c 300)" $LINENO
TOTAL=$(printf '%s' "$LIST_BODY" | jq -r '.total')
[ "$TOTAL" -ge 2 ] || cv_fail "expected total >= 2 got $TOTAL" $LINENO
[ "$Q_STATUS" = "200" ] || cv_fail "expected 200 listing filtered products got $Q_STATUS" $LINENO
N=$(printf '%s' "$Q_BODY" | jq -r --arg a "$ID1" --arg b "$ID2" '[.data[] | select(.id == $a or .id == $b)] | length')
[ "$N" = "2" ] || cv_fail "expected both created products in the list got $N" $LINENO
QT=$(printf '%s' "$Q_BODY" | jq -r '.total')
[ "$QT" = "2" ] || cv_fail "expected exactly 2 products with the unique tag got $QT" $LINENO

# Cleanup
cv_step Cleanup "delete the created products" $LINENO
cv_http DELETE "/api/products/${ID1}"
cv_http DELETE "/api/products/${ID2}"

echo "CODEVALID_TEST_ASSERTION_OK:api_32075139_1"
