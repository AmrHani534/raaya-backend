#!/bin/bash
# ============================================================
# Raaya - US-01-04: S3 Media Bucket Setup Script
# Epic: EP-01 - Project Foundation & DevOps
# Role: BE2
# Sprint: Sprint 1 (Weeks 1-2)
# ============================================================

set -e

# ── Configuration ──────────────────────────────────────────
BUCKET_NAME="${RAAYA_S3_BUCKET_NAME:-raaya-mvp-media}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ENVIRONMENT="${ENVIRONMENT:-demo}"

echo "╔════════════════════════════════════════════╗"
echo "║   Raaya - S3 Media Bucket Setup (MVP)      ║"
echo "╚════════════════════════════════════════════╝"
echo ""
echo "  Bucket : $BUCKET_NAME"
echo "  Region : $AWS_REGION"
echo "  Env    : $ENVIRONMENT"
echo ""

# ── Step 1: Create the bucket ──────────────────────────────
echo "▶ Step 1: Creating S3 bucket..."

if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "  ✓ Bucket already exists — skipping creation."
else
  if [ "$AWS_REGION" = "us-east-1" ]; then
    aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region "$AWS_REGION"
  else
    aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region "$AWS_REGION" \
      --create-bucket-configuration LocationConstraint="$AWS_REGION"
  fi
  echo "  ✓ Bucket created: $BUCKET_NAME"
fi

# ── Step 2: Block all public access ───────────────────────
echo ""
echo "▶ Step 2: Blocking all public access..."

aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "  ✓ Public access blocked (bucket listing is non-public)"

# ── Step 3: Enable versioning (optional safety layer) ─────
echo ""
echo "▶ Step 3: Enabling versioning for demo media safety..."

aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

echo "  ✓ Versioning enabled"

# ── Step 4: Enable server-side encryption ─────────────────
echo ""
echo "▶ Step 4: Enabling server-side encryption (AES-256)..."

aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }'

echo "  ✓ Server-side encryption enabled"

# ── Step 5: Apply bucket policy (deny non-HTTPS) ──────────
echo ""
echo "▶ Step 5: Applying bucket policy..."

cat <<EOF > bucket_policy_temp.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::${BUCKET_NAME}",
        "arn:aws:s3:::${BUCKET_NAME}/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
EOF

aws s3api put-bucket-policy \
  --bucket "$BUCKET_NAME" \
  --policy file://bucket_policy_temp.json

rm bucket_policy_temp.json

echo "  ✓ Bucket policy applied (HTTPS-only access)"

# ── Step 6: Set lifecycle rule (auto-expire old tmp uploads)
echo ""
echo "▶ Step 6: Setting lifecycle rule for temp uploads..."

aws s3api put-bucket-lifecycle-configuration \
  --bucket "$BUCKET_NAME" \
  --lifecycle-configuration '{
    "Rules": [
      {
        "ID": "ExpireUnconfirmedUploads",
        "Filter": { "Prefix": "tmp/" },
        "Status": "Enabled",
        "Expiration": { "Days": 1 }
      }
    ]
  }'

echo "  ✓ Lifecycle rule set (tmp/ prefix expires after 1 day)"

# ── Step 7: Apply CORS for presigned URL uploads ──────────
echo ""
echo "▶ Step 7: Applying CORS configuration for presigned uploads..."

aws s3api put-bucket-cors \
  --bucket "$BUCKET_NAME" \
  --cors-configuration '{
    "CORSRules": [
      {
        "AllowedHeaders": ["*"],
        "AllowedMethods": ["GET", "PUT", "POST"],
        "AllowedOrigins": ["*"],
        "ExposeHeaders": ["ETag"],
        "MaxAgeSeconds": 3600
      }
    ]
  }'

echo "  ✓ CORS configured for presigned URL direct uploads"

# ── Step 8: Tag the bucket ────────────────────────────────
echo ""
echo "▶ Step 8: Tagging the bucket..."

aws s3api put-bucket-tagging \
  --bucket "$BUCKET_NAME" \
  --tagging '{
    "TagSet": [
      { "Key": "Project",     "Value": "Raaya" },
      { "Key": "Environment", "Value": "'"$ENVIRONMENT"'" },
      { "Key": "Epic",        "Value": "EP-01" },
      { "Key": "ManagedBy",   "Value": "BE2" }
    ]
  }'

echo "  ✓ Tags applied"

# ── Step 9: Create folder prefixes (touch placeholder) ────
echo ""
echo "▶ Step 9: Creating media prefix structure..."

PREFIXES=(
  "family-media/voice/"
  "family-media/photos/"
  "resident-media/profile-photos/"
  "tmp/"
)

# عمل فايل فاضي مؤقت عشان الويندوز
touch temp_empty_file.txt

for prefix in "${PREFIXES[@]}"; do
  aws s3api put-object \
    --bucket "$BUCKET_NAME" \
    --key "${prefix}.gitkeep" \
    --body temp_empty_file.txt \
    --content-type "application/octet-stream" > /dev/null
  echo "  ✓ Created prefix: $prefix"
done

# مسح الفايل المؤقت
rm temp_empty_file.txt

# ── Done ──────────────────────────────────────────────────
echo ""
echo "╔════════════════════════════════════════════╗"
echo "║   ✓ S3 Bucket Setup Complete!              ║"
echo "╚════════════════════════════════════════════╝"
echo ""
echo "  Bucket ARN : arn:aws:s3:::$BUCKET_NAME"
echo ""
echo "  Media Prefixes:"
echo "    family-media/voice/              → Family voice notes"
echo "    family-media/photos/             → Family photos"
echo "    resident-media/profile-photos/   → Resident profile photos"
echo "    tmp/                             → Unconfirmed uploads (1-day TTL)"
echo ""
echo "  Add to your .env:"
echo "    AWS_S3_BUCKET_NAME=$BUCKET_NAME"
echo "    AWS_REGION=$AWS_REGION"
echo ""
