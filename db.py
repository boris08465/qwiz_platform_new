import os
import oracledb


def get_connection():
    return oracledb.connect(
        user=os.getenv("DB_USER", "system"),
        password=os.getenv("DB_PASSWORD", "oracle"),
        dsn=os.getenv("DB_DSN", "localhost:1521/XEPDB1"),
    )

