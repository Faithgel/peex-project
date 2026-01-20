#!/bin/bash
# Script to port forward the application for testing

APP_INSTANCE_ID="${1:-}"

if [ -z "$APP_INSTANCE_ID" ]; then
  cd "$(dirname "$0")/../terraform"
  APP_INSTANCE_ID=$(terraform output -raw application_instance_id 2>/dev/null || echo "")
fi

if [ -z "$APP_INSTANCE_ID" ]; then
  echo "Error: Could not get application instance ID"
  exit 1
fi

echo "Port forwarding application on instance: $APP_INSTANCE_ID"
echo "Application will be available at: http://localhost:8080"
echo ""
echo "Press Ctrl+C to stop port forwarding"
echo ""

aws ssm start-session \
  --target "$APP_INSTANCE_ID" \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["8080"],"localPortNumber":["8080"]}'
