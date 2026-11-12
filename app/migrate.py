"""Database migration runner executed only as a private Cloud Run Job.

A laptop triggers the job via gcloud; no direct internet/laptop DB connection.
Each SQL file should contain a migration that is safe to execute in one transaction.
"""
from pathlib import Path
from db import connect_db, read_secret


def migrate():
    password = read_secret("DB_PASSWORD_SECRET")
    connection = connect_db(password)
    try:
        cursor = connection.cursor()
        try:
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS schema_migrations (
                  filename TEXT PRIMARY KEY,
                  applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
                )
            """)
            connection.commit()
            for migration in sorted(Path(__file__).parent.joinpath("migrations").glob("*.sql")):
                cursor.execute("SELECT 1 FROM schema_migrations WHERE filename = %s", (migration.name,))
                if cursor.fetchone():
                    print(f"Already applied: {migration.name}")
                    continue
                # Each file contains exactly one SQL statement in this demo.
                cursor.execute(migration.read_text(encoding="utf-8"))
                cursor.execute("INSERT INTO schema_migrations (filename) VALUES (%s)", (migration.name,))
                connection.commit()
                print(f"Applied: {migration.name}")
        finally:
            cursor.close()
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


if __name__ == "__main__":
    migrate()
