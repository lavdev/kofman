#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
TMP_DIR="$(mktemp -d /tmp/byte-eater-api-smoke.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

request() {
    local expected="$1"
    shift
    local body="$TMP_DIR/body"
    local status
    status="$(curl --silent --show-error --output "$body" --write-out '%{http_code}' "$@")"
    if [[ "$status" != "$expected" ]]; then
        echo "expected HTTP $expected, got $status"
        sed -n '1,80p' "$body"
        exit 1
    fi
    cat "$body"
}

health="$(request 200 "$BASE_URL/api/health")"
[[ "$health" == *'"ok": true'* ]]
[[ "$health" == *'"game": "byte-eater"'* ]]

scores="$(request 200 "$BASE_URL/api/scores?limit=3")"
[[ "$scores" == \[* ]]

submitted="$(request 201 \
    --request POST "$BASE_URL/api/scores" \
    --header 'Content-Type: application/json' \
    --data '{"name":"smoke","score":123,"level":1}')"
[[ "$submitted" == \[* ]]

invalid="$(request 400 \
    --request POST "$BASE_URL/api/scores" \
    --header 'Content-Type: application/json' \
    --data '{"name":"bad!","score":1,"level":1}')"
[[ "$invalid" == *'error'* ]]

echo "API smoke passed: $BASE_URL"
