import os
from pathlib import Path
from uuid import uuid4

import oracledb
from flask import Flask, flash, redirect, render_template, request, session, url_for
from werkzeug.utils import secure_filename

from db import get_connection

app = Flask(__name__)
app.secret_key = os.getenv('SECRET_KEY', 'change-me')
app.config['MAX_CONTENT_LENGTH'] = 5 * 1024 * 1024

QUESTION_UPLOAD_DIR = Path(app.root_path) / 'static' / 'uploads' / 'questions'
QUESTION_UPLOAD_PREFIX = 'uploads/questions'
ALLOWED_IMAGE_EXTENSIONS = {'jpg', 'jpeg', 'png', 'gif', 'webp'}

ROLE_TITLE_FALLBACK = {
    'USER': 'Обычный пользователь',
    'AUTHOR': 'Автор тестов',
    'ADMIN': 'Администратор',
}


def save_question_image(file_storage, question_id):
    if not file_storage or not file_storage.filename:
        return None

    original_name = secure_filename(file_storage.filename)
    extension = original_name.rsplit('.', 1)[-1].lower() if '.' in original_name else ''
    if extension not in ALLOWED_IMAGE_EXTENSIONS:
        raise ValueError('Можно загрузить только изображение jpg, jpeg, png, gif или webp.')

    QUESTION_UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    filename = f'question_{question_id}_{uuid4().hex}.{extension}'
    file_storage.save(QUESTION_UPLOAD_DIR / filename)
    return f'{QUESTION_UPLOAD_PREFIX}/{filename}'


def get_user_by_uid(user_id):
    rows = fetch_cursor('quiz_platform.get_user', [user_id])
    row = rows[0] if rows else None
    if not row:
        return None
    return {
        'user_id': row[0],
        'user_name': row[1],
        'id_role': row[2],
        'role_name_code': row[3],
        'role_title': row[4] or ROLE_TITLE_FALLBACK.get(row[3], 'Пользователь'),
        'is_active': row[5],
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
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                has_access = int(cur.callfunc('quiz_platform.check_author_role', int, [session['user_id']]))
    except oracledb.DatabaseError as exc:
        flash(f'Ошибка проверки доступа: {exc.args[0].message}', 'error')
        return redirect(url_for('dashboard_page'))
    if has_access != 1:
        flash('Доступ только для автора или администратора.', 'error')
        return redirect(url_for('dashboard_page'))
    return None


def require_admin_role():
    auth = require_auth()
    if auth:
        return auth
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                has_access = int(cur.callfunc('quiz_platform.check_admin_role', int, [session['user_id']]))
    except oracledb.DatabaseError as exc:
        flash(f'Ошибка проверки доступа: {exc.args[0].message}', 'error')
        return redirect(url_for('dashboard_page'))
    if has_access != 1:
        flash('Доступ только для администратора.', 'error')
        return redirect(url_for('dashboard_page'))
    return None


def fetch_cursor(function_name, params=None):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cursor = cur.callfunc(function_name, oracledb.DB_TYPE_CURSOR, params or [])
            try:
                return cursor.fetchall()
            finally:
                cursor.close()


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
                    new_uid = int(cur.callfunc('quiz_platform.register_user_id', int, [user_name, password]))
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
                    cur.callfunc('quiz_platform.login_user', int, [user_id, password])
            user = get_user_by_uid(user_id)
            if not user:
                flash('Пользователь не найден.', 'error')
                return render_template('login.html')
            session['user_id'] = user['user_id']
            session['user_name'] = user['user_name']
            session['role_code'] = user['role_name_code']
            session['role_title'] = user['role_title']
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
    return render_template('profile.html', user_id=user['user_id'], user_name=user['user_name'], role_title=user['role_title'], role_name_code=user['role_name_code'], is_active=user['is_active'])


@app.get('/author/categories')
def author_categories_page():
    access = require_author_role()
    if access:
        return access
    categories = fetch_cursor('quiz_platform.list_categories')
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
                cur.callproc('quiz_platform.add_category', [name, description])
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
    levels = fetch_cursor('quiz_platform.list_difficulty_levels')
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
                cur.callproc('quiz_platform.add_difficulty_level', [level_name])
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
    types = fetch_cursor('quiz_platform.list_question_types')
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
    questions = fetch_cursor('quiz_platform.list_author_questions', [session['user_id']])
    return render_template('author_questions.html', questions=questions)


@app.get('/author/questions/create')
def create_question_page():
    access = require_author_role()
    if access:
        return access
    categories = fetch_cursor('quiz_platform.list_categories')
    levels = fetch_cursor('quiz_platform.list_difficulty_levels')
    types = fetch_cursor('quiz_platform.list_question_types')
    return render_template('create_question.html', categories=categories, levels=levels, types=types)


@app.post('/author/questions/create')
def create_question_submit():
    access = require_author_role()
    if access:
        return access

    form = request.form
    image_file = request.files.get('question_image')
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                new_question_id = int(cur.callfunc(
                    'quiz_platform.add_question_id',
                    int,
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
                ))
                image_path = save_question_image(image_file, new_question_id)
                if image_path:
                    cur.execute(
                        """
                        UPDATE question
                        SET image_path = :image_path
                        WHERE id_question = :id_question
                          AND uid_author = :uid_author
                        """,
                        image_path=image_path,
                        id_question=new_question_id,
                        uid_author=session['user_id'],
                    )
            conn.commit()
        flash('Вопрос создан.', 'success')
        return redirect(url_for('author_question_detail_page', id_question=new_question_id))
    except ValueError as exc:
        message = str(exc)
        if message.startswith('Можно загрузить'):
            flash(message, 'error')
        else:
            flash('Некорректные числовые параметры.', 'error')
    except TypeError:
        flash('Некорректные числовые параметры.', 'error')
    except oracledb.DatabaseError as exc:
        flash(f'Ошибка создания вопроса: {exc.args[0].message}', 'error')
    return redirect(url_for('create_question_page'))


@app.get('/author/questions/<int:id_question>')
def author_question_detail_page(id_question):
    access = require_author_role()
    if access:
        return access
    rows = fetch_cursor('quiz_platform.get_author_question', [id_question, session['user_id']])
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
                cur.callproc('quiz_platform.deactivate_question', [id_question, session['user_id']])
            conn.commit()
        flash('Вопрос деактивирован.', 'success')
    except oracledb.DatabaseError as exc:
        flash(f'Ошибка деактивации: {exc.args[0].message}', 'error')
    return redirect(url_for('author_question_detail_page', id_question=id_question))


@app.get('/author/questions/<int:id_question>/options')
def author_question_options_page(id_question):
    access = require_author_role()
    if access:
        return access
    question = fetch_cursor('quiz_platform.get_author_question', [id_question, session['user_id']])
    if not question:
        flash('Вопрос не найден.', 'error')
        return redirect(url_for('author_questions_page'))
    options = fetch_cursor('quiz_platform.list_answer_options', [id_question, session['user_id']])
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
    tests = fetch_cursor('quiz_platform.list_available_tests', [session['user_id']])
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

    test = fetch_cursor('quiz_platform.get_available_test', [id_test, session['user_id']])
    if not test:
        flash('Тест не найден.', 'error')
        return redirect(url_for('tests_page'))
    return render_template('test_detail.html', test=test[0])


@app.get('/attempts/<int:id_attempt>')
def attempt_page(id_attempt):
    auth = require_auth()
    if auth:
        return auth
    attempt_rows = fetch_cursor('quiz_platform.get_attempt', [id_attempt, session['user_id']])
    if not attempt_rows:
        flash('Попытка не найдена.', 'error')
        return redirect(url_for('my_attempts_page'))
    attempt = attempt_rows[0]

    if attempt[1] == 'STARTED' and attempt[6] is not None and attempt[8] <= 0:
        try:
            with get_connection() as conn:
                with conn.cursor() as cur:
                    cur.callproc('quiz_platform.finish_attempt', [id_attempt, session['user_id']])
                conn.commit()
            flash('Время теста истекло. Попытка завершена автоматически.', 'error')
            return redirect(url_for('result_page', id_attempt=id_attempt))
        except oracledb.DatabaseError as exc:
            flash(f'Ошибка завершения попытки: {exc.args[0].message}', 'error')

    questions = fetch_cursor('quiz_platform.list_attempt_questions', [id_attempt])

    answer_map = {}
    for ans in fetch_cursor('quiz_platform.list_attempt_answers', [id_attempt]):
        answer_map[ans[1]] = {
            'id_answer': ans[0],
            'answer_text': ans[2],
            'answer_number': ans[3],
            'is_correct': ans[4],
            'earned_score': ans[5],
            'answer_time': ans[6],
            'selected_options': [],
        }

    selected_rows = fetch_cursor('quiz_platform.list_attempt_selected_options', [id_attempt])
    by_answer_id = {}
    for r in selected_rows:
        by_answer_id.setdefault(r[0], []).append({'id_option': r[1], 'option_text': r[2]})

    option_map = {}
    for row in fetch_cursor('quiz_platform.list_attempt_question_options', [id_attempt]):
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
                new_attempt_id = int(cur.callfunc('quiz_platform.start_attempt_id', int, [id_test, session['user_id']]))
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
                new_answer_id = int(cur.callfunc('quiz_platform.save_answer_id', int, [id_attempt, id_qt, answer_text, answer_number, answer_time, session['user_id']]))
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
                cur.callproc('quiz_platform.finish_attempt', [id_attempt, session['user_id']])
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
    rows = fetch_cursor('quiz_platform.get_attempt_result', [id_attempt, session['user_id']])
    if not rows:
        flash('Результат не найден.', 'error')
        return redirect(url_for('my_attempts_page'))
    result = rows[0]

    answers = []
    if result[9] == 1:
        answer_rows = fetch_cursor('quiz_platform.list_result_answers', [id_attempt])

        selected_options = {}
        for row in fetch_cursor('quiz_platform.list_result_selected_options', [id_attempt]):
            selected_options.setdefault(row[0], []).append(row[1])

        correct_options = {}
        for row in fetch_cursor('quiz_platform.list_result_correct_options', [id_attempt]):
            correct_options.setdefault(row[0], []).append(row[1])

        for row in answer_rows:
            order_num = row[0]
            id_answer = row[3]
            chosen_options = selected_options.get(id_answer, []) if id_answer is not None else []
            valid_options = correct_options.get(order_num, [])

            if row[11] == 1:
                user_answer = ', '.join(chosen_options) if chosen_options else '-'
                correct_answer = ', '.join(valid_options) if valid_options else '-'
            elif row[13] == 1:
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
                'image_path': row[15],
            })

    return render_template('result.html', result=result, answers=answers)


@app.get('/my-attempts')
def my_attempts_page():
    auth = require_auth()
    if auth:
        return auth
    attempts = fetch_cursor('quiz_platform.list_user_attempts', [session['user_id']])
    return render_template('my_attempts.html', attempts=attempts)


@app.get('/author/tests')
def author_tests_page():
    access = require_author_role()
    if access:
        return access
    tests = fetch_cursor('quiz_platform.list_author_tests', [session['user_id']])
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
                    new_test_id = int(cur.callfunc(
                        'quiz_platform.create_test_id',
                        int,
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
                    ))
                conn.commit()
            flash('Тест создан.', 'success')
            return redirect(url_for('author_test_detail_page', id_test=new_test_id))
        except (TypeError, ValueError):
            flash('Проверьте числовые параметры теста.', 'error')
        except oracledb.DatabaseError as exc:
            flash(f'Ошибка создания теста: {exc.args[0].message}', 'error')

    categories = fetch_cursor('quiz_platform.list_categories')
    levels = fetch_cursor('quiz_platform.list_difficulty_levels')
    return render_template('create_test.html', categories=categories, levels=levels)


@app.get('/author/tests/<int:id_test>')
def author_test_detail_page(id_test):
    access = require_author_role()
    if access:
        return access
    test = fetch_cursor('quiz_platform.get_author_test', [id_test, session['user_id']])
    if not test:
        flash('Тест не найден.', 'error')
        return redirect(url_for('author_tests_page'))
    q_list = fetch_cursor('quiz_platform.list_test_questions', [id_test])
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
                            session['user_id'],
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

    selected = fetch_cursor('quiz_platform.list_selected_test_questions', [id_test])
    pool = fetch_cursor('quiz_platform.list_question_pool', [id_test, session['user_id']])
    return render_template('author_test_questions.html', id_test=id_test, selected=selected, pool=pool)


@app.post('/author/tests/<int:id_test>/generate')
def author_test_generate_page(id_test):
    access = require_author_role()
    if access:
        return access
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                cur.callproc('quiz_platform.generate_test_questions', [session['user_id'], id_test])
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
                cur.callproc('quiz_platform.publish_test', [session['user_id'], id_test, 1])
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
    owner_test = fetch_cursor('quiz_platform.get_author_test_access_header', [id_test, session['user_id']])
    if not owner_test:
        flash('Тест не найден.', 'error')
        return redirect(url_for('author_tests_page'))
    granted = fetch_cursor('quiz_platform.list_test_access', [id_test])
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
                cur.callproc('quiz_platform.grant_test_access', [session['user_id'], id_test, int(uid_raw)])
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
                cur.callproc('quiz_platform.deactivate_test_access', [id_test, user_id, session['user_id']])
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
    summary_rows = fetch_cursor('quiz_platform.get_test_statistics_summary', [id_test, session['user_id']])
    if not summary_rows:
        flash('Тест не найден.', 'error')
        return redirect(url_for('author_tests_page'))

    summary_with_name = summary_rows[0]
    summary = summary_with_name[1:]
    per_question = fetch_cursor('quiz_platform.list_test_statistics_questions', [id_test, session['user_id']])
    return render_template('statistics.html', id_test=id_test, test_name=summary_with_name[0], summary=summary, per_question=per_question)


@app.get('/admin/users')
def admin_users_page():
    access = require_admin_role()
    if access:
        return access
    users = fetch_cursor('quiz_platform.list_admin_users', [session['user_id']])
    return render_template('admin_users.html', users=users)


@app.get('/admin/tests')
def admin_tests_page():
    access = require_admin_role()
    if access:
        return access
    tests = fetch_cursor('quiz_platform.list_admin_tests', [session['user_id']])
    return render_template('admin_tests.html', tests=tests)


@app.get('/admin/questions')
def admin_questions_page():
    access = require_admin_role()
    if access:
        return access
    questions = fetch_cursor('quiz_platform.list_admin_questions', [session['user_id']])
    return render_template('admin_questions.html', questions=questions)


@app.get('/admin/categories')
def admin_categories_page():
    access = require_admin_role()
    if access:
        return access
    categories = fetch_cursor('quiz_platform.list_categories')
    return render_template('admin_categories.html', categories=categories)


@app.get('/admin/statistics')
def admin_statistics_page():
    access = require_admin_role()
    if access:
        return access
    stats = fetch_cursor('quiz_platform.get_admin_statistics', [session['user_id']])[0]
    overview = {
        'users_total': stats[0],
        'users_active': stats[1],
        'tests_total': stats[2],
        'tests_published': stats[3],
        'questions_total': stats[4],
        'attempts_total': stats[5],
    }
    return render_template('admin_statistics.html', overview=overview)


if __name__ == '__main__':
    app.run(debug=True)
