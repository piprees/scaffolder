#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPEC="$SCRIPT_DIR/openapi.yml"

echo ">> Generating frontend client (typescript-fetch)..."
pnpm exec openapi-generator-cli generate \
  -i "$SPEC" \
  -g typescript-fetch \
  -o "$SCRIPT_DIR/../frontend/src/generated" \
  --additional-properties=supportsES6=true,typescriptThreePlus=true

echo ">> Generating backend interfaces (spring)..."
pnpm exec openapi-generator-cli generate \
  -i "$SPEC" \
  -g spring \
  -o "$SCRIPT_DIR/../backend/src/generated" \
  --additional-properties=interfaceOnly=true,useSpringBoot3=true,java8=false,delegatePattern=true,useTags=true \
  --model-package=com.scaffoldedapplication.model.generated \
  --api-package=com.scaffoldedapplication.api.generated

echo ">> Code generation complete"
