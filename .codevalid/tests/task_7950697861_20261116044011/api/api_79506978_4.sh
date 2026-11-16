#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
# The app defines no sign-in mechanism, so every client is effectively "not signed in";
# both catalog reads below are made without credentials.
SUFFIX="$(date +%s%N)"
TAG="CVCAT${SUFFIX}"
IDS=()

# Given
cv_step Given "the catalog holds three saved products with a unique code prefix" $LINENO
for i in 1 2 3; do
  cv_prereq "create product $i" $LINENO
  cv_http POST /api/products "$(jq -nc --arg s "${TAG}-${i}" --arg n "CV Catalog ${i}" --argjson p "$((i*1000))" '{sku:$s,name:$n,description:"catalog item",priceCents:$p}')"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 creating product $i got $CV_HTTP_STATUS" $LINENO
  PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
  [ -n "$PID" ] || cv_fail "expected id for product $i got none" $LINENO
  IDS+=("$PID")
done

# When
cv_step When "a visitor without credentials requests the full catalog, then requests it again" $LINENO
cv_http GET "/api/products?limit=100"
ANON_STATUS="$CV_HTTP_STATUS"; ANON_BODY="$CV_HTTP_BODY"
cv_http GET "/api/products?q=${TAG}&limit=100"
ANON_Q_STATUS="$CV_HTTP_STATUS"; ANON_Q_BODY="$CV_HTTP_BODY"
cv_http GET "/api/products?q=${TAG}&limit=100"
SECOND_STATUS="$CV_HTTP_STATUS"; SECOND_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "all saved products are returned and both reads return the same products" $LINENO
[ "$ANON_STATUS" = "200" ] || cv_fail "expected 200 for anonymous catalog got $ANON_STATUS" $LINENO
TOTAL=$(printf '%s' "$ANON_BODY" | jq -r '.total')
[ "$TOTAL" -ge 3 ] || cv_fail "expected catalog total >= 3 got $TOTAL" $LINENO
[ "$ANON_Q_STATUS" = "200" ] || cv_fail "expected 200 for anonymous filtered catalog got $ANON_Q_STATUS" $LINENO
for PID in "${IDS[@]}"; do
  printf '%s' "$ANON_Q_BODY" | jq -e --arg id "$PID" 'any(.data[]; .id == $id)' >/dev/null || cv_fail "expected product $PID in the anonymous catalog, missing" $LINENO
done
QT=$(printf '%s' "$ANON_Q_BODY" | jq -r '.total')
[ "$QT" = "3" ] || cv_fail "expected exactly 3 products with the tag got $QT" $LINENO
[ "$SECOND_STATUS" = "200" ] || cv_fail "expected 200 for second catalog read got $SECOND_STATUS" $LINENO
A=$(printf '%s' "$ANON_Q_BODY" | jq -c '[.data[].id] | sort')
B=$(printf '%s' "$SECOND_BODY" | jq -c '[.data[].id] | sort')
[ "$A" = "$B" ] || cv_fail "expected identical product sets across reads got $A vs $B" $LINENO

# Cleanup
cv_step Cleanup "delete the created products" $LINENO
for PID in "${IDS[@]}"; do cv_http DELETE "/api/products/${PID}"; done

echo "CODEVALID_TEST_ASSERTION_OK:api_79506978_4"
