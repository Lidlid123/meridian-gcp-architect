"""Minimal HTTP API: this evaluation intentionally exposes only GET /health."""
import logging
import os

from flask import Flask, jsonify
from db import query_database, read_secret

app = Flask(__name__)
log = logging.getLogger(__name__)


@app.get("/health")
def health():
    # Never hardcode success. Fail closed (HTTP 503) when either real check fails.
    db_status = "error"
    secret_status = "error"
    db_password = None

    try:
        # Both independent secrets are actually retrieved on EVERY request.
        db_password = read_secret("DB_PASSWORD_SECRET")
        api_token = read_secret("API_TOKEN_SECRET")
        if db_password and api_token:
            secret_status = "ok"
    except Exception as exc:
        log.warning("Secret Manager check failed: %s", type(exc).__name__)

    if db_password:
        try:
            if query_database(db_password):
                db_status = "ok"
        except Exception as exc:
            log.warning("Cloud SQL query failed: %s", type(exc).__name__)

    body = {
        "candidate": os.environ.get("CANDIDATE_NAME", "NOT_CONFIGURED"),
        "commit": os.environ.get("COMMIT_SHA", "NOT_CONFIGURED"),
        "region": os.environ.get("REGION", "NOT_CONFIGURED"),
        "db": db_status,
        "secret": secret_status,
    }
    status_code = 200 if (db_status == "ok" and secret_status == "ok") else 503
    return jsonify(body), status_code
