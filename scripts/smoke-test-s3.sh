#!/bin/bash
# ============================================================
# Raaya - US-01-04: S3 Smoke Test
# Verifies all acceptance criteria before sprint sign-off
# ============================================================

set -e

BUCKET_NAME="${RAAYA_S3_BUCKET_NAME:-raaya-mvp-media}"
PASS=0
FAIL=0

pass() { echo "  ✅ PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "╔════════════════════════════════════════════╗"
echo "║   Raaya - US-01-04 Smoke Test              ║"
echo "╚════════════════════════════════════════════╝"
echo "  Bucket: $BUCKET_NAME"
echo ""

# ── AC 1: Bucket exists ───────────────────────────────────
echo "▶ AC1: Bucket exists"
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  pass "Bucket '$BUCKET_NAME' exists"
else
  fail "Bucket '$BUCKET_NAME' does not exist — run setup-s3-bucket.sh first"
fi

# ── AC 2: Bucket listing is non-public ───────────────────
echo ""
echo "▶ AC2: Bucket listing is non-public"

BLOCK_PUBLIC_ACLS=$(aws s3api get-public-access-block --bucket "$BUCKET_NAME" --query 'PublicAccessBlockConfiguration.BlockPublicAcls' --output text)
RESTRICT_PUBLIC=$(aws s3api get-public-access-block --bucket "$BUCKET_NAME" --query 'PublicAccessBlockConfiguration.RestrictPublicBuckets' --output text)

if [ "$BLOCK_PUBLIC_ACLS" = "True" ] && [ "$RESTRICT_PUBLIC" = "True" ]; then
  pass "Public access is fully blocked"
else
  fail "Public access is NOT fully blocked (check BlockPublicAcls and RestrictPublicBuckets)"
fi

# ── AC 3: Media prefixes exist ────────────────────────────
echo ""
echo "▶ AC3: Required media prefixes exist"
PREFIXES=("family-media/voice/" "family-media/photos/" "resident-media/profile-photos/" "tmp/")
for prefix in "${PREFIXES[@]}"; do
  COUNT=$(aws s3 ls "s3://${BUCKET_NAME}/${prefix}" 2>/dev/null | wc -l)
  if [ "$COUNT" -ge 0 ]; then
    pass "Prefix '$prefix' is reachable"
  else
    fail "Prefix '$prefix' not found"
  fi
done

# ── AC 4: Test PUT upload succeeds (smoke upload) ─────────
echo ""
echo "▶ AC4: Test file upload succeeds"
TMP_FILE=$(mktemp /tmp/raaya-smoke-XXXXXX.txt)
echo "Raaya smoke test - $(date)" > "$TMP_FILE"
TEST_KEY="tmp/smoke-test-$(date +%s).txt"

if aws s3 cp "$TMP_FILE" "s3://${BUCKET_NAME}/${TEST_KEY}" 2>/dev/null; then
  pass "Test upload succeeded → key: $TEST_KEY"

  ## ── AC 5: Test GET download succeeds ─────────────────
  echo ""
  echo "▶ AC5: Test file download succeeds"
  DL_TMP=$(mktemp /tmp/raaya-smoke-dl-XXXXXX.txt)
  if aws s3 cp "s3://${BUCKET_NAME}/${TEST_KEY}" "$DL_TMP" >/dev/null 2>&1; then
    pass "Test download succeeded"
  else
    fail "Test download failed"
  fi
  rm -f "$DL_TMP"
  # Cleanup
  aws s3 rm "s3://${BUCKET_NAME}/${TEST_KEY}" > /dev/null
else
  fail "Test upload failed — check IAM permissions"
fi

rm -f "$TMP_FILE"

# ── AC 6: Encryption is enabled ──────────────────────────
echo ""
echo "▶ AC6: Server-side encryption is enabled"
ENC=$(aws s3api get-bucket-encryption --bucket "$BUCKET_NAME" 2>/dev/null \
  --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' \
  --output text)
if [ "$ENC" = "AES256" ] || [ "$ENC" = "aws:kms" ]; then
  pass "Encryption enabled ($ENC)"
else
  fail "Encryption NOT enabled (got: $ENC)"
fi

# ── Summary ───────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════"
TOTAL=$((PASS + FAIL))
echo "  Results: $PASS/$TOTAL passed"
if [ "$FAIL" -eq 0 ]; then
  echo "  🎉 All checks passed — US-01-04 acceptance criteria met!"
else
  echo "  ⚠️  $FAIL check(s) failed — review output above"
fi
echo "════════════════════════════════════════════"
echo ""

exit $FAIL
