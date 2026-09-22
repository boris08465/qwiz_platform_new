"""Fast checks; no Oracle connection is required."""
import unittest
from unittest.mock import patch
import oracledb
from jinja2 import StrictUndefined
import app as web


class AppChecks(unittest.TestCase):
    def setUp(self):
        web.app.config.update(TESTING=True)
        self.client = web.app.test_client()

    def test_public_pages(self):
        for path in ('/', '/register', '/login'):
            with self.subTest(path=path):
                self.assertEqual(self.client.get(path).status_code, 200)

    def test_protected_pages_redirect_to_login(self):
        for path in ('/dashboard', '/profile', '/tests', '/my-attempts', '/attempts/1', '/admin/users', '/author/tests'):
            response = self.client.get(path)
            self.assertEqual(response.status_code, 302)
            self.assertTrue(response.location.endswith('/login'))

    def test_invalid_login_input_never_calls_database(self):
        with patch.object(web, 'get_connection') as connect:
            for data in ({'user_id': '1', 'password': ''}, {'user_id': 'bad', 'password': 'test'}):
                self.assertEqual(self.client.post('/login', data=data).status_code, 200)
            connect.assert_not_called()

    def test_missing_page_and_oversized_upload(self):
        self.assertEqual(self.client.get('/not-a-page').status_code, 404)
        self.assertEqual(self.client.post('/register', data=b'x' * (6 * 1024 * 1024), content_type='application/x-www-form-urlencoded').status_code, 413)

    def test_database_outage_is_readable(self):
        with self.client.session_transaction() as state:
            state['user_id'] = 1
        with patch.object(web, 'get_connection', side_effect=oracledb.OperationalError('offline')):
            with self.assertLogs(web.app.logger, level='ERROR'):
                response = self.client.get('/tests')
            self.assertEqual(response.status_code, 503)
            self.assertIn('Проверьте подключение', response.get_data(as_text=True))

    def test_uid_and_role_navigation(self):
        user = {'user_id': 4321, 'user_name': 'Иван', 'role_name_code': 'USER', 'role_title': 'Пользователь', 'is_active': 1}
        with self.client.session_transaction() as state:
            state['user_id'] = 4321
        with patch.object(web, 'get_user_by_uid', return_value=user):
            for path in ('/dashboard', '/profile'):
                html = self.client.get(path).get_data(as_text=True)
                self.assertIn('4321', html)
                self.assertNotIn('Админ: пользователи', html)

    def test_result_does_not_fetch_answers_until_finished(self):
        with self.client.session_transaction() as state:
            state['user_id'] = 1
        result = (1, 1, None, None, 'STARTED', None, None, 1, 'Тест', 1, 0)
        with patch.object(web, 'require_auth', return_value=None), patch.object(web, 'fetch_cursor', return_value=[result]) as fetch:
            response = self.client.get('/attempts/1/result')
            self.assertEqual(response.location, '/attempts/1')
            fetch.assert_called_once_with('quiz_platform.get_attempt_result', [1, 1])

    def test_numeric_parser_rejects_nonfinite(self):
        for value in ('NaN', 'inf', '-inf', '1e999', 'wrong'):
            with self.assertRaises(ValueError):
                web.finite_number(value)
        self.assertEqual(web.finite_number('0'), 0)

    def test_all_templates_compile(self):
        for name in web.app.jinja_env.list_templates():
            web.app.jinja_env.get_template(name)


if __name__ == '__main__':
    unittest.main()
