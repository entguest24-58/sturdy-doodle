#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
# No sign-in mechanism exists in the app; the submitting user is a plain API client.
SUFFIX="$(date +%s%N)"
TAG="CVMISS${SUFFIX}"
FULL=$(jq -nc --arg t "$TAG" '{name:("CV Missing " + $t),description:"incomplete",priceCents:999}')
FIELDS=(sku name description priceCents)
declare -A STATUS

# Given
cv_step Given "four submissions, each leaving out one of code, name, description or price" $LINENO
cv_http GET "/api/products?q=${TAG}&limit=100" 200
PRE=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.total')
[ "$PRE" = "0" ] || cv_fail "expected no products tagged ${TAG} before the test got $PRE" $LINENO

# When
cv_step When "the user submits each incomplete product" $LINENO
for f in "${FIELDS[@]}"; do
  BODY=$(printf '%s' "$FULL" | jq -c --arg s "${TAG}-${f}" --arg f "$f" '. + {sku:$s} | del(.[$f])')
  cv_http POST /api/products "$BODY"
  STATUS[$f]="$CV_HTTP_STATUS"
done

# Then
cv_step Then "no incomplete product is saved or shown in the catalog" $LINENO
cv_http GET "/api/products?q=${TAG}&limit=100" 200
LIST="$CV_HTTP_BODY"
SAVED=$(printf '%s' "$LIST" | jq -r '[.data[].id] | join(" ")')
for f in "${FIELDS[@]}"; do
  case "${STATUS[$f]}" in 4??) ;; *) cv_fail "expected 4xx rejecting a product without ${f} got ${STATUS[$f]} (saved ids: ${SAVED})" $LINENO ;; esac
done
T=$(printf '%s' "$LIST" | jq -r '.total')
[ "$T" = "0" ] || cv_fail "expected no incomplete products in the catalog got $T: $(printf '%s' "$LIST" | jq -c '[.data[] | {sku,name,description,priceCents}]')" $LINENO

# Cleanup
cv_step Cleanup "delete any product that was saved anyway" $LINENO
cv_http GET "/api/products?q=${TAG}&limit=100"
for id in $(printf '%s' "$CV_HTTP_BODY" | jq -r '.data[]?.id'); do cv_http DELETE "/api/products/${id}"; done

echo "CODEVALID_TEST_ASSERTION_OK:api_79506978_2"
