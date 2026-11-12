"""No Google Cloud account or real credentials required for unit tests."""
import importlib.util
import pathlib
import sys
import types
from unittest.mock import MagicMock, patch

# Allows evaluating the HTTP contract even without optional cloud SDK packages.
secret_mod = types.ModuleType("google.cloud.secretmanager")
sqlconnector_mod = types.ModuleType("google.cloud.sql.connector")
sqlconnector_mod.Connector = MagicMock()
sqlconnector_mod.IPTypes = types.SimpleNamespace(PRIVATE="PRIVATE")
for name in ("google", "google.cloud", "google.cloud.sql"):
    if name not in sys.modules:
        sys.modules[name] = types.ModuleType(name)
sys.modules["google.cloud.secretmanager"] = secret_mod
sys.modules["google.cloud.sql.connector"] = sqlconnector_mod
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

# Use a normal Flask test client; the dependencies that touch GCP are mocked.
from main import app  # noqa: E402


def test_health_success(monkeypatch):
    monkeypatch.setenv("CANDIDATE_NAME", "Example Candidate")
    monkeypatch.setenv("COMMIT_SHA", "abcdef1")
    monkeypatch.setenv("REGION", "europe-west1")
    with patch("main.read_secret", return_value="demo-secret") as secret, patch("main.query_database", return_value=True) as query:
        response = app.test_client().get("/health")
    assert response.status_code == 200
    assert response.json == {"candidate": "Example Candidate", "commit": "abcdef1", "region": "europe-west1", "db": "ok", "secret": "ok"}
    assert secret.call_count == 2
    query.assert_called_once_with("demo-secret")


def test_secret_failure_is_not_reported_as_ok():
    with patch("main.read_secret", side_effect=PermissionError("denied")), patch("main.query_database") as query:
        response = app.test_client().get("/health")
    assert response.status_code == 503
    assert response.json["secret"] == "error"
    assert response.json["db"] == "error"
    query.assert_not_called()


def test_database_failure_is_not_reported_as_ok():
    with patch("main.read_secret", return_value="demo-secret"), patch("main.query_database", side_effect=TimeoutError("db unavailable")):
        response = app.test_client().get("/health")
    assert response.status_code == 503
    assert response.json["secret"] == "ok"
    assert response.json["db"] == "error"


def test_public_app_has_no_other_endpoint():
    assert app.test_client().get("/payments").status_code == 404
