#!/bin/bash
# Script to test alerting by generating test metrics

set -e

APP_IP="${1:-localhost:8080}"
COUNT="${2:-50}"  # Default 50 requests

echo "Testing alerting system..."
echo "Application endpoint: http://${APP_IP}"
echo "Generating ${COUNT} requests..."
echo ""

# Generate orders (60% of requests)
ORDERS=$((COUNT * 60 / 100))
echo "Generating ${ORDERS} orders..."
for i in $(seq 1 $ORDERS); do
  curl -s -X POST "http://${APP_IP}/order" -H "Content-Type: application/json" > /dev/null 2>&1
  if [ $((i % 10)) -eq 0 ]; then
    echo "  ✓ Generated $i orders..."
  fi
  sleep 0.1
done

# Update active users (25% of requests)
USERS=$((COUNT * 25 / 100))
echo "Updating users ${USERS} times..."
for i in $(seq 1 $USERS); do
  curl -s -X POST "http://${APP_IP}/users" -H "Content-Type: application/json" > /dev/null 2>&1
  sleep 0.2
done

# Generate errors (10% of requests)
ERRORS=$((COUNT * 10 / 100))
echo "Generating ${ERRORS} test errors..."
for i in $(seq 1 $ERRORS); do
  curl -s "http://${APP_IP}/error" > /dev/null 2>&1
  sleep 0.3
done

# Health checks (5% of requests)
HEALTH=$((COUNT * 5 / 100))
echo "Running ${HEALTH} health checks..."
for i in $(seq 1 $HEALTH); do
  curl -s "http://${APP_IP}/health" > /dev/null 2>&1
  sleep 0.1
done

echo ""
echo "✓ Test completed: ${COUNT} total requests"
echo "  - Orders: ${ORDERS}"
echo "  - User updates: ${USERS}"
echo "  - Errors: ${ERRORS}"
echo "  - Health checks: ${HEALTH}"
echo ""
echo "Check Prometheus and CloudWatch for metrics and alerts."
