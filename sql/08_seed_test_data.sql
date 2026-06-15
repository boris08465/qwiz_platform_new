SET DEFINE OFF
SET SERVEROUTPUT ON

DECLARE
    v_admin_id users.user_id%TYPE;
    v_author_id users.user_id%TYPE;
    v_student_id users.user_id%TYPE;
    v_category_id category.id_category%TYPE;
    v_test_id test.id_test%TYPE;
    v_q_single_id question.id_question%TYPE;
    v_q_multi_id question.id_question%TYPE;
    v_q_text_id question.id_question%TYPE;
    v_q_number_id question.id_question%TYPE;
    v_q_true_false_id question.id_question%TYPE;
    v_q_short_id question.id_question%TYPE;

    PROCEDURE upsert_user(
        p_user_name IN users.user_name%TYPE,
        p_password IN VARCHAR2,
        p_role_name IN role.role_name%TYPE,
        p_user_id OUT users.user_id%TYPE
    ) IS
        v_role_id role.id_role%TYPE;
    BEGIN
        SELECT id_role
        INTO v_role_id
        FROM role
        WHERE role_name = p_role_name;

        BEGIN
            SELECT MIN(user_id)
            INTO p_user_id
            FROM users
            WHERE user_name = p_user_name;

            IF p_user_id IS NULL THEN
                RAISE NO_DATA_FOUND;
            END IF;

            UPDATE users
            SET id_role = v_role_id,
                password_hash = STANDARD_HASH(p_password, 'SHA256'),
                is_active = 1
            WHERE user_id = p_user_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                INSERT INTO users (id_role, password_hash, user_name, created_at, is_active)
                VALUES (v_role_id, STANDARD_HASH(p_password, 'SHA256'), p_user_name, SYSDATE, 1)
                RETURNING user_id INTO p_user_id;
        END;
    END;
BEGIN
    upsert_user('admin1', 'adminpass', 'ADMIN', v_admin_id);
    upsert_user('author1', 'authorpass', 'AUTHOR', v_author_id);
    upsert_user('user1', 'userpass', 'USER', v_student_id);

    BEGIN
        SELECT id_category
        INTO v_category_id
        FROM category
        WHERE category_name = 'Проверка работы';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            INSERT INTO category (category_name, category_description)
            VALUES (
                'Проверка работы',
                'Данные для проверки работы приложения'
            )
            RETURNING id_category INTO v_category_id;
    END;

    v_test_id := quiz_platform.create_test_id(
        v_author_id,
        'Тест работоспособности',
        'Простой тест для проверки приложения',
        v_category_id,
        1,
        600,
        3,
        1,
        6
    );

    v_q_single_id := quiz_platform.add_question_id(
        v_author_id,
        'Сколько будет 2 + 2?',
        v_category_id,
        1,
        1,
        NULL,
        NULL,
        NULL,
        'Правильный ответ: 4.'
    );

    quiz_platform.add_answer_option(v_q_single_id, '4', 1);
    quiz_platform.add_answer_option(v_q_single_id, '3', 0);
    quiz_platform.add_answer_option(v_q_single_id, '5', 0);

    v_q_multi_id := quiz_platform.add_question_id(
        v_author_id,
        'Выбери цвета светофора.',
        v_category_id,
        1,
        2,
        NULL,
        NULL,
        NULL,
        'У светофора есть красный, желтый и зеленый цвета.'
    );

    quiz_platform.add_answer_option(v_q_multi_id, 'Красный', 1);
    quiz_platform.add_answer_option(v_q_multi_id, 'Желтый', 1);
    quiz_platform.add_answer_option(v_q_multi_id, 'Синий', 0);

    v_q_text_id := quiz_platform.add_question_id(
        v_author_id,
        'Напиши слово test.',
        v_category_id,
        1,
        3,
        'test',
        NULL,
        NULL,
        'Нужно ввести слово test.'
    );

    v_q_number_id := quiz_platform.add_question_id(
        v_author_id,
        'Сколько будет 10 / 2?',
        v_category_id,
        1,
        4,
        NULL,
        5,
        0,
        'Правильный числовой ответ: 5.'
    );

    v_q_true_false_id := quiz_platform.add_question_id(
        v_author_id,
        'Земля круглая?',
        v_category_id,
        1,
        5,
        NULL,
        NULL,
        NULL,
        'Для тестовой проверки правильный ответ: верно.'
    );

    quiz_platform.add_answer_option(v_q_true_false_id, 'Верно', 1);
    quiz_platform.add_answer_option(v_q_true_false_id, 'Неверно', 0);

    v_q_short_id := quiz_platform.add_question_id(
        v_author_id,
        'Коротко напиши слово да.',
        v_category_id,
        1,
        6,
        'да',
        NULL,
        NULL,
        'Правильный короткий ответ: да.'
    );

    quiz_platform.include_question_in_test(v_author_id, v_test_id, v_q_single_id, 1, 1, 1, NULL);
    quiz_platform.include_question_in_test(v_author_id, v_test_id, v_q_multi_id, 1, 2, 1, NULL);
    quiz_platform.include_question_in_test(v_author_id, v_test_id, v_q_text_id, 1, 3, 1, NULL);
    quiz_platform.include_question_in_test(v_author_id, v_test_id, v_q_number_id, 1, 4, 1, NULL);
    quiz_platform.include_question_in_test(v_author_id, v_test_id, v_q_true_false_id, 1, 5, 1, NULL);
    quiz_platform.include_question_in_test(v_author_id, v_test_id, v_q_short_id, 1, 6, 1, NULL);

    quiz_platform.publish_test(v_test_id);
    quiz_platform.grant_test_access(v_test_id, v_student_id);

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Admin user_id: ' || v_admin_id || ' password: adminpass');
    DBMS_OUTPUT.PUT_LINE('Author user_id: ' || v_author_id || ' password: authorpass');
    DBMS_OUTPUT.PUT_LINE('Student user_id: ' || v_student_id || ' password: userpass');
    DBMS_OUTPUT.PUT_LINE('Test id: ' || v_test_id);
END;
/
