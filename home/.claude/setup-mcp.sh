#!/usr/bin/env bash

# Claude MCP Setup Script
# This script reads MCP server configurations from YAML and executes claude mcp add commands

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_CONFIG="${SCRIPT_DIR}/mcp-servers.yaml"
ENV_FILE="${SCRIPT_DIR}/.env"

# Default values
SCOPE="user"

# Function to show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
  -s, --scope SCOPE    Set the scope for MCP servers (default: user)
                       Available scopes: user, project
  -h, --help          Show this help message

Examples:
  $0                   # Install with user scope (default)
  $0 -s user          # Install with user scope
  $0 -s project       # Install with project scope
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--scope)
            SCOPE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate scope
if [[ "$SCOPE" != "user" && "$SCOPE" != "project" ]]; then
    print_error "Invalid scope: $SCOPE. Must be 'user' or 'project'"
    usage
    exit 1
fi

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

print_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
}

# Check if required files exist
if [[ ! -f "$MCP_CONFIG" ]]; then
    print_error "MCP configuration file not found: $MCP_CONFIG"
    exit 1
fi

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    print_error "yq is not installed. Please install it first:"
    echo "  brew install yq"
    exit 1
fi

# Check if claude command is available
if ! command -v claude &> /dev/null; then
    print_error "claude command not found. Please install Claude Code CLI first."
    exit 1
fi

# Load environment variables if .env exists
if [[ -f "$ENV_FILE" ]]; then
    print_info "Loading environment variables from .env"
    export $(grep -v '^#' "$ENV_FILE" | xargs)
else
    print_warn ".env file not found. Environment variables may not be available."
fi

# Get the number of servers in the YAML
server_count=$(yq eval '.servers | length' "$MCP_CONFIG")

if [[ $server_count -eq 0 ]]; then
    print_warn "No servers found in configuration"
    exit 0
fi

print_info "Found $server_count server(s) to configure"
print_info "Installing with scope: $SCOPE"

# Get list of existing MCP servers
print_info "Checking for existing MCP servers..."
existing_servers=$(claude mcp list 2>/dev/null | grep ': ' | cut -d':' -f1 || echo "")

# Debug: Print existing servers
if [[ -n "$existing_servers" ]]; then
    print_info "Detected existing servers: $(echo "$existing_servers" | tr '\n' ', ' | sed 's/, $//')"
fi

# Process each server
for ((i=0; i<$server_count; i++)); do
    # Get server name (key)
    server_name=$(yq eval ".servers | keys | .[$i]" "$MCP_CONFIG")

    # Get server configuration
    command=$(yq eval ".servers.$server_name.command" "$MCP_CONFIG")
    args=$(yq eval ".servers.$server_name.args[]" "$MCP_CONFIG" | tr '\n' ' ')

    # Check if server already exists
    if echo "$existing_servers" | grep -q "^${server_name}$"; then
        print_skip "$server_name already exists"
        continue
    fi

    print_info "Adding MCP server: $server_name"

    # Build the claude mcp add command
    claude_cmd="claude mcp add $server_name --scope $SCOPE"

    # Add environment variables if they exist
    env_count=$(yq eval ".servers.$server_name.env | length" "$MCP_CONFIG" 2>/dev/null || echo "0")
    if [[ $env_count -gt 0 ]]; then
        # Get all environment variable keys for this server
        env_keys=$(yq eval ".servers.$server_name.env | keys | .[]" "$MCP_CONFIG" 2>/dev/null)
        for env_key in $env_keys; do
            # Get the environment variable value from YAML
            env_value=$(yq eval ".servers.$server_name.env.$env_key" "$MCP_CONFIG")
            # Expand environment variables (replace ${VAR} with actual value)
            if [[ "$env_value" =~ ^\$\{([^}]+)\}$ ]]; then
                var_name="${BASH_REMATCH[1]}"
                # Check if variable exists before indirect expansion
                if [[ -v "$var_name" ]]; then
                    actual_value="${!var_name}"
                    if [[ -n "$actual_value" ]]; then
                        claude_cmd="$claude_cmd -e $env_key=\"$actual_value\""
                    else
                        print_warn "Environment variable $var_name is empty"
                    fi
                else
                    print_warn "Environment variable $var_name is not set"
                fi
            else
                claude_cmd="$claude_cmd -e $env_key=\"$env_value\""
            fi
        done
    fi

    # Add the command and args
    claude_cmd="$claude_cmd -- $command $args"

    # Execute the command
    if eval "$claude_cmd"; then
        print_info "Successfully added $server_name"
    else
        print_error "Failed to add $server_name"
    fi
done

print_info "MCP setup complete!"
print_info "Run 'claude mcp list' to verify the configuration"
