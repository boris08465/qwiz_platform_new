"""Integration tests against a DISPOSABLE Oracle schema named QWIZ_TEST.

Set QWIZ_TEST_DSN, QWIZ_TEST_PASSWORD and install sql/00_install_all.sql first.
Each test clears application records in that dedicated schema.
"""
import os
import base64
import io
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from threading import Barrier
from unittest.mock import patch
import oracledb
from jinja2 import StrictUndefined
import app as web
from db import get_connection


@unittest.skipUnless(os.getenv('QWIZ_TEST_DSN'), 'Disposable Oracle database not configured')
class OracleWorkflows(unittest.TestCase):
    def setUp(self):
        self.env = patch.dict(os.environ, {
            'DB_USER': 'QWIZ_TEST', 'DB_PASSWORD': os.environ['QWIZ_TEST_PASSWORD'],
            'DB_DSN': os.environ['QWIZ_TEST_DSN'],
        })
        self.env.start()
        self.addCleanup(self.env.stop)
        web.app.config.update(TESTING=True)
        old_undefined = web.app.jinja_env.undefined
        web.app.jinja_env.undefined = StrictUndefined
        self.addCleanup(setattr, web.app.jinja_env, 'undefined', old_undefined)
        self.conn = get_connection()
        self.addCleanup(self.conn.close)
        self.cur = self.conn.cursor()
        self.addCleanup(self.cur.close)
        self.cur.execute('SELECT USER FROM dual')
        self.assertEqual(self.cur.fetchone()[0], 'QWIZ_TEST')
        for table in ('attempt_question_visit', 'answer_selected_option', 'answer', 'attempt', 'test_access',
                      'question_in_test', 'answer_option', 'question', 'test', 'users', 'category'):
            self.cur.execute('DELETE FROM ' + table)
        self.admin = self.fn('register_user_id', ['Администратор', 'testpass'])
        self.author = self.fn('register_user_id', ['Автор', 'testpass'])
        self.user = self.fn('register_user_id', ['Участник', 'testpass'])
        self.proc('set_user_role', [self.admin, self.author, 'AUTHOR'])
        self.proc('add_category', ['Математика', 'Тестовая категория'])
        self.cur.execute('SELECT id_category FROM category')
        self.category = self.cur.fetchone()[0]
        self.cur.execute("SELECT id_level FROM difficulty_level WHERE level_name = 'Легкий'")
        self.level = self.cur.fetchone()[0]
        self.cur.execute('SELECT type_code, type_id FROM question_type')
        self.types = dict(self.cur.fetchall())
        self.conn.commit()
        self.client = web.app.test_client()
        self.signin(self.user)

    def fn(self, name, args):
        return int(self.cur.callfunc('quiz_platform.' + name, int, args))

    def proc(self, name, args):
        self.cur.callproc('quiz_platform.' + name, args)

    def one(self, sql, **binds):
        self.cur.execute(sql, binds)
        return self.cur.fetchone()

    def signin(self, uid):
        with self.client.session_transaction() as state:
            state.clear()
            state['user_id'] = uid

    def question(self, kind='TEXT', owner=None):
        qid = self.fn('add_question_id', [owner or self.author, 'Вопрос ' + kind,
                      self.category, self.level, self.types[kind],
                      'ответ' if kind in ('TEXT', 'SHORT_TEXT') else None,
                      5 if kind == 'NUMBER' else None, 0, 'Пояснение'])
        if kind in ('SINGLE_CHOICE', 'MULTIPLE_CHOICE', 'TRUE_FALSE'):
            self.proc('add_answer_option', [qid, 'Верно', 1])
            self.proc('add_answer_option', [qid, 'Неверно', 0])
            if kind == 'MULTIPLE_CHOICE':
                self.proc('add_answer_option', [qid, 'Тоже верно', 1])
        return qid

    def make_test(self, kinds=('TEXT',), required=1, q_limit=None, time_limit=600, publish=True):
        tid = self.fn('create_test_id', [self.author, 'Проверочный тест', 'Описание', self.category, self.level, time_limit, 3, 1, len(kinds)])
        qts = []
        for order, kind in enumerate(kinds, 1):
            qid = self.question(kind)
            self.proc('include_question_in_test', [self.author, tid, qid, 1, order, required, q_limit])
            qts.append(self.one('SELECT id_qt FROM question_in_test WHERE id_test=:t AND id_question=:q', t=tid, q=qid)[0])
        if publish:
            self.proc('publish_test', [self.author, tid, 1])
        self.proc('grant_test_access', [self.author, tid, self.user])
        self.conn.commit()
        return tid, qts

    def start(self, tid):
        response = self.client.post(f'/tests/{tid}/start')
        self.assertEqual(response.status_code, 302)
        return int(response.location.rsplit('/', 1)[-1])

    def assert_db_error(self, name, args, code):
        with self.assertRaises(oracledb.DatabaseError) as caught:
            self.proc(name, args)
        self.assertEqual(caught.exception.args[0].code, code)
        self.conn.rollback()

    def test_complete_all_question_types(self):
        tid, qts = self.make_test(('SINGLE_CHOICE', 'MULTIPLE_CHOICE', 'TEXT', 'NUMBER', 'TRUE_FALSE', 'SHORT_TEXT'))
        aid = self.start(tid)
        self.assertEqual(self.start(tid), aid)
        self.assertEqual(self.one('SELECT COUNT(*) FROM attempt WHERE id_test=:t', t=tid)[0], 1)
        self.assertEqual(self.client.get(f'/tests/{tid}/start').status_code, 405)
        self.assertEqual(self.client.get(f'/attempts/{aid}/result').location, f'/attempts/{aid}')
        for qt in qts:
            response = self.client.get(f'/attempts/{aid}')
            self.assertEqual(response.status_code, 200)
            kind = self.one('SELECT ty.type_code FROM question_in_test qt JOIN question q ON q.id_question=qt.id_question JOIN question_type ty ON ty.type_id=q.type_id WHERE qt.id_qt=:qt', qt=qt)[0]
            data = {'id_qt': str(qt)}
            if kind in ('SINGLE_CHOICE', 'MULTIPLE_CHOICE', 'TRUE_FALSE'):
                self.cur.execute('SELECT o.id_option FROM answer_option o JOIN question_in_test qt ON qt.id_question=o.id_question WHERE qt.id_qt=:qt AND o.is_correct=1', qt=qt)
                data['selected_option_ids'] = [str(x[0]) for x in self.cur.fetchall()]
            elif kind == 'NUMBER':
                data['answer_number'] = '5'
            else:
                data['answer_text'] = '  ОТВЕТ  '
            self.assertEqual(self.client.post(f'/attempts/{aid}/answer', data=data).status_code, 302)
        self.assertIn('Все вопросы пройдены', self.client.get(f'/attempts/{aid}').get_data(as_text=True))
        result = self.client.post(f'/attempts/{aid}/finish', follow_redirects=True)
        self.assertEqual(result.status_code, 200)
        self.assertIn('100%', result.get_data(as_text=True))
        self.assertEqual(self.one('SELECT status, score, percent_result FROM attempt WHERE id_attempt=:a', a=aid), ('FINISHED', 6, 100))
        self.assertEqual(self.client.post(f'/attempts/{aid}/finish').status_code, 302)

    def test_all_pages_with_strict_template_variables(self):
        tid, qts = self.make_test(('TEXT', 'SINGLE_CHOICE'))
        aid = self.start(tid)
        qid = self.one('SELECT id_question FROM question_in_test WHERE id_qt=:q', q=qts[1])[0]
        paths = ['/', '/dashboard', '/profile', '/tests', '/my-attempts', f'/tests/{tid}', f'/attempts/{aid}']
        for path in paths:
            with self.subTest(path=path):
                self.assertEqual(self.client.get(path).status_code, 200)
        self.signin(self.author)
        for path in ['/author/categories', '/author/difficulty-levels', '/author/question-types', '/author/questions',
                     '/author/questions/create', '/author/tests', '/author/tests/create', f'/author/questions/{qid}',
                     f'/author/questions/{qid}/options', f'/author/tests/{tid}', f'/author/tests/{tid}/questions',
                     f'/author/tests/{tid}/access', f'/author/tests/{tid}/statistics']:
            with self.subTest(path=path):
                self.assertEqual(self.client.get(path).status_code, 200)
        self.signin(self.admin)
        for path in ['/admin/users', '/admin/tests', '/admin/questions', '/admin/categories', '/admin/statistics', '/admin/attempts']:
            self.assertEqual(self.client.get(path).status_code, 200)

    def test_invalid_and_empty_answers_do_not_consume_question(self):
        tid, qts = self.make_test(('NUMBER',))
        aid = self.start(tid)
        for value in ('', 'abc', 'NaN', 'inf', '1e999'):
            response = self.client.post(f'/attempts/{aid}/answer', data={'id_qt': qts[0], 'answer_number': value}, follow_redirects=True)
            self.assertEqual(response.status_code, 200)
            self.assertEqual(self.one('SELECT COUNT(*) FROM answer WHERE id_attempt=:a', a=aid)[0], 0)
        self.client.post(f'/attempts/{aid}/answer', data={'id_qt': qts[0], 'answer_number': '5'})
        self.assertEqual(self.one('SELECT COUNT(*) FROM answer WHERE id_attempt=:a', a=aid)[0], 1)

    def test_required_and_optional_questions(self):
        tid, qts = self.make_test(required=0)
        aid = self.start(tid)
        html = self.client.get(f'/attempts/{aid}').get_data(as_text=True)
        self.assertIn('Пропустить вопрос', html)
        self.client.post(f'/attempts/{aid}/answer', data={'id_qt': qts[0], 'skip': '1'})
        self.client.post(f'/attempts/{aid}/finish')
        self.assertEqual(self.one('SELECT status, score FROM attempt WHERE id_attempt=:a', a=aid), ('FINISHED', 0))
        tid, qts = self.make_test(required=1)
        aid = self.start(tid)
        self.client.post(f'/attempts/{aid}/answer', data={'id_qt': qts[0], 'skip': '1'})
        self.client.post(f'/attempts/{aid}/finish')
        self.assertEqual(self.one('SELECT status FROM attempt WHERE id_attempt=:a', a=aid)[0], 'STARTED')

    def test_question_timer_persists_across_reload(self):
        tid, qts = self.make_test(q_limit=10)
        aid = self.start(tid)
        self.client.get(f'/attempts/{aid}')
        self.cur.execute('UPDATE attempt_question_visit SET started_at=SYSDATE-20/86400 WHERE id_attempt=:a', a=aid)
        self.conn.commit()
        self.assertIn('data-seconds="0"', self.client.get(f'/attempts/{aid}').get_data(as_text=True))
        self.client.post(f'/attempts/{aid}/answer', data={'id_qt': qts[0], 'answer_text': 'ответ', 'answer_time': '0'})
        self.client.post(f'/attempts/{aid}/finish')
        self.assertEqual(self.one('SELECT score FROM attempt WHERE id_attempt=:a', a=aid)[0], 0)
        self.assertEqual(self.one('SELECT is_checked, is_correct FROM answer WHERE id_attempt=:a', a=aid), (1, 0))

    def test_expired_question_auto_advance(self):
        tid, qts = self.make_test(q_limit=10)
        aid = self.start(tid)
        self.client.get(f'/attempts/{aid}')
        self.client.post(f'/attempts/{aid}/answer', data={'id_qt': qts[0], 'timeout': '1'})
        self.assertEqual(self.one('SELECT COUNT(*) FROM answer WHERE id_attempt=:a', a=aid)[0], 0)
        self.cur.execute('UPDATE attempt_question_visit SET started_at=SYSDATE-20/86400 WHERE id_attempt=:a', a=aid)
        self.conn.commit()
        self.client.post(f'/attempts/{aid}/answer', data={'id_qt': qts[0], 'timeout': '1'})
        self.assertEqual(self.one('SELECT COUNT(*) FROM answer WHERE id_attempt=:a', a=aid)[0], 1)

    def test_expired_test_is_committed_even_without_redirect(self):
        tid, qts = self.make_test(time_limit=10)
        aid = self.start(tid)
        self.cur.execute('UPDATE attempt SET start_date=SYSDATE-20/86400 WHERE id_attempt=:a', a=aid)
        self.conn.commit()
        response = self.client.post(f'/attempts/{aid}/answer', data={'id_qt': qts[0], 'answer_text': 'ответ'})
        self.assertTrue(response.location.endswith('/result'))
        self.assertEqual(self.one('SELECT status, score FROM attempt WHERE id_attempt=:a', a=aid), ('TIME_EXPIRED', 0))

    def test_immutable_started_tests_and_question_keys(self):
        tid, qts = self.make_test(('MULTIPLE_CHOICE',))
        self.start(tid)
        self.proc('publish_test', [self.author, tid, 1])
        self.conn.commit()
        qid = self.one('SELECT id_question FROM question_in_test WHERE id_qt=:q', q=qts[0])[0]
        self.assert_db_error('include_question_in_test', [self.author, tid, qid, 1, 2, 1, None], 20120)
        self.assert_db_error('generate_test_questions', [self.author, tid], 20120)
        self.assert_db_error('add_answer_option', [qid, 'Поздний вариант', 1], 20122)

    def test_publication_requires_complete_questions(self):
        tid = self.fn('create_test_id', [self.author, 'Пустой', None, self.category, self.level, None, 1, 1, 1])
        qid = self.fn('add_question_id', [self.author, 'Неполный', self.category, self.level, self.types['SINGLE_CHOICE'], None, None, None, None])
        self.proc('include_question_in_test', [self.author, tid, qid, 1, 1, 1, None])
        self.conn.commit()
        self.assert_db_error('publish_test', [self.author, tid, 1], 20123)
        self.proc('add_answer_option', [qid, 'Да', 1])
        self.proc('add_answer_option', [qid, 'Нет', 0])
        self.proc('publish_test', [self.author, tid, 1])
        self.conn.commit()
        self.assertEqual(self.one('SELECT is_active FROM test WHERE id_test=:t', t=tid)[0], 1)

    def test_reference_sequences_and_custom_type(self):
        self.proc('add_difficulty_level', ['Уровень ' + str(self.admin)])
        self.proc('add_question_type', ['Тип ' + str(self.admin)])
        self.conn.commit()
        self.assertIsNotNone(self.one('SELECT type_id FROM question_type WHERE type_name=:n', n='Тип ' + str(self.admin)))

    def test_author_cannot_modify_another_authors_question(self):
        tid, qts = self.make_test(('SINGLE_CHOICE',), publish=False)
        qid = self.one('SELECT id_question FROM question_in_test WHERE id_qt=:q', q=qts[0])[0]
        self.proc('set_user_role', [self.admin, self.user, 'AUTHOR'])
        self.conn.commit()
        self.signin(self.user)
        response = self.client.post(f'/author/questions/{qid}/options', data={'option_text': 'Чужой', 'is_correct': '1'})
        self.assertEqual(response.location, '/author/questions')
        self.assertEqual(self.client.get(f'/author/tests/{tid}/questions').location, '/author/tests')
        self.assertEqual(self.one('SELECT COUNT(*) FROM answer_option WHERE id_question=:q', q=qid)[0], 2)

    def test_admin_manages_other_authors_questions_tests_and_access(self):
        tid, qts = self.make_test(('SINGLE_CHOICE',), publish=False)
        qid = self.one('SELECT id_question FROM question_in_test WHERE id_qt=:q', q=qts[0])[0]
        extra = self.question('NUMBER', owner=self.admin)
        self.conn.commit()
        self.signin(self.admin)
        for path in [f'/author/questions/{qid}', f'/author/questions/{qid}/options',
                     f'/author/tests/{tid}', f'/author/tests/{tid}/questions',
                     f'/author/tests/{tid}/access', f'/author/tests/{tid}/statistics']:
            with self.subTest(path=path):
                self.assertEqual(self.client.get(path).status_code, 200)
        self.assertIn(f'/author/tests/{tid}', self.client.get('/admin/tests').get_data(as_text=True))
        self.assertIn(f'/author/questions/{qid}', self.client.get('/admin/questions').get_data(as_text=True))
        self.client.post(f'/author/questions/{qid}/options', data={'option_text': 'Добавлен админом', 'is_correct': '0'})
        added = self.one('SELECT id_option FROM answer_option WHERE option_text=:t', t='Добавлен админом')[0]
        self.client.post(f'/author/questions/{qid}/options/{added}/delete')
        self.assertEqual(self.one('SELECT COUNT(*) FROM answer_option WHERE id_question=:q', q=qid)[0], 2)
        self.client.post(f'/author/tests/{tid}/questions', data={'id_question': extra, 'weight': '1', 'order_num': '2', 'is_required': '1'})
        self.assertEqual(self.one('SELECT COUNT(*) FROM question_in_test WHERE id_test=:t', t=tid)[0], 2)
        self.client.post(f'/author/tests/{tid}/questions/{extra}/delete')
        self.assertEqual(self.one('SELECT COUNT(*) FROM question_in_test WHERE id_test=:t', t=tid)[0], 1)
        self.client.post(f'/author/tests/{tid}/access/{self.user}/deactivate')
        self.assertEqual(self.one('SELECT is_active FROM test_access WHERE id_test=:t AND user_id=:u', t=tid, u=self.user)[0], 0)
        self.client.post(f'/author/tests/{tid}/access', data={'user_id': self.user})
        self.assertEqual(self.one('SELECT is_active FROM test_access WHERE id_test=:t AND user_id=:u', t=tid, u=self.user)[0], 1)
        self.client.post(f'/author/tests/{tid}/publish')
        self.assertEqual(self.one('SELECT is_active, uid_author FROM test WHERE id_test=:t', t=tid), (1, self.author))
        self.client.post(f'/author/questions/{extra}/deactivate')
        self.assertEqual(self.one('SELECT is_active FROM question WHERE id_question=:q', q=extra)[0], 0)

    def test_admin_generates_from_all_authors(self):
        tid, qts = self.make_test(publish=False)
        first = self.one('SELECT id_question FROM question_in_test WHERE id_qt=:q', q=qts[0])[0]
        second = self.question(owner=self.admin)
        self.cur.execute('UPDATE test SET question_count=2 WHERE id_test=:t', t=tid)
        self.conn.commit()
        self.signin(self.admin)
        self.assertIn(f'value="{second}"', self.client.get(f'/author/tests/{tid}/questions').get_data(as_text=True))
        self.client.post(f'/author/tests/{tid}/generate')
        self.cur.execute('SELECT id_question FROM question_in_test WHERE id_test=:t', t=tid)
        self.assertEqual({q[0] for q in self.cur.fetchall()}, {first, second})
        self.assertEqual(self.one('SELECT uid_author FROM test WHERE id_test=:t', t=tid)[0], self.author)

    def test_admin_can_take_hidden_tests_without_access_or_attempt_limit(self):
        tid, qts = self.make_test(publish=False)
        self.cur.execute('UPDATE test SET attempt_limit=1 WHERE id_test=:t', t=tid)
        self.conn.commit()
        self.assertEqual(self.client.get(f'/tests/{tid}').status_code, 302)
        self.signin(self.admin)
        self.assertIn(f'/tests/{tid}', self.client.get('/tests').get_data(as_text=True))
        self.assertEqual(self.client.get(f'/tests/{tid}').status_code, 200)
        for _ in range(2):
            aid = self.start(tid)
            self.client.post(f'/attempts/{aid}/answer', data={'id_qt': qts[0], 'answer_text': 'ответ'})
            self.client.post(f'/attempts/{aid}/finish')
            self.assertEqual(self.one('SELECT status, percent_result FROM attempt WHERE id_attempt=:a', a=aid), ('FINISHED', 100))
        self.assertEqual(self.one('SELECT COUNT(*) FROM test_access WHERE user_id=:u', u=self.admin)[0], 0)
        self.assertEqual(self.one('SELECT COUNT(*) FROM attempt WHERE user_id=:u', u=self.admin)[0], 2)
        self.proc('publish_test', [self.author, tid, 1])
        self.conn.commit()
        self.signin(self.user)
        aid = self.start(tid)
        self.client.post(f'/attempts/{aid}/answer', data={'id_qt': qts[0], 'answer_text': 'ответ'})
        self.client.post(f'/attempts/{aid}/finish')
        self.assertEqual(self.client.post(f'/tests/{tid}/start').location, f'/tests/{tid}')
        self.assertEqual(self.one('SELECT COUNT(*) FROM attempt WHERE user_id=:u', u=self.user)[0], 1)

    def test_admin_opens_and_completes_other_users_attempt(self):
        tid, qts = self.make_test()
        self.cur.execute('UPDATE test SET show_feedback=0 WHERE id_test=:t', t=tid)
        self.conn.commit()
        aid = self.start(tid)
        self.signin(self.author)
        self.assertEqual(self.client.get('/admin/attempts').status_code, 302)
        self.assertEqual(self.client.get(f'/attempts/{aid}').location, '/my-attempts')
        self.assertEqual(self.client.get(f'/attempts/{aid}/result').location, '/my-attempts')
        self.signin(self.admin)
        page = self.client.get('/admin/attempts').get_data(as_text=True)
        self.assertIn(f'/attempts/{aid}', page)
        page = self.client.get(f'/attempts/{aid}').get_data(as_text=True)
        self.assertIn('Режим администратора', page)
        self.client.post(f'/attempts/{aid}/answer', data={'id_qt': qts[0], 'answer_text': 'ответ'})
        self.client.post(f'/attempts/{aid}/finish')
        self.assertEqual(self.one('SELECT user_id, status, percent_result FROM attempt WHERE id_attempt=:a', a=aid), (self.user, 'FINISHED', 100))
        result = self.client.get(f'/attempts/{aid}/result').get_data(as_text=True)
        self.assertIn('Обратная связь', result)
        self.assertIn('Ответ участника: ответ', result)
        self.signin(self.user)
        self.assertNotIn('Обратная связь', self.client.get(f'/attempts/{aid}/result').get_data(as_text=True))

    def test_admin_preserves_integrity_and_loses_access_after_demotion(self):
        tid, qts = self.make_test()
        self.start(tid)
        self.assert_db_error('generate_test_questions', [self.admin, tid], 20120)
        other_admin = self.fn('register_user_id', ['Другой администратор', 'testpass'])
        self.proc('set_user_role', [self.admin, other_admin, 'ADMIN'])
        self.proc('set_user_role', [other_admin, self.admin, 'USER'])
        self.conn.commit()
        self.signin(self.admin)
        self.assertEqual(self.client.get('/admin/attempts').status_code, 302)
        self.assertEqual(self.client.get(f'/tests/{tid}').location, '/tests')
        self.assertEqual(self.client.get(f'/author/tests/{tid}').location, '/dashboard')

    def test_autogeneration_uses_ready_questions_of_owner(self):
        own = self.question()
        other = self.question(owner=self.admin)
        tid = self.fn('create_test_id', [self.author, 'Генерация', None, self.category, self.level, None, 1, 1, 1])
        self.proc('generate_test_questions', [self.author, tid])
        self.assertEqual(self.one('SELECT id_question FROM question_in_test WHERE id_test=:t', t=tid)[0], own)
        self.conn.commit()
        self.cur.execute('UPDATE test SET question_count=2 WHERE id_test=:t', t=tid)
        self.conn.commit()
        self.assert_db_error('generate_test_questions', [self.author, tid], 20111)
        self.assertEqual(self.one('SELECT id_question FROM question_in_test WHERE id_test=:t', t=tid)[0], own)

    def test_admin_role_assignment_and_navigation_refresh(self):
        self.signin(self.admin)
        response = self.client.post(f'/admin/users/{self.user}/role', data={'role_code': 'AUTHOR'}, follow_redirects=True)
        self.assertEqual(response.status_code, 200)
        self.signin(self.user)
        self.assertIn('Тесты автора', self.client.get('/dashboard').get_data(as_text=True))

    def test_real_login_and_registration(self):
        self.client.get('/logout')
        response = self.client.post('/login', data={'user_id': self.user, 'password': 'testpass'}, follow_redirects=True)
        self.assertIn(str(self.user), response.get_data(as_text=True))
        self.client.get('/logout')
        response = self.client.post('/register', data={'user_name': 'Новый', 'password': '1234', 'password_repeat': '1234'}, follow_redirects=True)
        self.assertIn('Регистрация успешно', response.get_data(as_text=True))

    def test_form_errors_preserve_question(self):
        self.signin(self.author)
        response = self.client.post('/author/questions/create', data={'question_text': 'Сохрани меня', 'id_category': self.category,
                    'id_level': self.level, 'type_id': self.types['NUMBER'], 'correct_number': 'bad'})
        self.assertEqual(response.status_code, 200)
        self.assertIn('Сохрани меня', response.get_data(as_text=True))

    def test_edit_draft_question_options_and_composition(self):
        tid, qts = self.make_test(('SINGLE_CHOICE',), publish=False)
        qid = self.one('SELECT id_question FROM question_in_test WHERE id_qt=:q', q=qts[0])[0]
        option = self.one('SELECT id_option FROM answer_option WHERE id_question=:q AND is_correct=0', q=qid)[0]
        self.signin(self.author)
        response = self.client.post(f'/author/questions/{qid}/options/{option}/delete', follow_redirects=True)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(self.one('SELECT COUNT(*) FROM answer_option WHERE id_question=:q', q=qid)[0], 1)
        self.client.post(f'/author/questions/{qid}/options', data={'option_text': 'Новый неверный', 'is_correct': '0'})
        self.assertEqual(self.one('SELECT COUNT(*) FROM answer_option WHERE id_question=:q', q=qid)[0], 2)
        self.client.post(f'/author/tests/{tid}/questions/{qid}/delete')
        self.assertEqual(self.one('SELECT COUNT(*) FROM question_in_test WHERE id_test=:t', t=tid)[0], 0)
        response = self.client.post(f'/author/tests/{tid}/questions', data={
            'id_question': qid, 'weight': '2.5', 'order_num': '1', 'is_required': '1', 'time_limit': ''}, follow_redirects=True)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(self.one('SELECT weight FROM question_in_test WHERE id_test=:t', t=tid)[0], 2.5)
        self.client.post(f'/author/tests/{tid}/publish')
        self.signin(self.user)
        aid = self.start(tid)
        qt = self.one('SELECT id_qt FROM question_in_test WHERE id_test=:t', t=tid)[0]
        correct = self.one('SELECT id_option FROM answer_option WHERE id_question=:q AND is_correct=1', q=qid)[0]
        self.client.post(f'/attempts/{aid}/answer', data={'id_qt': qt, 'selected_option_ids': str(correct)})
        self.client.post(f'/attempts/{aid}/finish')
        self.assertEqual(self.one('SELECT score, percent_result FROM attempt WHERE id_attempt=:a', a=aid), (2.5, 100))

    def test_image_upload_is_served_and_invalid_upload_rolls_back(self):
        self.signin(self.author)
        image = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a9WQAAAAASUVORK5CYII=')
        data = {'question_text': 'Вопрос с картинкой', 'id_category': self.category,
                'id_level': self.level, 'type_id': self.types['TEXT'], 'correct_text': 'ответ'}
        with tempfile.TemporaryDirectory(dir=web.app.static_folder, prefix='qwiz-test-') as folder:
            prefix = Path(folder).name
            with patch.object(web, 'QUESTION_UPLOAD_DIR', Path(folder)), patch.object(web, 'QUESTION_UPLOAD_PREFIX', prefix):
                response = self.client.post('/author/questions/create', data={**data, 'question_image': (io.BytesIO(image), 'photo.png')}, follow_redirects=True)
                self.assertEqual(response.status_code, 200)
                image_path = self.one('SELECT image_path FROM question WHERE question_text=:t', t=data['question_text'])[0]
                self.assertIn(image_path, response.get_data(as_text=True))
                with self.client.get('/static/' + image_path) as served:
                    self.assertEqual(served.status_code, 200)
                    self.assertEqual(served.data, image)
                response = self.client.post('/author/questions/create', data={**data, 'question_image': (io.BytesIO(b'bad'), 'bad.txt')})
                self.assertEqual(response.status_code, 200)
                self.assertEqual(self.one('SELECT COUNT(*) FROM question')[0], 1)
                self.assertEqual(len(list(Path(folder).iterdir())), 1)

    def test_simultaneous_start_and_duplicate_answers(self):
        tid, qts = self.make_test()
        def concurrent_action(action):
            barrier = Barrier(2)
            def run():
                with get_connection() as conn:
                    with conn.cursor() as cur:
                        barrier.wait(timeout=10)
                        try:
                            value = action(cur)
                            conn.commit()
                            return value
                        except oracledb.DatabaseError as exc:
                            conn.rollback()
                            return ('error', exc.args[0].code)
            with ThreadPoolExecutor(max_workers=2) as pool:
                futures = [pool.submit(run) for _ in range(2)]
                return [f.result(timeout=20) for f in futures]
        ids = concurrent_action(lambda cur: int(cur.callfunc('quiz_platform.start_attempt_id', int, [tid, self.user])))
        self.assertEqual(ids[0], ids[1])
        self.assertEqual(self.one('SELECT COUNT(*) FROM attempt WHERE id_test=:t', t=tid)[0], 1)
        results = concurrent_action(lambda cur: int(cur.callfunc('quiz_platform.save_answer_id', int, [ids[0], qts[0], 'ответ', None, 0, self.user])))
        self.assertEqual(sum(isinstance(x, int) for x in results), 1)
        self.assertEqual(self.one('SELECT COUNT(*) FROM answer WHERE id_attempt=:a', a=ids[0])[0], 1)
        self.client.post(f'/attempts/{ids[0]}/finish')
        self.assertEqual(self.one('SELECT status, percent_result FROM attempt WHERE id_attempt=:a', a=ids[0]), ('FINISHED', 100))


if __name__ == '__main__':
    unittest.main()
