import os
import oracledb


def get_connection():
    return oracledb.connect(
        user=os.getenv("DB_USER", "quiz_user"),
        password=os.getenv("DB_PASSWORD", "quiz_pass"),
        dsn=os.getenv("DB_DSN", "localhost:1521/FREEPDB1"),
    )

