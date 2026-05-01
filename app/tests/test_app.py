import pytest, json, os
os.environ['SIMULATE_ERRORS'] = 'false'
from app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as c:
        yield c

def test_home_returns_200(client):
    r = client.get('/')
    assert r.status_code == 200

def test_home_has_version(client):
    r = client.get('/')
    data = json.loads(r.data)
    assert 'version' in data

def test_health_is_healthy(client):
    r = client.get('/health')
    assert r.status_code == 200
    assert json.loads(r.data)['status'] == 'healthy'

def test_metrics_endpoint_works(client):
    r = client.get('/metrics')
    assert r.status_code == 200
    assert b'app_requests_total' in r.data