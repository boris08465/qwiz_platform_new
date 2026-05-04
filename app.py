import os

import oracledb
from flask import Flask, flash, redirect, render_template, request, session, url_for

from db import get_connection

app = Flask(__name__)
app.secret_key = os.getenv('SECRET_KEY', 'change-me')

ROLE_MAP = {1: 'Пользователь', 2: 'Автор', 3: 'Администратор'}


def get_user_by_uid(uid):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                '''
                SELECT u.uid, u.user_name, u.id_role, r.role_name, u.is_active
                FROM users u
                JOIN role r ON r.id_role = u.id_role
                WHERE u.uid = :uid
                ''',
                {'uid': uid},
            )
            row = cur.fetchone()
    if not row:
        return None
    return {
        'uid': row[0],
        'user_name': row[1],
        'id_role': row[2],
        'role_name_code': row[3],
        'is_active': row[4],
    }


def require_auth():
    if 'uid' not in session:
        flash('Сначала выполните вход.', 'error')
        return redirect(url_for('login_page'))
    return None


def require_author_role():
    auth = require_auth()
    if auth:
        return auth
    if session.get('role_id') not in (2, 3):
        flash('Доступ только для автора или администратора.', 'error')
        return redirect(url_for('dashboard_page'))
    return None


def fetch_list(sql, params=None):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params or {})
            return cur.fetchall()


@app.get('/')
def index():
    return render_template('index.html')


@app.route('/register', methods=['GET', 'POST'])
def register_page():
    if request.method == 'POST':
        user_name = request.form.get('user_name', '').strip()
        password = request.form.get('password', '')
        password_repeat = request.form.get('password_repeat', '')
        if not user_name:
            flash('Введите имя пользователя.', 'error')
            return render_template('register.html')
        if not password:
            flash('Введите пароль.', 'error')
            return render_template('register.html')
        if password != password_repeat:
            flash('Пароли не совпадают.', 'error')
            return render_template('register.html')
        try:
            with get_connection() as conn:
                with conn.cursor() as cur:
                    cur.callproc('quiz_platform.register_user', [user_name, password])
                    cur.execute('SELECT seq_users.CURRVAL FROM dual')
                    new_uid = cur.fetchone()[0]
                conn.commit()
            flash(f'Регистрация успешно завершена. Ваш UID: {new_uid}. Используйте этот UID для входа в систему.', 'success')
            return redirect(url_for('login_page'))
        except oracledb.DatabaseError as exc:
            flash(f'Ошибка регистрации: {exc.args[0].message}', 'error')
    return render_template('register.html')


@app.route('/login', methods=['GET', 'POST'])
def login_page():
    if request.method == 'POST':
        uid_raw = request.form.get('uid', '').strip()
        password = request.form.get('password', '')
        if not uid_raw.isdigit():
            flash('UID должен быть числом.', 'error')
            return render_template('login.html')
        try:
            uid = int(uid_raw)
            with get_connection() as conn:
                with conn.cursor() as cur:
                    role_id = int(cur.callfunc('quiz_platform.login_user', int, [uid, password]))
            user = get_user_by_uid(uid)
            if not user:
                flash('Пользователь не найден.', 'error')
                return render_template('login.html')
            session['uid'] = user['uid']
            session['user_name'] = user['user_name']
            session['role_id'] = role_id
            session['role_title'] = ROLE_MAP.get(role_id, 'Пользователь')
            return redirect(url_for('dashboard_page'))
        except oracledb.DatabaseError as exc:
            flash(f'Ошибка входа: {exc.args[0].message}', 'error')
    return render_template('login.html')


@app.get('/logout')
def logout_page():
    session.clear()
    flash('Вы вышли из системы.', 'success')
    return redirect(url_for('login_page'))


@app.get('/dashboard')
def dashboard_page():
    auth = require_auth()
    if auth:
        return auth
    return render_template('dashboard.html', uid=session['uid'], user_name=session['user_name'], role_title=session['role_title'])


@app.get('/profile')
def profile_page():
    auth = require_auth()
    if auth:
        return auth
    user = get_user_by_uid(session['uid'])
    return render_template('profile.html', uid=user['uid'], user_name=user['user_name'], role_title=ROLE_MAP.get(user['id_role'], 'Пользователь'), role_name_code=user['role_name_code'], is_active=user['is_active'])


@app.get('/author/categories')
def author_categories_page():
    access = require_author_role()
    if access:
        return access
    categories = fetch_list('SELECT id_category, category_name, category_description FROM category ORDER BY category_name')
    return render_template('author_categories.html', categories=categories)


@app.post('/author/categories')
def author_categories_create():
    access = require_author_role()
    if access:
        return access
    name = request.form.get('category_name', '').strip()
    description = request.form.get('category_description', '').strip() or None
    if not name:
        flash('Название категории обязательно.', 'error')
        return redirect(url_for('author_categories_page'))
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute('INSERT INTO category (category_name, category_description) VALUES (:n, :d)', {'n': name, 'd': description})
            conn.commit()
        flash('Категория создана.', 'success')
    except oracledb.DatabaseError as exc:
        flash(f'Ошибка создания категории: {exc.args[0].message}', 'error')
    return redirect(url_for('author_categories_page'))


@app.get('/author/difficulty-levels')
def author_difficulty_levels_page():
    access = require_author_role()
    if access:
        return access
    levels = fetch_list('SELECT id_level, level_name FROM difficulty_level ORDER BY id_level')
    return render_template('author_difficulty_levels.html', levels=levels)


@app.post('/author/difficulty-levels')
def author_difficulty_levels_create():
    access = require_author_role()
    if access:
        return access
    level_name = request.form.get('level_name', '').strip()
    if not level_name:
        flash('Название уровня обязательно.', 'error')
        return redirect(url_for('author_difficulty_levels_page'))
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute('INSERT INTO difficulty_level (level_name) VALUES (:n)', {'n': level_name})
            conn.commit()
        flash('Уровень сложности создан.', 'success')
    except oracledb.DatabaseError as exc:
        flash(f'Ошибка создания уровня: {exc.args[0].message}', 'error')
    return redirect(url_for('author_difficulty_levels_page'))


@app.get('/author/question-types')
def author_question_types_page():
    access = require_author_role()
    if access:
        return access
    types = fetch_list('SELECT type_id, type_name FROM question_type ORDER BY type_id')
    return render_template('author_question_types.html', types=types)


@app.post('/author/question-types')
def author_question_types_create():
    access = require_author_role()
    if access:
        return access
    type_name = request.form.get('type_name', '').strip()
    if not type_name:
        flash('Название типа обязательно.', 'error')
        return redirect(url_for('author_question_types_page'))
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.callproc('quiz_platform.add_question_type', [type_name])
            conn.commit()
        flash('Тип вопроса создан.', 'success')
    except oracledb.DatabaseError as exc:
        flash(f'Ошибка создания типа: {exc.args[0].message}', 'error')
    return redirect(url_for('author_question_types_page'))


@app.get('/author/questions')
def author_questions_page():
    access = require_author_role()
    if access:
        return access
    questions = fetch_list(
        '''
        SELECT q.id_question, q.question_text, qt.type_name, c.category_name, d.level_name, q.is_active
        FROM question q
        JOIN question_type qt ON qt.type_id = q.type_id
        JOIN category c ON c.id_category = q.id_category
        JOIN difficulty_level d ON d.id_level = q.id_level
        WHERE q.uid_author = :uid
        ORDER BY q.id_question DESC
        ''',
        {'uid': session['uid']},
    )
    return render_template('author_questions.html', questions=questions)


@app.get('/author/questions/create')
def create_question_page():
    access = require_author_role()
    if access:
        return access
    categories = fetch_list('SELECT id_category, category_name FROM category ORDER BY category_name')
    levels = fetch_list('SELECT id_level, level_name FROM difficulty_level ORDER BY id_level')
    types = fetch_list('SELECT type_id, type_name FROM question_type ORDER BY type_id')
    return render_template('create_question.html', categories=categories, levels=levels, types=types)


@app.post('/author/questions/create')
def create_question_submit():
    access = require_author_role()
    if access:
        return access

    form = request.form
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.callproc(
                    'quiz_platform.add_question',
                    [
                        session['uid'],
                        form.get('question_text', '').strip(),
                        int(form.get('id_category')),
                        int(form.get('id_level')),
                        int(form.get('type_id')),
                        form.get('correct_text') or None,
                        float(form.get('correct_number')) if form.get('correct_number') else None,
                        float(form.get('tolerance')) if form.get('tolerance') else None,
                        form.get('explanation') or None,
                    ],
                )
                cur.execute('SELECT seq_question.CURRVAL FROM dual')
                new_question_id = cur.fetchone()[0]
            conn.commit()
        flash('Вопрос создан.', 'success')
        return redirect(url_for('author_question_detail_page', id_question=new_question_id))
    except (ValueError, TypeError):
        flash('Некорректные числовые параметры.', 'error')
    except oracledb.DatabaseError as exc:
        flash(f'Ошибка создания вопроса: {exc.args[0].message}', 'error')
    return redirect(url_for('create_question_page'))


@app.get('/author/questions/<int:id_question>')
def author_question_detail_page(id_question):
    access = require_author_role()
    if access:
        return access
    rows = fetch_list(
        '''
        SELECT q.id_question, q.question_text, q.explanation, q.correct_text, q.correct_number, q.tolerance,
               q.is_active, qt.type_name, c.category_name, d.level_name
        FROM question q
        JOIN question_type qt ON qt.type_id = q.type_id
        JOIN category c ON c.id_category = q.id_category
        JOIN difficulty_level d ON d.id_level = q.id_level
        WHERE q.id_question = :id_question AND q.uid_author = :uid
        ''',
        {'id_question': id_question, 'uid': session['uid']},
    )
    if not rows:
        flash('Вопрос не найден.', 'error')
        return redirect(url_for('author_questions_page'))
    return render_template('question_detail.html', q=rows[0])


@app.post('/author/questions/<int:id_question>/deactivate')
def author_question_deactivate(id_question):
    access = require_author_role()
    if access:
        return access
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    'UPDATE question SET is_active = 0 WHERE id_question = :id_question AND uid_author = :uid',
                    {'id_question': id_question, 'uid': session['uid']},
                )
                if cur.rowcount == 0:
                    flash('Вопрос не найден.', 'error')
                else:
                    flash('Вопрос деактивирован.', 'success')
            conn.commit()
    except oracledb.DatabaseError as exc:
        flash(f'Ошибка деактивации: {exc.args[0].message}', 'error')
    return redirect(url_for('author_question_detail_page', id_question=id_question))


@app.get('/author/questions/<int:id_question>/options')
def author_question_options_page(id_question):
    access = require_author_role()
    if access:
        return access
    question = fetch_list('SELECT id_question, question_text FROM question WHERE id_question = :id_question AND uid_author = :uid', {'id_question': id_question, 'uid': session['uid']})
    if not question:
        flash('Вопрос не найден.', 'error')
        return redirect(url_for('author_questions_page'))
    options = fetch_list('SELECT id_option, option_text, is_correct FROM answer_option WHERE id_question = :id_question ORDER BY id_option', {'id_question': id_question})
    return render_template('question_options.html', question=question[0], options=options)


@app.post('/author/questions/<int:id_question>/options')
def author_question_options_create(id_question):
    access = require_author_role()
    if access:
        return access
    option_text = request.form.get('option_text', '').strip()
    is_correct = 1 if request.form.get('is_correct') == '1' else 0
    if not option_text:
        flash('Текст варианта обязателен.', 'error')
        return redirect(url_for('author_question_options_page', id_question=id_question))
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.callproc('quiz_platform.add_answer_option', [id_question, option_text, is_correct])
            conn.commit()
        flash('Вариант ответа добавлен.', 'success')
    except oracledb.DatabaseError as exc:
        flash(f'Ошибка добавления варианта: {exc.args[0].message}', 'error')
    return redirect(url_for('author_question_options_page', id_question=id_question))


@app.get('/tests')
def tests_page():
    return render_template('tests.html')


@app.get('/tests/<int:id_test>')
def test_detail_page(id_test):
    return render_template('test_detail.html', id_test=id_test)


@app.get('/attempts/<int:id_attempt>')
def attempt_page(id_attempt):
    return render_template('attempt.html', id_attempt=id_attempt)


@app.get('/attempts/<int:id_attempt>/result')
def result_page(id_attempt):
    return render_template('result.html', id_attempt=id_attempt)


@app.get('/my-attempts')
def my_attempts_page():
    return render_template('my_attempts.html')


@app.get('/author/tests')
def author_tests_page():
    access = require_author_role()
    if access:
        return access
    tests = fetch_list(
        '''
        SELECT t.id_test, t.test_name, t.test_description, t.is_active,
               t.question_count, t.attempt_limit, t.time_limit, t.show_feedback,
               c.category_name, d.level_name
        FROM test t
        LEFT JOIN category c ON c.id_category = t.id_category
        LEFT JOIN difficulty_level d ON d.id_level = t.id_level
        WHERE t.uid_author = :uid
        ORDER BY t.id_test DESC
        ''',
        {'uid': session['uid']},
    )
    return render_template('author_tests.html', tests=tests)


@app.route('/author/tests/create', methods=['GET', 'POST'])
def create_test_page():
    access = require_author_role()
    if access:
        return access
    if request.method == 'POST':
        form = request.form
        try:
            with get_connection() as conn:
                with conn.cursor() as cur:
                    cur.callproc(
                        'quiz_platform.create_test',
                        [
                            session['uid'],
                            form.get('test_name', '').strip(),
                            form.get('test_description') or None,
                            int(form.get('id_category')) if form.get('id_category') else None,
                            int(form.get('id_level')) if form.get('id_level') else None,
                            int(form.get('time_limit')) if form.get('time_limit') else None,
                            int(form.get('attempt_limit')),
                            int(form.get('show_feedback')),
                            int(form.get('question_count')) if form.get('question_count') else None,
                        ],
                    )
                    cur.execute('SELECT seq_test.CURRVAL FROM dual')
                    new_test_id = cur.fetchone()[0]
                conn.commit()
            flash('Тест создан.', 'success')
            return redirect(url_for('author_test_detail_page', id_test=new_test_id))
        except (TypeError, ValueError):
            flash('Проверьте числовые параметры теста.', 'error')
        except oracledb.DatabaseError as exc:
            flash(f'Ошибка создания теста: {exc.args[0].message}', 'error')

    categories = fetch_list('SELECT id_category, category_name FROM category ORDER BY category_name')
    levels = fetch_list('SELECT id_level, level_name FROM difficulty_level ORDER BY id_level')
    return render_template('create_test.html', categories=categories, levels=levels)


@app.get('/author/tests/<int:id_test>')
def author_test_detail_page(id_test):
    access = require_author_role()
    if access:
        return access
    test = fetch_list(
        '''
        SELECT t.id_test, t.test_name, t.test_description, t.is_active, t.question_count, t.attempt_limit, t.time_limit,
               t.show_feedback, c.category_name, d.level_name
        FROM test t
        LEFT JOIN category c ON c.id_category = t.id_category
        LEFT JOIN difficulty_level d ON d.id_level = t.id_level
        WHERE t.id_test = :id_test AND t.uid_author = :uid
        ''',
        {'id_test': id_test, 'uid': session['uid']},
    )
    if not test:
        flash('Тест не найден.', 'error')
        return redirect(url_for('author_tests_page'))
    q_list = fetch_list(
        '''
        SELECT qt.id_qt, qt.order_num, qt.weight, qt.is_required, qt.time_limit, q.id_question, q.question_text
        FROM question_in_test qt
        JOIN question q ON q.id_question = qt.id_question
        WHERE qt.id_test = :id_test
        ORDER BY qt.order_num
        ''',
        {'id_test': id_test},
    )
    return render_template('author_test_detail.html', test=test[0], questions=q_list)


@app.route('/author/tests/<int:id_test>/questions', methods=['GET', 'POST'])
def author_test_questions_page(id_test):
    access = require_author_role()
    if access:
        return access
    if request.method == 'POST':
        form = request.form
        try:
            with get_connection() as conn:
                with conn.cursor() as cur:
                    cur.callproc(
                        'quiz_platform.include_question_in_test',
                        [
                            id_test,
                            int(form.get('id_question')),
                            float(form.get('weight')) if form.get('weight') else 1,
                            int(form.get('order_num')),
                            int(form.get('is_required')),
                            int(form.get('time_limit')) if form.get('time_limit') else None,
                        ],
                    )
                conn.commit()
            flash('Вопрос добавлен в тест.', 'success')
        except (TypeError, ValueError):
            flash('Проверьте числовые параметры.', 'error')
        except oracledb.DatabaseError as exc:
            flash(f'Ошибка добавления вопроса: {exc.args[0].message}', 'error')
        return redirect(url_for('author_test_questions_page', id_test=id_test))

    selected = fetch_list(
        '''
        SELECT qt.order_num, q.id_question, q.question_text, qt.weight, qt.is_required, qt.time_limit
        FROM question_in_test qt
        JOIN question q ON q.id_question = qt.id_question
        WHERE qt.id_test = :id_test
        ORDER BY qt.order_num
        ''',
        {'id_test': id_test},
    )
    pool = fetch_list(
        '''
        SELECT q.id_question, q.question_text
        FROM question q
        JOIN test t ON t.uid_author = q.uid_author
        WHERE t.id_test = :id_test
          AND q.uid_author = :uid
          AND q.is_active = 1
          AND NOT EXISTS (
              SELECT 1 FROM question_in_test x WHERE x.id_test = :id_test AND x.id_question = q.id_question
          )
        ORDER BY q.id_question DESC
        ''',
        {'id_test': id_test, 'uid': session['uid']},
    )
    return render_template('author_test_questions.html', id_test=id_test, selected=selected, pool=pool)


@app.post('/author/tests/<int:id_test>/generate')
def author_test_generate_page(id_test):
    access = require_author_role()
    if access:
        return access
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.callproc('quiz_platform.generate_test_questions', [id_test])
            conn.commit()
        flash('Тест автоматически сформирован.', 'success')
    except oracledb.DatabaseError as exc:
        flash(f'Ошибка автогенерации: {exc.args[0].message}', 'error')
    return redirect(url_for('author_test_detail_page', id_test=id_test))


@app.post('/author/tests/<int:id_test>/publish')
def author_test_publish_page(id_test):
    access = require_author_role()
    if access:
        return access
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.callproc('quiz_platform.publish_test', [id_test, 1])
            conn.commit()
        flash('Статус публикации теста изменен.', 'success')
    except oracledb.DatabaseError as exc:
        flash(f'Ошибка публикации: {exc.args[0].message}', 'error')
    return redirect(url_for('author_test_detail_page', id_test=id_test))


@app.get('/author/tests/<int:id_test>/access')
def test_access_page(id_test):
    return render_template('test_access.html', id_test=id_test)


@app.get('/author/tests/<int:id_test>/statistics')
def statistics_page(id_test):
    return render_template('statistics.html', id_test=id_test)


if __name__ == '__main__':
    app.run(debug=True)
