#!/usr/bin/env bash
# Build the Lambda image, push it to ECR, and point the function at it.
set -euo pipefail

PROFILE="${AWS_PROFILE:-terraform-dev}"
REGION="us-east-1"
ACCOUNT_ID="924586450630"
REPO="ik-dev-email-ai-agent-lambda"
FUNCTION_NAME="$REPO"
TAG="$(date +%Y%m%d%H%M%S)"
IMAGE_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO:$TAG"

cd "$(dirname "$0")"

aws ecr get-login-password --region "$REGION" --profile "$PROFILE" |
  docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

# --provenance=false keeps buildx from producing a multi-manifest image,
# which Lambda rejects.
docker build --platform linux/amd64 --provenance=false -t "$IMAGE_URI" .
docker push "$IMAGE_URI"

aws lambda update-function-code \
  --function-name "$FUNCTION_NAME" \
  --image-uri "$IMAGE_URI" \
  --region "$REGION" --profile "$PROFILE" >/dev/null

aws lambda wait function-updated \
  --function-name "$FUNCTION_NAME" \
  --region "$REGION" --profile "$PROFILE"

echo "Deployed $IMAGE_URI"
