from flask import Flask, jsonify, Response, request
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import time, os, random

app = Flask(__name__)

APP_VERSION = os.environ.get('APP_VERSION', 'v1')
SIMULATE_ERRORS = os.environ.get('SIMULATE_ERRORS', 'false').lower() == 'true'

REQUEST_COUNT = Counter(
    'app_requests_total', 'Total HTTP requests',
    ['method', 'endpoint', 'status_code', 'version']
)
REQUEST_LATENCY = Histogram(
    'app_request_duration_seconds', 'Request latency',
    ['endpoint', 'version']
)

@app.before_request
def before_request():
    request.start_time = time.time()

@app.after_request
def after_request(response):
    duration = time.time() - request.start_time
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.path,
        status_code=response.status_code,
        version=APP_VERSION
    ).inc()
    REQUEST_LATENCY.labels(
        endpoint=request.path, version=APP_VERSION
    ).observe(duration)
    return response

@app.route('/')
def index():
    if SIMULATE_ERRORS and random.random() < 0.35:
        return jsonify({'error': 'Simulated canary error', 'version': APP_VERSION}), 500
    return jsonify({'message': 'Canary Deployment App', 'version': APP_VERSION, 'status': 'healthy'})

@app.route('/health')
def health():
    return jsonify({'status': 'healthy', 'version': APP_VERSION}), 200

@app.route('/metrics')
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)