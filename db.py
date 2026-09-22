import os
import atexit
from threading import Lock
import oracledb

_pools = {}
_pool_lock = Lock()


def get_connection():
    # A page performs several queries. Reuse bounded connections instead of
    # making Oracle spawn a new server process for every query.
    config = (
        os.getpid(),
        os.getenv("DB_USER", "KE2303_07"),
        os.getenv("DB_PASSWORD", "KE2303_07"),
        os.getenv("DB_DSN", "10.22.10.49:1521/ORCL"),
    )
    with _pool_lock:
        pool = _pools.get(config)
        if pool is None:
            pool = oracledb.create_pool(
                user=config[1], password=config[2], dsn=config[3],
                min=1, max=6, increment=1, timeout=60,
                getmode=oracledb.POOL_GETMODE_TIMEDWAIT, wait_timeout=5000,
                tcp_connect_timeout=5,
            )
            _pools[config] = pool
    # The connection context manager rolls back uncommitted work and returns
    # this connection to the pool on exit (including on exceptions).
    return pool.acquire()


@atexit.register
def close_pools():
    for config, pool in _pools.items():
        if config[0] == os.getpid():
            try:
                pool.close(force=True)
            except oracledb.Error:
                pass
    _pools.clear()
