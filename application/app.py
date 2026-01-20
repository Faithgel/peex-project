"""
Sample Application with Custom Metrics
This application demonstrates custom metrics collection for Prometheus and CloudWatch
"""
from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
import time
import random
import boto3
from datetime import datetime
import os

app = Flask(__name__)

# Custom metrics definitions
request_count = Counter(
    'sample_app_requests_total',
    'Total number of requests',
    ['method', 'endpoint']
)

request_duration = Histogram(
    'sample_app_request_duration_seconds',
    'Request duration in seconds',
    ['endpoint']
)

active_users = Gauge(
    'sample_app_active_users',
    'Number of active users'
)

order_count = Counter(
    'sample_app_orders_total',
    'Total number of orders'
)

processing_time = Histogram(
    'sample_app_processing_time_seconds',
    'Order processing time in seconds',
    buckets=[0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0, 10.0]
)

error_count = Counter(
    'sample_app_errors_total',
    'Total number of errors',
    ['error_type']
)

# CloudWatch client
aws_region = os.getenv('AWS_REGION', 'us-east-1')
cloudwatch = boto3.client('cloudwatch', region_name=aws_region)

# Simulated active users
current_users = 0


@app.route('/')
def index():
    """Root endpoint with API documentation"""
    return jsonify({
        'message': 'Sample Application with Custom Metrics',
        'version': '1.0.0',
        'endpoints': {
            '/metrics': 'Prometheus metrics endpoint',
            '/order': 'Create an order (POST)',
            '/users': 'Get/Update active users (GET/POST)',
            '/health': 'Health check',
            '/error': 'Generate test error (for alerting)'
        }
    })


@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}


@app.route('/order', methods=['POST'])
def create_order():
    """Create an order - demonstrates business metric collection"""
    start_time = time.time()
    global current_users
    
    try:
        # Simulate order processing
        processing_delay = random.uniform(0.1, 0.5)
        time.sleep(processing_delay)
        
        # Increment Prometheus metrics
        order_count.inc()
        processing_time.observe(processing_delay)
        request_count.labels(method='POST', endpoint='/order').inc()
        
        # Publish custom metric to CloudWatch
        try:
            cloudwatch.put_metric_data(
                Namespace='PeexProject/CustomMetrics',
                MetricData=[
                    {
                        'MetricName': 'OrdersCreated',
                        'Value': 1,
                        'Unit': 'Count',
                        'Timestamp': datetime.utcnow()
                    },
                    {
                        'MetricName': 'OrderProcessingTime',
                        'Value': processing_delay,
                        'Unit': 'Seconds',
                        'Timestamp': datetime.utcnow()
                    }
                ]
            )
        except Exception as e:
            # Log but don't fail if CloudWatch is unavailable
            print(f"CloudWatch error: {e}")
        
        duration = time.time() - start_time
        request_duration.labels(endpoint='/order').observe(duration)
        
        return jsonify({
            'status': 'success',
            'message': 'Order created',
            'processing_time': processing_delay,
            'order_id': f"ORD-{int(time.time())}"
        }), 201
        
    except Exception as e:
        error_count.labels(error_type='order_creation_error').inc()
        request_duration.labels(endpoint='/order').observe(time.time() - start_time)
        return jsonify({'status': 'error', 'message': str(e)}), 500


@app.route('/users', methods=['GET', 'POST'])
def users():
    """Manage active users - demonstrates gauge metric"""
    global current_users
    
    if request.method == 'POST':
        # Simulate user login
        new_users = random.randint(1, 5)
        current_users = min(current_users + new_users, 100)
        active_users.set(current_users)
        
        # Publish to CloudWatch
        try:
            cloudwatch.put_metric_data(
                Namespace='PeexProject/CustomMetrics',
                MetricData=[
                    {
                        'MetricName': 'ActiveUsers',
                        'Value': current_users,
                        'Unit': 'Count',
                        'Timestamp': datetime.utcnow()
                    }
                ]
            )
        except Exception as e:
            print(f"CloudWatch error: {e}")
        
        request_count.labels(method='POST', endpoint='/users').inc()
        return jsonify({
            'active_users': current_users,
            'new_users': new_users
        }), 200
    else:
        request_count.labels(method='GET', endpoint='/users').inc()
        return jsonify({'active_users': current_users}), 200


@app.route('/health')
def health():
    """Health check endpoint"""
    request_count.labels(method='GET', endpoint='/health').inc()
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat()
    }), 200


@app.route('/error')
def generate_error():
    """Endpoint to generate errors for testing alerts"""
    error_count.labels(error_type='test_error').inc()
    
    try:
        cloudwatch.put_metric_data(
            Namespace='PeexProject/CustomMetrics',
            MetricData=[
                {
                    'MetricName': 'ErrorRate',
                    'Value': 1,
                    'Unit': 'Count',
                    'Timestamp': datetime.utcnow()
                }
            ]
        )
    except Exception as e:
        print(f"CloudWatch error: {e}")
    
    return jsonify({
        'status': 'error',
        'message': 'Test error generated for alerting validation'
    }), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)
