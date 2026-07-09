#!/usr/bin/env bash
# Re-captures MercuryTests/Fixtures/*.json from a live Mercury server so the
# DTO decoding tests stay pinned to the real wire format.
#
# Usage:
#   BASE_URL=http://localhost:3000 scripts/refresh-fixtures.sh
#
# Requires a running Mercury backend (see README) with seeded content.
# Registers a fresh throwaway account each run, so captures are reproducible.
# Afterwards: review `git diff MercuryTests/Fixtures/` and run the unit tests —
# a diff means the API contract moved and the Swift models may need to follow.
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3000}"
FIXTURES_DIR="$(cd "$(dirname "$0")/.." && pwd)/MercuryTests/Fixtures"
EMAIL="fixture-$(date +%s)@example.com"
PASSWORD="password123"

status=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/v1/me" || true)
if [ "$status" != "401" ]; then
    echo "error: expected 401 from $BASE_URL/api/v1/me, got '$status'." >&2
    echo "Is the Mercury backend running? (see README: Backend)" >&2
    exit 1
fi

echo "Capturing fixtures from $BASE_URL as $EMAIL"
cd "$FIXTURES_DIR"

# Unauthenticated error envelope.
curl -s "$BASE_URL/api/v1/me" >error-unauthorized.json

# Sign-up: token arrives in the set-auth-token response header (body keeps a copy).
HEADERS=$(mktemp)
curl -s -D "$HEADERS" -o signup-body.json -X POST "$BASE_URL/api/auth/sign-up/email" \
    -H 'Content-Type: application/json' \
    -d "{\"name\":\"Fixture User\",\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}"
TOKEN=$(grep -i '^set-auth-token:' "$HEADERS" | sed 's/^[^:]*: *//' | tr -d '\r')
rm -f "$HEADERS"
test -n "$TOKEN" || { echo "error: no set-auth-token header on sign-up" >&2; exit 1; }
AUTH="Authorization: Bearer $TOKEN"

# Scrub the live session token from the committed fixture (secret scanners
# flag it, and tests read whatever value is present rather than pinning it).
python3 - <<'EOF'
import json
body = json.load(open("signup-body.json"))
if "token" in body:
    body["token"] = "fixture-token-redacted"
json.dump(body, open("signup-body.json", "w"), ensure_ascii=False, indent=1)
EOF

# better-auth failure shape (not the v1 envelope).
curl -s -o auth-error.json -X POST "$BASE_URL/api/auth/sign-in/email" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$EMAIL\",\"password\":\"wrong-password\"}"

# Pre-onboarding: settings must be null.
curl -s -H "$AUTH" "$BASE_URL/api/v1/me" >me-pre-onboarding.json

# Validation error envelope (422).
curl -s -o error-validation.json -X PUT "$BASE_URL/api/v1/me/settings" \
    -H "$AUTH" -H 'Content-Type: application/json' -d '{"track":"invalid"}'

# Onboard to toeic, then the core reads.
curl -s -X PUT "$BASE_URL/api/v1/me/settings" \
    -H "$AUTH" -H 'Content-Type: application/json' -d '{"track":"toeic"}' >settings.json
curl -s -H "$AUTH" "$BASE_URL/api/v1/me" >me.json
curl -s -H "$AUTH" "$BASE_URL/api/v1/dashboard" >dashboard.json
curl -s -H "$AUTH" "$BASE_URL/api/v1/vocab/overview" >vocab-overview-full.json
curl -s -H "$AUTH" "$BASE_URL/api/v1/vocab/study-queue" >study-queue.json
curl -s -H "$AUTH" "$BASE_URL/api/v1/vocab/quiz" >quiz.json

# Grade the first study card (creates SRS state + streak activity).
WORD_ID=$(python3 -c "import json; print(json.load(open('study-queue.json'))['cards'][0]['wordId'])") \
    || { echo "error: study queue is empty — is the content seeded? (bun run db:seed)" >&2; exit 1; }
curl -s -X POST "$BASE_URL/api/v1/vocab/grade" \
    -H "$AUTH" -H 'Content-Type: application/json' \
    -d "{\"wordId\":\"$WORD_ID\",\"grade\":4}" >grade.json

# Submit the quiz answering every question with its first option.
python3 - <<'EOF'
import json
quiz = json.load(open("quiz.json"))
answers = {q["wordId"]: q["options"][0]["wordId"] for q in quiz["questions"]}
json.dump({"track": quiz["track"], "answers": answers}, open("quiz-submit-body.tmp.json", "w"))
EOF
curl -s -X POST "$BASE_URL/api/v1/vocab/quiz" \
    -H "$AUTH" -H 'Content-Type: application/json' \
    -d @quiz-submit-body.tmp.json >quiz-result.json
rm -f quiz-submit-body.tmp.json

# Dashboard again, now with a recentScores entry.
curl -s -H "$AUTH" "$BASE_URL/api/v1/dashboard" >dashboard-after.json

# Trim the overview to a representative slice: 41 KB of words adds nothing to
# decode coverage and makes diffs unreadable.
python3 - <<'EOF'
import json
overview = json.load(open("vocab-overview-full.json"))
overview["words"] = overview["words"][:6]
json.dump(overview, open("vocab-overview.json", "w"), ensure_ascii=False, indent=1)
EOF
rm -f vocab-overview-full.json

echo "Done. Now: review 'git diff MercuryTests/Fixtures/' and run the unit tests."
