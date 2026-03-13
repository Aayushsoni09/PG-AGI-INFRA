#!/bin/bash
# ──────────────────────────────────────────────────────
# Run this ONCE before any terraform init
# Creates the S3 bucket and DynamoDB table for state
# These are NOT managed by Terraform (chicken-and-egg)
# ──────────────────────────────────────────────────────

set -e

BUCKET_NAME="pgagi-tfstate-monkweb009"   # must be globally unique
TABLE_NAME="pgagi-tfstate-lock"
REGION="ap-south-1"

echo "Creating S3 bucket for Terraform state..."
aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION"

echo "Enabling versioning on state bucket..."
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

echo "Enabling encryption on state bucket..."
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

echo "Blocking all public access on state bucket..."
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "Creating DynamoDB table for state locking..."
aws dynamodb create-table \
  --table-name "$TABLE_NAME" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION"

echo ""
echo "✅ Bootstrap complete!"
echo "   S3 bucket : $BUCKET_NAME"
echo "   DynamoDB  : $TABLE_NAME"
echo "   Region    : $REGION"
echo ""
echo "Now run: cd infra/aws/dev && terraform init"
