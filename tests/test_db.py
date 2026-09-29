"""Connection configuration checks; never connect to the shared Oracle schema."""
import os
import unittest
from unittest.mock import MagicMock, patch

import db


class ConnectionSettingsChecks(unittest.TestCase):
    def test_default_connection_uses_provided_credentials_and_sid(self):
        with patch.dict(os.environ, {}, clear=True), patch.dict(db._pools, {}, clear=True), \
                patch.object(db.oracledb, 'create_pool') as create_pool:
            db.get_connection()
            args = create_pool.call_args.kwargs
            self.assertEqual(args['user'], 'KE2302_07')
            self.assertEqual(args['password'], 'KE2302_07')
            params = db.oracledb.ConnectParams()
            params.parse_connect_string(args['dsn'])
            self.assertEqual(params.host, '10.22.10.40')
            self.assertEqual(params.port, 1521)
            self.assertEqual(params.sid, 'ORCL')
            self.assertIsNone(params.service_name)

    def test_disposable_schema_can_override_defaults(self):
        settings = {'DB_USER': 'QWIZ_TEST', 'DB_PASSWORD': 'test-only',
                    'DB_DSN': db.oracledb.makedsn('test-host', 1521, sid='TEST')}
        with patch.dict(os.environ, settings, clear=True), patch.dict(db._pools, {}, clear=True), \
                patch.object(db.oracledb, 'create_pool') as create_pool:
            db.get_connection()
            args = create_pool.call_args.kwargs
            self.assertEqual(args['user'], settings['DB_USER'])
            self.assertEqual(args['password'], settings['DB_PASSWORD'])
            self.assertEqual(args['dsn'], settings['DB_DSN'])

    def test_reuses_pool_for_same_configuration(self):
        pool = MagicMock()
        with patch.dict(os.environ, {}, clear=True), patch.dict(db._pools, {}, clear=True), \
                patch.object(db.oracledb, 'create_pool', return_value=pool) as create_pool:
            db.get_connection()
            db.get_connection()
            create_pool.assert_called_once()
            self.assertEqual(pool.acquire.call_count, 2)


if __name__ == '__main__':
    unittest.main()
