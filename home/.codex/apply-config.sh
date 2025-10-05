#!/usr/bin/env bash

# Codex Config Apply Script
# This script applies config.toml.template with environment variables from .env

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="${SCRIPT_DIR}/config.toml.template"
OUTPUT_FILE="${SCRIPT_DIR}/config.toml"
ENV_FILE="${SCRIPT_DIR}/.env"

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if template file exists
if [[ ! -f "$TEMPLATE_FILE" ]]; then
    print_error "Template file not found: $TEMPLATE_FILE"
    exit 1
fi

# Load environment variables if .env exists
if [[ -f "$ENV_FILE" ]]; then
    print_info "Loading environment variables from .env"
    export $(grep -v '^#' "$ENV_FILE" | xargs)
else
    print_warn ".env file not found. Using environment variables from shell."
fi

# Apply template with environment variable substitution
print_info "Applying config template..."

# Use envsubst if available, otherwise use sed
if command -v envsubst &> /dev/null; then
    envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"
else
    # Fallback: simple sed replacement for common patterns
    print_warn "envsubst not found, using sed (limited functionality)"
    sed "s/\${GEMINI_API_KEY}/${GEMINI_API_KEY:-}/g; s/\${GITHUB_PERSONAL_ACCESS_TOKEN}/${GITHUB_PERSONAL_ACCESS_TOKEN:-}/g" "$TEMPLATE_FILE" > "$OUTPUT_FILE"
fi

if [[ $? -eq 0 ]]; then
    print_info "Successfully generated config.toml"
    print_info "Location: $OUTPUT_FILE"
else
    print_error "Failed to generate config.toml"
    exit 1
fi

# Verify that no placeholder remains in the output
if grep -q '\${' "$OUTPUT_FILE"; then
    print_warn "Warning: Some placeholders were not replaced. Please check your .env file."
fi

print_info "Done!"
