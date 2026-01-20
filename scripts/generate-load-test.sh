#!/bin/bash
# Script to generate large random test load and metrics

set -e

APP_ENDPOINT="${1:-localhost:8080}"
DURATION="${2:-300}"  # Default 5 minutes
CONCURRENT="${3:-5}"   # Number of concurrent requests

echo "=========================================="
echo "Load Test Generator"
echo "=========================================="
echo "Application: http://${APP_ENDPOINT}"
echo "Duration: ${DURATION} seconds (~$((DURATION/60)) minutes)"
echo "Concurrent requests: ${CONCURRENT}"
echo "=========================================="
echo ""

# Function to generate random order
generate_order() {
  local endpoint="http://${APP_ENDPOINT}/order"
  curl -s -X POST "$endpoint" -H "Content-Type: application/json" > /dev/null 2>&1
  echo "✓ Order created"
}

# Function to update users (random number)
update_users() {
  local endpoint="http://${APP_ENDPOINT}/users"
  curl -s -X POST "$endpoint" -H "Content-Type: application/json" > /dev/null 2>&1
  echo "✓ Users updated"
}

# Function to generate error (random chance)
generate_error() {
  local endpoint="http://${APP_ENDPOINT}/error"
  curl -s "$endpoint" > /dev/null 2>&1
  echo "⚠ Error generated"
}

# Function to check health
check_health() {
  local endpoint="http://${APP_ENDPOINT}/health"
  curl -s "$endpoint" > /dev/null 2>&1
}

# Function to get metrics
get_metrics() {
  local endpoint="http://${APP_ENDPOINT}/metrics"
  curl -s "$endpoint" > /dev/null 2>&1
}

# Worker function for concurrent requests
worker() {
  local worker_id=$1
  local end_time=$(($(date +%s) + DURATION))
  local count=0
  
  while [ $(date +%s) -lt $end_time ]; do
    # Random action selection
    local action=$((RANDOM % 100))
    
    if [ $action -lt 60 ]; then
      # 60% chance: Create order
      generate_order
    elif [ $action -lt 85 ]; then
      # 25% chance: Update users
      update_users
    elif [ $action -lt 95 ]; then
      # 10% chance: Check health
      check_health
      echo "✓ Health check"
    elif [ $action -lt 98 ]; then
      # 3% chance: Get metrics
      get_metrics
      echo "✓ Metrics scraped"
    else
      # 2% chance: Generate error
      generate_error
    fi
    
    count=$((count + 1))
    
    # Random delay between 0.1 and 2 seconds
    local delay=$(awk "BEGIN {print ($RANDOM % 190 + 10) / 100}")
    sleep $delay
  done
  
  echo "Worker $worker_id completed: $count requests"
}

# Check if application is accessible
echo "Checking application health..."
if ! check_health; then
  echo "❌ Error: Cannot connect to application at http://${APP_ENDPOINT}"
  echo "Make sure you have port forwarding active:"
  echo "  ./scripts/port-forward-app.sh"
  exit 1
fi
echo "✓ Application is accessible"
echo ""

# Start time
START_TIME=$(date +%s)
echo "Starting load test at $(date)"
echo ""

# Start concurrent workers
PIDS=()
for i in $(seq 1 $CONCURRENT); do
  worker $i &
  PIDS+=($!)
done

# Wait for all workers
for pid in "${PIDS[@]}"; do
  wait $pid
done

# End time
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo ""
echo "=========================================="
echo "Load Test Complete"
echo "=========================================="
echo "Duration: ${ELAPSED} seconds"
echo "Concurrent workers: ${CONCURRENT}"
echo "Estimated requests: ~$((CONCURRENT * ELAPSED / 2))"
echo ""
echo "Check your dashboards in Grafana!"
echo "  - Orders Created"
echo "  - Active Users"
echo "  - Request Rate"
echo "  - Error Rate"
echo "=========================================="
