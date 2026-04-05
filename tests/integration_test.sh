#!/usr/bin/env bash
# Integration test for caddy-template
# Builds the image, starts the container, validates HTTP responses, then tears down.

set -euo pipefail

PROJECT_NAME="caddy-template-test-$$"
COMPOSE_FILE="$(cd "$(dirname "$0")/.." && pwd)/compose.yaml"
COMPOSE="docker compose -f $COMPOSE_FILE -p $PROJECT_NAME"
TEST_PORT=8484  # avoid conflicts with host port 80
TIMEOUT=30

# ── Helpers ──────────────────────────────────────────────────────────────────

TOTAL=0
pass() { TOTAL=$((TOTAL + 1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { TOTAL=$((TOTAL + 1)); printf '  \033[31m✗\033[0m %s\n' "$1"; FAILURES=$((FAILURES + 1)); }

cleanup() {
    echo ""
    echo "Tearing down..."
    $COMPOSE down -v --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

FAILURES=0

# ── Build & Start ────────────────────────────────────────────────────────────

echo "Building and starting services (project: $PROJECT_NAME)..."
echo ""

# Write port-override file
cat > "/tmp/${PROJECT_NAME}-override.yaml" <<EOF
services:
  caddy:
    ports:
      - "${TEST_PORT}:80"
EOF

COMPOSE="docker compose -f $COMPOSE_FILE -f /tmp/${PROJECT_NAME}-override.yaml -p $PROJECT_NAME"

# Show build output so the build process is visible
$COMPOSE up -d --build --force-recreate \
    || { echo "docker compose up failed"; exit 1; }

echo ""

# ── Wait for healthy ─────────────────────────────────────────────────────────

echo "Waiting for Caddy to become ready on port $TEST_PORT..."

elapsed=0
until curl -sf "http://localhost:${TEST_PORT}" >/dev/null 2>&1; do
    if [ "$elapsed" -ge "$TIMEOUT" ]; then
        echo "ERROR: Caddy did not become ready within ${TIMEOUT}s"
        $COMPOSE logs
        exit 1
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done

echo "Caddy is up after ${elapsed}s."
echo ""
echo "Running tests..."
echo ""

# ── Tests ────────────────────────────────────────────────────────────────────

# 1. HTTP 200 on root
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${TEST_PORT}/")
if [ "$STATUS" = "200" ]; then
    pass "GET / returns 200"
else
    fail "GET / returned $STATUS (expected 200)"
fi

# 2. Response contains expected page content
BODY=$(curl -sf "http://localhost:${TEST_PORT}/")
if echo "$BODY" | grep -q "Service Active"; then
    pass "Response body contains 'Service Active'"
else
    fail "Response body missing 'Service Active'"
fi

# 3. Content-Type is HTML
CT=$(curl -sf -o /dev/null -w '%{content_type}' "http://localhost:${TEST_PORT}/")
if echo "$CT" | grep -qi "text/html"; then
    pass "Content-Type is text/html"
else
    fail "Content-Type is '$CT' (expected text/html)"
fi

# 4. Server header identifies Caddy
SERVER=$(curl -sf -I "http://localhost:${TEST_PORT}/" | grep -i '^server:' || true)
if echo "$SERVER" | grep -qi "caddy"; then
    pass "Server header contains 'Caddy'"
else
    fail "Server header: '$SERVER' (expected 'Caddy')"
fi

# 5. Non-existent path returns 404
STATUS_404=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${TEST_PORT}/nonexistent-path")
if [ "$STATUS_404" = "404" ]; then
    pass "GET /nonexistent-path returns 404"
else
    fail "GET /nonexistent-path returned $STATUS_404 (expected 404)"
fi

# 6. Container is running
STATE=$($COMPOSE ps --format '{{.State}}' 2>/dev/null | head -1)
if [ "$STATE" = "running" ]; then
    pass "Container state is 'running'"
else
    fail "Container state is '$STATE' (expected 'running')"
fi

# ── Summary ──────────────────────────────────────────────────────────────────

PASSED=$((TOTAL - FAILURES))
echo ""
if [ "$FAILURES" -eq 0 ]; then
    printf "\033[32mPassed: %d/%d\033[0m\n" "$PASSED" "$TOTAL"
    exit 0
else
    printf "\033[31mPassed: %d/%d — %d failed\033[0m\n" "$PASSED" "$TOTAL" "$FAILURES"
    exit 1
fi
