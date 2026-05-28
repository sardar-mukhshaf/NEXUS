#!/usr/bin/env bash
# =============================================================================
# NEXUS PLATFORM — Bootstrap Backend
# Idempotent creation of S3 bucket, DynamoDB table, and KMS key for Terraform.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="nexus"
REGION="eu-west-1"
BUCKET_NAME="${PROJECT_NAME}-platform-tfstate"
DYNAMO_TABLE="${PROJECT_NAME}-platform-tfstate-lock"
KMS_ALIAS="alias/${PROJECT_NAME}-tfstate"

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Bootstrap Terraform remote backend resources (S3, DynamoDB, KMS).

Options:
  -h, --help    Show this help message
  -f, --force   Force recreate even if resources exist
EOF
}

FORCE=false
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help) show_help; exit 0 ;;
    -f|--force) FORCE=true; shift ;;
    *) echo "Unknown option: $1"; show_help; exit 1 ;;
  esac
done

echo "[BOOTSTRAP] Starting Nexus platform backend bootstrap..."

# Check AWS credentials
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "[ERROR] AWS credentials not configured or invalid."
  exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "[BOOTSTRAP] Using AWS account: ${ACCOUNT_ID}"

# Create S3 bucket for state
echo "[BOOTSTRAP] Ensuring S3 bucket: ${BUCKET_NAME}"
if ! aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
  aws s3api create-bucket \
    --bucket "${BUCKET_NAME}" \
    --region "${REGION}" \
    --create-bucket-configuration LocationConstraint="${REGION}"
  echo "[BOOTSTRAP] Created S3 bucket."
else
  echo "[BOOTSTRAP] S3 bucket already exists."
fi

echo "[BOOTSTRAP] Enabling S3 versioning..."
aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled

echo "[BOOTSTRAP] Enabling S3 encryption..."
aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms"
      },
      "BucketKeyEnabled": true
    }]
  }'

echo "[BOOTSTRAP] Enabling S3 public access block..."
aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "[BOOTSTRAP] Applying S3 bucket policy..."
cat > /tmp/tfstate-bucket-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EnforceTLS",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::${BUCKET_NAME}",
        "arn:aws:s3:::${BUCKET_NAME}/*"
      ],
      "Condition": {
        "Bool": {"aws:SecureTransport": "false"}
      }
    }
  ]
}
EOF
aws s3api put-bucket-policy --bucket "${BUCKET_NAME}" --policy file:///tmp/tfstate-bucket-policy.json

# Create DynamoDB table for locking
echo "[BOOTSTRAP] Ensuring DynamoDB table: ${DYNAMO_TABLE}"
if ! aws dynamodb describe-table --table-name "${DYNAMO_TABLE}" >/dev/null 2>&1; then
  aws dynamodb create-table \
    --table-name "${DYNAMO_TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}"
  echo "[BOOTSTRAP] Created DynamoDB table."
else
  echo "[BOOTSTRAP] DynamoDB table already exists."
fi

# Create KMS key for state encryption
echo "[BOOTSTRAP] Ensuring KMS key: ${KMS_ALIAS}"
if ! aws kms describe-key --key-id "${KMS_ALIAS}" >/dev/null 2>&1; then
  KEY_ID=$(aws kms create-key \
    --description "Nexus Terraform state encryption key" \
    --key-usage ENCRYPT_DECRYPT \
    --origin AWS_KMS \
    --query KeyMetadata.KeyId --output text)
  aws kms create-alias --alias-name "${KMS_ALIAS}" --target-key-id "${KEY_ID}"
  aws kms enable-key-rotation --key-id "${KEY_ID}"
  echo "[BOOTSTRAP] Created KMS key: ${KEY_ID}"
else
  echo "[BOOTSTRAP] KMS key already exists."
fi

echo "[BOOTSTRAP] Backend bootstrap complete."
echo "[BOOTSTRAP] Update terraform/backend.tf with:"
echo "  bucket         = \"${BUCKET_NAME}\""
echo "  dynamodb_table = \"${DYNAMO_TABLE}\""
echo "  kms_key_id     = \"${KMS_ALIAS}\""
