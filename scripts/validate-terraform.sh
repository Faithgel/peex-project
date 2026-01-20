#!/bin/bash
# Script to validate Terraform configuration

set -e

cd "$(dirname "$0")/../terraform"

echo "Running terraform fmt..."
terraform fmt -check -recursive

echo "Running terraform validate..."
terraform init -backend=false
terraform validate

echo "Terraform validation completed successfully!"
