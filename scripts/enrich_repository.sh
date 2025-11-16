#!/usr/bin/env bash
# Enrich repository with metadata (discrete but incisive)
set -euo pipefail

REPO="danvoulez/icu-sl4"

# Generate token
TOKEN=$(./scripts/generate_github_app_token.sh 2>/dev/null | grep "Installation token:" | awk '{print $3}')

if [ -z "$TOKEN" ]; then
    echo "Error: Could not generate GitHub App token"
    exit 1
fi

export GITHUB_TOKEN="$TOKEN"

echo "=== Enriching repository ==="
echo ""

# Update description
echo "1. Updating description..."
curl -s -X PATCH \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/$REPO \
  -d '{"description":"Sistema de decisão determinística para UTI com garantia matemática de consistência e rastreabilidade"}' \
  > /dev/null && echo "   ✅ Description updated"

# Add topics
echo "2. Adding topics..."
curl -s -X PUT \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.mercy-preview+json" \
  https://api.github.com/repos/$REPO/topics \
  -d '{"names":["healthcare","icu","decision-support","deterministic","rust","fhir","slsa","cryptography"]}' \
  > /dev/null && echo "   ✅ Topics added"

echo ""
echo "✅ Repository enriched"
echo ""
echo "📋 Changes:"
echo "   • Description: Clear and objective"
echo "   • Topics: healthcare, icu, decision-support, deterministic, rust, fhir, slsa, cryptography"
echo ""
echo "🔗 View: https://github.com/$REPO"

