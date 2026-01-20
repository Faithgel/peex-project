#!/bin/bash
# Script to generate sustained load over a longer period

set -e

APP_ENDPOINT="${1:-localhost:8080}"
DURATION="${2:-1800}"  # Default 30 minutes

echo "=========================================="
echo "Sustained Load Generator"
echo "=========================================="
echo "Application: http://${APP_ENDPOINT}"
echo "Duration: ${DURATION} seconds ($((DURATION/60)) minutes)"
echo "This will generate continuous load..."
echo "=========================================="
echo ""

# Check if application is accessible
if ! curl -s "http://${APP_ENDPOINT}/health" > /dev/null 2>&1; then
  echo "❌ Error: Cannot connect to application"
  echo "Start port forwarding first: ./scripts/port-forward-app.sh"
  exit 1
fi

START_TIME=$(date +%s)
END_TIME=$((START_TIME + DURATION))
REQUEST_COUNT=0
ERROR_COUNT=0

# Trap to show stats on exit
trap 'echo ""; echo "Stats: $REQUEST_COUNT requests, $ERROR_COUNT errors"; exit' INT TERM

echo "Starting at $(date)"
echo "Press Ctrl+C to stop early"
echo ""

while [ $(date +%s) -lt $END_TIME ]; do
  # Random action
  ACTION=$((RANDOM % 100))
  
  if [ $ACTION -lt 50 ]; then
    # 50%: Orders
    curl -s -X POST "http://${APP_ENDPOINT}/order" -H "Content-Type: application/json" > /dev/null 2>&1 && REQUEST_COUNT=$((REQUEST_COUNT + 1)) || ERROR_COUNT=$((ERROR_COUNT + 1))
  elif [ $ACTION -lt 75 ]; then
    # 25%: Users
    curl -s -X POST "http://${APP_ENDPOINT}/users" -H "Content-Type: application/json" > /dev/null 2>&1 && REQUEST_COUNT=$((REQUEST_COUNT + 1)) || ERROR_COUNT=$((ERROR_COUNT + 1))
  elif [ $ACTION -lt 90 ]; then
    # 15%: Health check
    curl -s "http://${APP_ENDPOINT}/health" > /dev/null 2>&1 && REQUEST_COUNT=$((REQUEST_COUNT + 1)) || ERROR_COUNT=$((ERROR_COUNT + 1))
  elif [ $ACTION -lt 98 ]; then
    # 8%: Metrics
    curl -s "http://${APP_ENDPOINT}/metrics" > /dev/null 2>&1 && REQUEST_COUNT=$((REQUEST_COUNT + 1)) || ERROR_COUNT=$((ERROR_COUNT + 1))
  else
    # 2%: Errors
    curl -s "http://${APP_ENDPOINT}/error" > /dev/null 2>&1 && REQUEST_COUNT=$((REQUEST_COUNT + 1)) || ERROR_COUNT=$((ERROR_COUNT + 1))
  fi
  
  # Random delay 0.05 to 0.5 seconds (high frequency)
  sleep $(awk "BEGIN {print ($RANDOM % 45 + 5) / 100}")
  
  # Show progress every 100 requests
  if [ $((REQUEST_COUNT % 100)) -eq 0 ]; then
    echo "[$(date +%H:%M:%S)] Requests: $REQUEST_COUNT, Errors: $ERROR_COUNT"
  fi
done

echo ""
echo "=========================================="
echo "Completed!"
echo "Total requests: $REQUEST_COUNT"
echo "Total errors: $ERROR_COUNT"
echo "=========================================="
