#!/bin/bash
# Script to generate SSH keys for the project

set -e

KEYS_DIR="$(dirname "$0")/../keys"

# Create keys directory if it doesn't exist
mkdir -p "$KEYS_DIR"

# Generate SSH key pair
echo "Generating SSH key pair..."
ssh-keygen -t rsa -b 4096 -f "$KEYS_DIR/id_rsa" -N "" -C "peex-project-key"

echo "SSH keys generated successfully!"
echo "Private key: $KEYS_DIR/id_rsa"
echo "Public key: $KEYS_DIR/id_rsa.pub"
echo ""
echo "Note: These keys are for emergency access only."
echo "Primary access should use AWS Systems Manager Session Manager."
