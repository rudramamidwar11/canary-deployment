#!/usr/bin/env python3
import boto3, requests, os, logging
from datetime import datetime, timezone

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

PROM  = "http://localhost:9090"
NS    = f"{os.environ.get('PROJECT_NAME','canary-deploy')}/app-metrics"
REGION = os.environ.get('AWS_REGION', 'us-east-1')
cw    = boto3.client('cloudwatch', region_name=REGION)

def query(q):
    try:
        r = requests.get(f"{PROM}/api/v1/query", params={'query': q}, timeout=10)
        results = r.json()['data']['result']
        return float(results[0]['value'][1]) if results else 0.0
    except Exception as e:
        log.error(f"Query failed: {e}")
        return 0.0

def main():
    now = datetime.now(timezone.utc)
    err = query('100 * sum(rate(app_requests_total{status_code=~"5..",deployment="canary"}[2m])) / (sum(rate(app_requests_total{deployment="canary"}[2m])) + 0.001)')
    lat = query('avg(rate(app_request_duration_seconds_sum{deployment="canary"}[2m])) / avg(rate(app_request_duration_seconds_count{deployment="canary"}[2m]) + 0.001)')
    rps = query('sum(rate(app_requests_total{deployment="canary"}[2m]))')

    log.info(f"Canary — errors:{err:.1f}%  latency:{lat:.3f}s  rps:{rps:.2f}")

    cw.put_metric_data(Namespace=NS, MetricData=[
        {'MetricName':'CanaryErrorRate', 'Value':err, 'Unit':'Percent',      'Timestamp':now, 'Dimensions':[{'Name':'Deployment','Value':'canary'}]},
        {'MetricName':'CanaryLatency',   'Value':lat, 'Unit':'Seconds',      'Timestamp':now, 'Dimensions':[{'Name':'Deployment','Value':'canary'}]},
        {'MetricName':'CanaryRPS',       'Value':rps, 'Unit':'Count/Second', 'Timestamp':now, 'Dimensions':[{'Name':'Deployment','Value':'canary'}]},
    ])

if __name__ == '__main__':
    main()