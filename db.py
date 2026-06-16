import os
import oracledb


def get_connection():
    return oracledb.connect(
        user=os.getenv("DB_USER", "KE2303_07"),
        password=os.getenv("DB_PASSWORD", "KE2303_07"),
        dsn=os.getenv("DB_DSN", "10.22.10.49:1521/ORCL"),
    )

