"""Shared private PostgreSQL and Secret Manager access.

Only the two resource *names* are supplied as environment variables.
Credentials are retrieved at runtime using the Cloud Run service identity.
"""
import os
from functools import lru_cache

from google.cloud import secretmanager
from google.cloud.sql.connector import Connector, IPTypes


@lru_cache(maxsize=1)
def _secret_client():
    return secretmanager.SecretManagerServiceClient()


@lru_cache(maxsize=1)
def _sql_connector():
    # LAZY is appropriate for Cloud Run's CPU-on-request environment.
    return Connector(refresh_strategy="LAZY")


def read_secret(env_var_name: str) -> str:
    """Read *the current version* from Secret Manager, never a local secret."""
    version = os.environ[env_var_name]
    response = _secret_client().access_secret_version(request={"name": version})
    value = response.payload.data.decode("utf-8")
    if not value:
        raise RuntimeError(f"Secret named by {env_var_name} has no data")
    return value


def connect_db(password: str):
    """Secure Cloud SQL Connector via *private* IP (Direct VPC egress)."""
    return _sql_connector().connect(
        os.environ["INSTANCE_CONNECTION_NAME"],
        "pg8000",
        user=os.environ["DB_USER"],
        password=password,
        db=os.environ["DB_NAME"],
        ip_type=IPTypes.PRIVATE,
    )


def query_database(password: str) -> bool:
    """Run a real query on every /health HTTP request."""
    connection = connect_db(password)
    try:
        cursor = connection.cursor()
        try:
            cursor.execute("SELECT 1")
            row = cursor.fetchone()
            return row is not None and row[0] == 1
        finally:
            cursor.close()
    finally:
        connection.close()
