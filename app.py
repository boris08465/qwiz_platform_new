import os

import oracledb
from flask import Flask, flash, redirect, render_template, request, session, url_for

from db import get_connection

app = Flask(__name__)
app.secret_key = os.getenv('SECRET_KEY', 'change-me')

ROLE_MAP = {1: 'Пользователь', 2: 'Автор', 3: 'Администратор'}


def get_user_by_uid(user_id):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                '''
                SELECT u.user_id, u.user_name, u.id_role, r.role_name, u.is_active
                FROM users u
                JOIN role r ON r.id_role = u.id_role
                WHERE u.user_id = :user_id
                ''',
                {'user_id': user_id},
            )
            row = cur.fetchone()
    if not row:
        return None
    return {
        'user_id': row[0],
        'user_name': row[1],
        'id_role': row[2],
        'role_name_code': row[3],
        'is_active': row[4],
    }


def require_auth():
    if 'user_id' not in session:
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


def require_admin_role():
    auth = require_auth()
    if auth:
        return auth
    if session.get('role_id') != 3:
        flash('Доступ только для администратора.', 'error')
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
            flash(f'Регистрация успешно завершена. Ваш user_id: {new_uid}. Используйте этот user_id для входа в систему.', 'success')
            return redirect(url_for('login_page'))
        except oracledb.DatabaseError as exc:
            flash(f'Ошибка регистрации: {exc.args[0].message}', 'error')
    return render_template('register.html')


@app.route('/login', methods=['GET', 'POST'])
def login_page():
    if request.method == 'POST':
        uid_raw = request.form.get('user_id', '').strip()
        password = request.form.get('password', '')
        if not uid_raw.isdigit():
            flash('user_id должен быть числом.', 'error')
            return render_template('login.html')
        try:
            user_id = int(uid_raw)
            with get_connection() as conn:
                with conn.cursor() as cur:
                    role_id = int(cur.callfunc('quiz_platform.login_user', int, [user_id, password]))
            user = get_user_by_uid(user_id)
            if not user:
                flash('Пользователь не найден.', 'error')
                return render_template('login.html')
            session['user_id'] = user['user_id']
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
    return render_template('dashboard.html', user_id=session['user_id'], user_name=session['user_name'], role_title=session['role_title'])


@app.get('/profile')
def profile_page():
    auth = require_auth()
    if auth:
        return auth
    user = get_user_by_uid(session['user_id'])
    return render_template('profile.html', user_id=user['user_id'], user_name=user['user_name'], role_title=ROLE_MAP.get(user['id_role'], 'Пользователь'), role_name_code=user['role_name_code'], is_active=user['is_active'])


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
        WHERE q.uid_author = :user_id
        ORDER BY q.id_question DESC
        ''',
        {'user_id': session['user_id']},
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
                        session['user_id'],
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
        WHERE q.id_question = :id_question AND q.uid_author = :user_id
        ''',
        {'id_question': id_question, 'user_id': session['user_id']},
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
                    'UPDATE question SET is_active = 0 WHERE id_question = :id_question AND uid_author = :user_id',
                    {'id_question': id_question, 'user_id': session['user_id']},
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
    question = fetch_list('SELECT id_question, question_text FROM question WHERE id_question = :id_question AND uid_author = :user_id', {'id_question': id_question, 'user_id': session['user_id']})
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
    auth = require_auth()
    if auth:
        return auth
    tests = fetch_list(
        '''
        SELECT t.id_test, t.test_name, t.test_description, c.category_name, d.level_name,
               t.time_limit, t.attempt_limit, t.question_count, t.show_feedback,
               NVL((
                   SELECT MAX(a.attempt_number)
                   FROM attempt a
                   WHERE a.user_id = :user_id AND a.id_test = t.id_test
               ), 0) AS used_attempts
        FROM test_access ta
        JOIN test t ON t.id_test = ta.id_test
        LEFT JOIN category c ON c.id_category = t.id_category
        LEFT JOIN difficulty_level d ON d.id_level = t.id_level
        WHERE ta.user_id = :user_id
          AND ta.is_active = 1
          AND t.is_active = 1
        ORDER BY t.id_test DESC
        ''',
        {'user_id': session['user_id']},
    )
    return render_template('tests.html', tests=tests)


@app.get('/tests/<int:id_test>')
def test_detail_page(id_test):
    auth = require_auth()
    if auth:
        return auth
    with get_connection() as conn:
        with conn.cursor() as cur:
            has_access = int(cur.callfunc('quiz_platform.check_access', int, [id_test, session['user_id']]))
    if has_access != 1:
        flash('Нет доступа к тесту.', 'error')
        return redirect(url_for('tests_page'))

    test = fetch_list(
        '''
        SELECT t.id_test, t.test_name, t.test_description, c.category_name, d.level_name,
               t.time_limit, t.attempt_limit, t.question_count, t.show_feedback,
               NVL((
                   SELECT MAX(a.attempt_number)
                   FROM attempt a
                   WHERE a.user_id = :user_id AND a.id_test = t.id_test
               ), 0) AS used_attempts
        FROM test t
        LEFT JOIN category c ON c.id_category = t.id_category
        LEFT JOIN difficulty_level d ON d.id_level = t.id_level
        WHERE t.id_test = :id_test AND t.is_active = 1
        ''',
        {'id_test': id_test, 'user_id': session['user_id']},
    )
    if not test:
        flash('Тест не найден.', 'error')
        return redirect(url_for('tests_page'))
    return render_template('test_detail.html', test=test[0])


@app.get('/attempts/<int:id_attempt>')
def attempt_page(id_attempt):
    auth = require_auth()
    if auth:
        return auth
    attempt_rows = fetch_list(
        '''
        SELECT a.id_attempt, a.status, a.start_date, a.end_date, t.id_test, t.test_name,
               t.time_limit,
               FLOOR((SYSDATE - a.start_date) * 86400) AS elapsed_seconds,
               CASE
                   WHEN t.time_limit IS NULL THEN NULL
                   ELSE GREATEST(0, t.time_limit - FLOOR((SYSDATE - a.start_date) * 86400))
               END AS remaining_seconds
        FROM attempt a
        JOIN test t ON t.id_test = a.id_test
        WHERE a.id_attempt = :id_attempt AND a.user_id = :user_id
        ''',
        {'id_attempt': id_attempt, 'user_id': session['user_id']},
    )
    if not attempt_rows:
        flash('Попытка не найдена.', 'error')
        return redirect(url_for('my_attempts_page'))
    attempt = attempt_rows[0]

    if attempt[1] == 'STARTED' and attempt[6] is not None and attempt[8] <= 0:
        try:
            with get_connection() as conn:
                with conn.cursor() as cur:
                    cur.callproc('quiz_platform.finish_attempt', [id_attempt])
                conn.commit()
            flash('Время теста истекло. Попытка завершена автоматически.', 'error')
            return redirect(url_for('result_page', id_attempt=id_attempt))
        except oracledb.DatabaseError as exc:
            flash(f'Ошибка завершения попытки: {exc.args[0].message}', 'error')

    questions = fetch_list(
        '''
        SELECT qt.id_qt, qt.order_num, qt.weight, qt.time_limit,
               q.id_question, q.question_text, q.type_id, q.explanation
        FROM question_in_test qt
        JOIN question q ON q.id_question = qt.id_question
        JOIN attempt a ON a.id_test = qt.id_test
        WHERE a.id_attempt = :id_attempt
        ORDER BY qt.order_num
        ''',
        {'id_attempt': id_attempt},
    )

    answer_map = {}
    for ans in fetch_list(
        '''
        SELECT id_answer, id_qt, answer_text, answer_number, is_correct, earned_score, answer_time
        FROM answer
        WHERE id_attempt = :id_attempt
        ''',
        {'id_attempt': id_attempt},
    ):
        answer_map[ans[1]] = {
            'id_answer': ans[0],
            'answer_text': ans[2],
            'answer_number': ans[3],
            'is_correct': ans[4],
            'earned_score': ans[5],
            'answer_time': ans[6],
            'selected_options': [],
        }

    selected_rows = fetch_list(
        '''
        SELECT aso.id_answer, aso.id_option, ao.option_text
        FROM answer_selected_option aso
        JOIN answer a ON a.id_answer = aso.id_answer
        JOIN answer_option ao ON ao.id_option = aso.id_option
        WHERE a.id_attempt = :id_attempt
        ORDER BY ao.id_option
        ''',
        {'id_attempt': id_attempt},
    )
    by_answer_id = {}
    for r in selected_rows:
        by_answer_id.setdefault(r[0], []).append({'id_option': r[1], 'option_text': r[2]})

    option_map = {}
    for row in fetch_list(
        '''
        SELECT ao.id_option, ao.id_question, ao.option_text
        FROM answer_option ao
        JOIN question q ON q.id_question = ao.id_question
        JOIN question_in_test qt ON qt.id_question = q.id_question
        JOIN attempt a ON a.id_test = qt.id_test
        WHERE a.id_attempt = :id_attempt
        ORDER BY ao.id_option
        ''',
        {'id_attempt': id_attempt},
    ):
        option_map.setdefault(row[1], []).append({'id_option': row[0], 'option_text': row[2]})

    for info in answer_map.values():
        info['selected_options'] = by_answer_id.get(info['id_answer'], [])
        info['selected_option_ids'] = [opt['id_option'] for opt in info['selected_options']]

    answered_count = len(answer_map)
    total_questions = len(questions)
    current_question = None
    if attempt[1] == 'STARTED':
        for question in questions:
            if question[0] not in answer_map:
                current_question = question
                break

    return render_template(
        'attempt.html',
        attempt=attempt,
        questions=questions,
        current_question=current_question,
        answered_count=answered_count,
        total_questions=total_questions,
        option_map=option_map,
        answer_map=answer_map,
    )


@app.get('/tests/<int:id_test>/start')
def start_test_page(id_test):
    auth = require_auth()
    if auth:
        return auth
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.callproc('quiz_platform.start_attempt', [id_test, session['user_id']])
                cur.execute('SELECT seq_attempt.CURRVAL FROM dual')
                new_attempt_id = cur.fetchone()[0]
            conn.commit()
        return redirect(url_for('attempt_page', id_attempt=new_attempt_id))
    except oracledb.DatabaseError as exc:
        flash(f'Ошибка запуска попытки: {exc.args[0].message}', 'error')
        return redirect(url_for('test_detail_page', id_test=id_test))


@app.post('/attempts/<int:id_attempt>/answer')
def save_attempt_answer_page(id_attempt):
    auth = require_auth()
    if auth:
        return auth
    id_qt_raw = request.form.get('id_qt', '').strip()
    if not id_qt_raw.isdigit():
        flash('Неверный вопрос попытки.', 'error')
        return redirect(url_for('attempt_page', id_attempt=id_attempt))
    id_qt = int(id_qt_raw)
    try:
        answer_time = max(0, int(request.form.get('answer_time', '0') or 0))
    except ValueError:
        answer_time = 0
    answer_text = request.form.get('answer_text') or None
    answer_number_raw = request.form.get('answer_number', '').strip()
    answer_number = float(answer_number_raw) if answer_number_raw else None
    selected_option_ids = [int(x) for x in request.form.getlist('selected_option_ids') if str(x).isdigit()]

    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.callproc('quiz_platform.save_answer', [id_attempt, id_qt, answer_text, answer_number, answer_time])
                cur.execute('SELECT seq_answer.CURRVAL FROM dual')
                new_answer_id = cur.fetchone()[0]
                for opt_id in selected_option_ids:
                    cur.callproc('quiz_platform.save_selected_option', [new_answer_id, opt_id])
            conn.commit()
        flash('Ответ сохранен.', 'success')
    except oracledb.DatabaseError as exc:
        flash(f'Ошибка сохранения ответа: {exc.args[0].message}', 'error')
    return redirect(url_for('attempt_page', id_attempt=id_attempt))


@app.route('/attempts/<int:id_attempt>/finish', methods=['POST', 'GET'])
def finish_attempt_page(id_attempt):
    auth = require_auth()
    if auth:
        return auth
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.callproc('quiz_platform.finish_attempt', [id_attempt])
            conn.commit()
        return redirect(url_for('result_page', id_attempt=id_attempt))
    except oracledb.DatabaseError as exc:
        flash(f'Ошибка завершения попытки: {exc.args[0].message}', 'error')
        return redirect(url_for('attempt_page', id_attempt=id_attempt))


@app.get('/attempts/<int:id_attempt>/result')
def result_page(id_attempt):
    auth = require_auth()
    if auth:
        return auth
    rows = fetch_list(
        '''
        SELECT a.id_attempt, a.attempt_number, a.start_date, a.end_date, a.status, a.score, a.percent_result,
               t.id_test, t.test_name, t.show_feedback,
               NVL((
                   SELECT AVG(x.percent_result)
                   FROM attempt x
                   WHERE x.id_test = a.id_test
                     AND x.status IN ('FINISHED', 'TIME_EXPIRED')
                     AND x.percent_result IS NOT NULL
               ), 0) AS avg_percent
        FROM attempt a
        JOIN test t ON t.id_test = a.id_test
        WHERE a.id_attempt = :id_attempt AND a.user_id = :user_id
        ''',
        {'id_attempt': id_attempt, 'user_id': session['user_id']},
    )
    if not rows:
        flash('Результат не найден.', 'error')
        return redirect(url_for('my_attempts_page'))
    result = rows[0]

    answers = []
    if result[9] == 1:
        answer_rows = fetch_list(
            '''
            SELECT qt.order_num, q.question_text, q.type_id, a.id_answer, a.answer_text, a.answer_number,
                   a.is_correct, a.earned_score, q.correct_text, q.correct_number, q.explanation
            FROM question_in_test qt
            JOIN question q ON q.id_question = qt.id_question
            JOIN attempt at ON at.id_test = qt.id_test
            LEFT JOIN answer a ON a.id_qt = qt.id_qt AND a.id_attempt = at.id_attempt
            WHERE at.id_attempt = :id_attempt
            ORDER BY qt.order_num
            ''',
            {'id_attempt': id_attempt},
        )

        selected_options = {}
        for row in fetch_list(
            '''
            SELECT aso.id_answer, ao.option_text
            FROM answer_selected_option aso
            JOIN answer_option ao ON ao.id_option = aso.id_option
            JOIN answer a ON a.id_answer = aso.id_answer
            WHERE a.id_attempt = :id_attempt
            ORDER BY ao.id_option
            ''',
            {'id_attempt': id_attempt},
        ):
            selected_options.setdefault(row[0], []).append(row[1])

        correct_options = {}
        for row in fetch_list(
            '''
            SELECT qt.order_num, ao.option_text
            FROM question_in_test qt
            JOIN attempt at ON at.id_test = qt.id_test
            JOIN answer_option ao ON ao.id_question = qt.id_question
            WHERE at.id_attempt = :id_attempt
              AND ao.is_correct = 1
            ORDER BY qt.order_num, ao.id_option
            ''',
            {'id_attempt': id_attempt},
        ):
            correct_options.setdefault(row[0], []).append(row[1])

        for row in answer_rows:
            order_num = row[0]
            type_id = row[2]
            id_answer = row[3]
            chosen_options = selected_options.get(id_answer, []) if id_answer is not None else []
            valid_options = correct_options.get(order_num, [])

            if type_id in (1, 2, 5):
                user_answer = ', '.join(chosen_options) if chosen_options else '-'
                correct_answer = ', '.join(valid_options) if valid_options else '-'
            elif type_id == 4:
                user_answer = row[5] if row[5] is not None else '-'
                correct_answer = row[9] if row[9] is not None else '-'
            else:
                user_answer = row[4] if row[4] else '-'
                correct_answer = row[8] if row[8] else '-'

            answers.append({
                'order_num': order_num,
                'question_text': row[1],
                'user_answer': user_answer,
                'is_correct': row[6],
                'earned_score': row[7],
                'correct_answer': correct_answer,
                'explanation': row[10],
            })

    return render_template('result.html', result=result, answers=answers)


@app.get('/my-attempts')
def my_attempts_page():
    auth = require_auth()
    if auth:
        return auth
    attempts = fetch_list(
        '''
        SELECT a.id_attempt, t.test_name, a.attempt_number, a.status, a.score, a.percent_result, a.start_date, a.end_date
        FROM attempt a
        JOIN test t ON t.id_test = a.id_test
        WHERE a.user_id = :user_id
        ORDER BY a.id_attempt DESC
        ''',
        {'user_id': session['user_id']},
    )
    return render_template('my_attempts.html', attempts=attempts)


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
        WHERE t.uid_author = :user_id
        ORDER BY t.id_test DESC
        ''',
        {'user_id': session['user_id']},
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
                            session['user_id'],
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
        WHERE t.id_test = :id_test AND t.uid_author = :user_id
        ''',
        {'id_test': id_test, 'user_id': session['user_id']},
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
          AND q.uid_author = :user_id
          AND q.is_active = 1
          AND NOT EXISTS (
              SELECT 1 FROM question_in_test x WHERE x.id_test = :id_test AND x.id_question = q.id_question
          )
        ORDER BY q.id_question DESC
        ''',
        {'id_test': id_test, 'user_id': session['user_id']},
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
    access = require_author_role()
    if access:
        return access
    owner_test = fetch_list('SELECT id_test, test_name FROM test WHERE id_test = :id_test AND uid_author = :user_id', {'id_test': id_test, 'user_id': session['user_id']})
    if not owner_test:
        flash('Тест не найден.', 'error')
        return redirect(url_for('author_tests_page'))
    granted = fetch_list(
        '''
        SELECT ta.user_id, u.user_name, ta.is_active, ta.granted_at
        FROM test_access ta
        JOIN users u ON u.user_id = ta.user_id
        WHERE ta.id_test = :id_test
        ORDER BY ta.granted_at DESC
        ''',
        {'id_test': id_test},
    )
    return render_template('test_access.html', id_test=id_test, test_name=owner_test[0][1], granted=granted)


@app.post('/author/tests/<int:id_test>/access')
def test_access_grant_page(id_test):
    access = require_author_role()
    if access:
        return access
    uid_raw = request.form.get('user_id', '').strip()
    if not uid_raw.isdigit():
        flash('user_id должен быть числом.', 'error')
        return redirect(url_for('test_access_page', id_test=id_test))
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.callproc('quiz_platform.grant_test_access', [id_test, int(uid_raw)])
            conn.commit()
        flash('Доступ выдан.', 'success')
    except oracledb.DatabaseError as exc:
        flash(f'Ошибка выдачи доступа: {exc.args[0].message}', 'error')
    return redirect(url_for('test_access_page', id_test=id_test))


@app.post('/author/tests/<int:id_test>/access/<int:user_id>/deactivate')
def test_access_deactivate_page(id_test, user_id):
    access = require_author_role()
    if access:
        return access
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    '''
                    UPDATE test_access ta
                    SET ta.is_active = 0
                    WHERE ta.id_test = :id_test
                      AND ta.user_id = :user_id
                      AND EXISTS (
                        SELECT 1 FROM test t
                        WHERE t.id_test = ta.id_test AND t.uid_author = :author_uid
                      )
                    ''',
                    {'id_test': id_test, 'user_id': user_id, 'author_uid': session['user_id']},
                )
            conn.commit()
        flash('Доступ деактивирован.', 'success')
    except oracledb.DatabaseError as exc:
        flash(f'Ошибка деактивации доступа: {exc.args[0].message}', 'error')
    return redirect(url_for('test_access_page', id_test=id_test))


@app.get('/author/tests/<int:id_test>/statistics')
def statistics_page(id_test):
    access = require_author_role()
    if access:
        return access
    owner = fetch_list('SELECT id_test, test_name FROM test WHERE id_test = :id_test AND uid_author = :user_id', {'id_test': id_test, 'user_id': session['user_id']})
    if not owner:
        flash('Тест не найден.', 'error')
        return redirect(url_for('author_tests_page'))

    summary = fetch_list(
        '''
        SELECT
            COUNT(*) AS total_attempts,
            SUM(CASE WHEN status IN ('FINISHED', 'TIME_EXPIRED') THEN 1 ELSE 0 END) AS finished_attempts,
            ROUND(AVG(score), 2) AS avg_score,
            ROUND(AVG(percent_result), 2) AS avg_percent,
            MIN(percent_result) AS min_percent,
            MAX(percent_result) AS max_percent
        FROM attempt
        WHERE id_test = :id_test
        ''',
        {'id_test': id_test},
    )[0]

    per_question = fetch_list(
        '''
        SELECT
            qt.order_num,
            q.question_text,
            COUNT(a.id_answer) AS total_answers,
            SUM(CASE WHEN a.is_correct = 1 THEN 1 ELSE 0 END) AS correct_answers,
            ROUND(
                CASE WHEN COUNT(a.id_answer) = 0 THEN 0
                     ELSE SUM(CASE WHEN a.is_correct = 1 THEN 1 ELSE 0 END) / COUNT(a.id_answer) * 100
                END, 2
            ) AS percent_correct,
            ROUND(AVG(a.answer_time), 2) AS avg_answer_time,
            ROUND(AVG(a.earned_score), 2) AS avg_earned_score
        FROM question_in_test qt
        JOIN question q ON q.id_question = qt.id_question
        LEFT JOIN answer a ON a.id_qt = qt.id_qt
        WHERE qt.id_test = :id_test
        GROUP BY qt.order_num, q.question_text
        ORDER BY qt.order_num
        ''',
        {'id_test': id_test},
    )
    return render_template('statistics.html', id_test=id_test, test_name=owner[0][1], summary=summary, per_question=per_question)


@app.get('/admin/users')
def admin_users_page():
    access = require_admin_role()
    if access:
        return access
    users = fetch_list(
        '''
        SELECT u.user_id, u.user_name, r.role_name, u.is_active, u.created_at
        FROM users u
        JOIN role r ON r.id_role = u.id_role
        ORDER BY u.user_id DESC
        '''
    )
    return render_template('admin_users.html', users=users)


@app.get('/admin/tests')
def admin_tests_page():
    access = require_admin_role()
    if access:
        return access
    tests = fetch_list(
        '''
        SELECT t.id_test, t.test_name, u.user_name, t.is_active, t.created_at, t.attempt_limit, t.question_count
        FROM test t
        JOIN users u ON u.user_id = t.uid_author
        ORDER BY t.id_test DESC
        '''
    )
    return render_template('admin_tests.html', tests=tests)


@app.get('/admin/questions')
def admin_questions_page():
    access = require_admin_role()
    if access:
        return access
    questions = fetch_list(
        '''
        SELECT q.id_question, q.question_text, u.user_name, qt.type_name, q.is_active, q.created_at
        FROM question q
        JOIN users u ON u.user_id = q.uid_author
        JOIN question_type qt ON qt.type_id = q.type_id
        ORDER BY q.id_question DESC
        '''
    )
    return render_template('admin_questions.html', questions=questions)


@app.get('/admin/categories')
def admin_categories_page():
    access = require_admin_role()
    if access:
        return access
    categories = fetch_list('SELECT id_category, category_name, category_description FROM category ORDER BY category_name')
    return render_template('admin_categories.html', categories=categories)


@app.get('/admin/statistics')
def admin_statistics_page():
    access = require_admin_role()
    if access:
        return access
    overview = {
        'users_total': fetch_list('SELECT COUNT(*) FROM users')[0][0],
        'users_active': fetch_list('SELECT COUNT(*) FROM users WHERE is_active = 1')[0][0],
        'tests_total': fetch_list('SELECT COUNT(*) FROM test')[0][0],
        'tests_published': fetch_list('SELECT COUNT(*) FROM test WHERE is_active = 1')[0][0],
        'questions_total': fetch_list('SELECT COUNT(*) FROM question')[0][0],
        'attempts_total': fetch_list('SELECT COUNT(*) FROM attempt')[0][0],
    }
    return render_template('admin_statistics.html', overview=overview)


if __name__ == '__main__':
    app.run(debug=True)
