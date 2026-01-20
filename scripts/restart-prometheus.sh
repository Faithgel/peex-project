#!/bin/bash
# Script to restart Prometheus service

set -e

PROMETHEUS_INSTANCE_ID="${1:-}"

if [ -z "$PROMETHEUS_INSTANCE_ID" ]; then
  cd "$(dirname "$0")/../terraform"
  PROMETHEUS_INSTANCE_ID=$(terraform output -raw prometheus_instance_id 2>/dev/null || echo "")
  
  if [ -z "$PROMETHEUS_INSTANCE_ID" ]; then
    echo "Error: Could not get Prometheus instance ID from Terraform output"
    echo "Usage: $0 [prometheus-instance-id]"
    exit 1
  fi
fi

echo "Restarting Prometheus on instance: $PROMETHEUS_INSTANCE_ID"
echo ""

# Send restart command
COMMAND_OUTPUT=$(aws ssm send-command \
  --instance-ids "$PROMETHEUS_INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["sudo systemctl restart prometheus", "sleep 3", "sudo systemctl status prometheus --no-pager"]' \
  --output json)

COMMAND_ID=$(echo "$COMMAND_OUTPUT" | jq -r '.Command.CommandId')
echo "Command ID: $COMMAND_ID"
echo "Waiting for command to complete..."
echo ""

# Wait for command
sleep 5

# Get command output
OUTPUT=$(aws ssm get-command-invocation \
  --command-id "$COMMAND_ID" \
  --instance-id "$PROMETHEUS_INSTANCE_ID" \
  --output json)

echo "=== Prometheus Service Status ==="
echo "$OUTPUT" | jq -r '.StandardOutputContent'

if [ "$(echo "$OUTPUT" | jq -r '.StandardErrorContent')" != "" ]; then
  echo ""
  echo "=== Errors ==="
  echo "$OUTPUT" | jq -r '.StandardErrorContent'
fi

EXIT_CODE=$(echo "$OUTPUT" | jq -r '.ResponseCode')
if [ "$EXIT_CODE" = "0" ]; then
  echo ""
  echo "✓ Prometheus restarted successfully!"
else
  echo ""
  echo "✗ Prometheus restart failed with exit code: $EXIT_CODE"
  exit 1
fi
