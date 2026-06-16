
DELETE FROM answer_selected_option;
DELETE FROM answer;
DELETE FROM attempt;
DELETE FROM test_access;
DELETE FROM question_in_test;
DELETE FROM answer_option;
DELETE FROM question;
DELETE FROM test;
DELETE FROM users;
DELETE FROM category;
DELETE FROM attempt_status;
DELETE FROM question_type;
DELETE FROM difficulty_level;
DELETE FROM role;

INSERT INTO role (id_role, role_name, role_description)
VALUES (1, 'USER', 'Обычный пользователь');
INSERT INTO role (id_role, role_name, role_description)
VALUES (2, 'AUTHOR', 'Автор тестов');
INSERT INTO role (id_role, role_name, role_description)
VALUES (3, 'ADMIN', 'Администратор');

INSERT INTO difficulty_level (id_level, level_name)
VALUES (1, 'Легкий');
INSERT INTO difficulty_level (id_level, level_name)
VALUES (2, 'Средний');
INSERT INTO difficulty_level (id_level, level_name)
VALUES (3, 'Сложный');

INSERT INTO question_type (
    type_id, type_code, type_name, uses_options,
    is_multi_select, is_numeric_answer, is_text_answer
) VALUES (
    1, 'SINGLE_CHOICE', 'Один правильный ответ', 1, 0, 0, 0
);
INSERT INTO question_type (
    type_id, type_code, type_name, uses_options,
    is_multi_select, is_numeric_answer, is_text_answer
) VALUES (
    2, 'MULTIPLE_CHOICE', 'Несколько правильных ответов', 1, 1, 0, 0
);
INSERT INTO question_type (
    type_id, type_code, type_name, uses_options,
    is_multi_select, is_numeric_answer, is_text_answer
) VALUES (
    3, 'TEXT', 'Текстовый ответ', 0, 0, 0, 1
);
INSERT INTO question_type (
    type_id, type_code, type_name, uses_options,
    is_multi_select, is_numeric_answer, is_text_answer
) VALUES (
    4, 'NUMBER', 'Числовой ответ', 0, 0, 1, 0
);
INSERT INTO question_type (
    type_id, type_code, type_name, uses_options,
    is_multi_select, is_numeric_answer, is_text_answer
) VALUES (
    5, 'TRUE_FALSE', 'Верно / неверно', 1, 0, 0, 0
);
INSERT INTO question_type (
    type_id, type_code, type_name, uses_options,
    is_multi_select, is_numeric_answer, is_text_answer
) VALUES (
    6, 'SHORT_TEXT', 'Короткий ответ', 0, 0, 0, 1
);

INSERT INTO attempt_status (status_code, status_name, is_terminal, is_successful)
VALUES ('STARTED', 'Начата', 0, 0);
INSERT INTO attempt_status (status_code, status_name, is_terminal, is_successful)
VALUES ('FINISHED', 'Завершена', 1, 1);
INSERT INTO attempt_status (status_code, status_name, is_terminal, is_successful)
VALUES ('TIME_EXPIRED', 'Время истекло', 1, 1);
INSERT INTO attempt_status (status_code, status_name, is_terminal, is_successful)
VALUES ('INTERRUPTED', 'Прервана', 1, 0);

INSERT INTO category (id_category, category_name, category_description)
VALUES (1, 'Тестовая категория', 'Категория для проверки работы приложения');

INSERT INTO users (user_id, id_role, password_hash, user_name, created_at, is_active)
VALUES (1000, 3, STANDARD_HASH('adminpass', 'SHA256'), 'admin1', SYSDATE, 1);
INSERT INTO users (user_id, id_role, password_hash, user_name, created_at, is_active)
VALUES (1001, 2, STANDARD_HASH('authorpass', 'SHA256'), 'author1', SYSDATE, 1);
INSERT INTO users (user_id, id_role, password_hash, user_name, created_at, is_active)
VALUES (1002, 1, STANDARD_HASH('userpass', 'SHA256'), 'user1', SYSDATE, 1);

INSERT INTO test (
    id_test, uid_author, id_category, id_level, test_name, test_description,
    created_at, time_limit, attempt_limit, question_count, show_feedback, is_active
) VALUES (
    1, 1001, 1, 1, 'Простой тест',
    'Минимальный тестовый набор данных', SYSDATE, 600, 3, 3, 1, 1
);

INSERT INTO question (
    id_question, uid_author, id_category, id_level, type_id,
    question_text, explanation, correct_text, correct_number,
    tolerance, created_at, is_active
) VALUES (
    1, 1001, 1, 1, 1,
    'Сколько будет 2 + 2?', 'Правильный ответ: 4.',
    NULL, NULL, NULL, SYSDATE, 1
);
INSERT INTO question (
    id_question, uid_author, id_category, id_level, type_id,
    question_text, explanation, correct_text, correct_number,
    tolerance, created_at, is_active
) VALUES (
    2, 1001, 1, 1, 4,
    'Сколько будет 10 / 2?', 'Правильный ответ: 5.',
    NULL, 5, 0, SYSDATE, 1
);
INSERT INTO question (
    id_question, uid_author, id_category, id_level, type_id,
    question_text, explanation, correct_text, correct_number,
    tolerance, created_at, is_active
) VALUES (
    3, 1001, 1, 1, 3,
    'Напишите слово test.', 'Правильный ответ: test.',
    'test', NULL, NULL, SYSDATE, 1
);

INSERT INTO answer_option (id_option, id_question, option_text, is_correct)
VALUES (1, 1, '4', 1);
INSERT INTO answer_option (id_option, id_question, option_text, is_correct)
VALUES (2, 1, '3', 0);
INSERT INTO answer_option (id_option, id_question, option_text, is_correct)
VALUES (3, 1, '5', 0);

INSERT INTO question_in_test (id_qt, id_test, id_question, weight, order_num, is_required, time_limit)
VALUES (1, 1, 1, 1, 1, 1, NULL);
INSERT INTO question_in_test (id_qt, id_test, id_question, weight, order_num, is_required, time_limit)
VALUES (2, 1, 2, 1, 2, 1, NULL);
INSERT INTO question_in_test (id_qt, id_test, id_question, weight, order_num, is_required, time_limit)
VALUES (3, 1, 3, 1, 3, 1, NULL);

INSERT INTO test_access (id_access, user_id, id_test, granted_at, is_active)
VALUES (1, 1002, 1, SYSDATE, 1);

INSERT INTO attempt (
    id_attempt, user_id, id_test, attempt_number, start_date, end_date,
    status, score, percent_result, finished_in_time
) VALUES (
    1, 1002, 1, 1, SYSDATE - (30 / 1440), SYSDATE,
    'FINISHED', 3, 100, 1
);

INSERT INTO answer (
    id_answer, id_attempt, id_qt, answer_text, answer_number,
    is_correct, earned_score, is_checked, answer_date, answer_time
) VALUES (
    1, 1, 1, NULL, NULL, 1, 1, 1, SYSDATE, 15
);
INSERT INTO answer (
    id_answer, id_attempt, id_qt, answer_text, answer_number,
    is_correct, earned_score, is_checked, answer_date, answer_time
) VALUES (
    2, 1, 2, NULL, 5, 1, 1, 1, SYSDATE, 20
);
INSERT INTO answer (
    id_answer, id_attempt, id_qt, answer_text, answer_number,
    is_correct, earned_score, is_checked, answer_date, answer_time
) VALUES (
    3, 1, 3, 'test', NULL, 1, 1, 1, SYSDATE, 12
);

INSERT INTO answer_selected_option (id_selected, id_answer, id_option)
VALUES (1, 1, 1);

COMMIT;

BEGIN
    FOR seq_name IN (
        SELECT 'seq_answer_selected_option' name FROM dual UNION ALL
        SELECT 'seq_answer' FROM dual UNION ALL
        SELECT 'seq_attempt' FROM dual UNION ALL
        SELECT 'seq_test_access' FROM dual UNION ALL
        SELECT 'seq_question_in_test' FROM dual UNION ALL
        SELECT 'seq_answer_option' FROM dual UNION ALL
        SELECT 'seq_question' FROM dual UNION ALL
        SELECT 'seq_test' FROM dual UNION ALL
        SELECT 'seq_question_type' FROM dual UNION ALL
        SELECT 'seq_difficulty_level' FROM dual UNION ALL
        SELECT 'seq_category' FROM dual UNION ALL
        SELECT 'seq_users' FROM dual UNION ALL
        SELECT 'seq_role' FROM dual
    ) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP SEQUENCE ' || seq_name.name;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;
    END LOOP;
END;


CREATE SEQUENCE seq_role START WITH 4 INCREMENT BY 1;
CREATE SEQUENCE seq_users START WITH 1003 INCREMENT BY 1;
CREATE SEQUENCE seq_category START WITH 2 INCREMENT BY 1;
CREATE SEQUENCE seq_difficulty_level START WITH 4 INCREMENT BY 1;
CREATE SEQUENCE seq_question_type START WITH 7 INCREMENT BY 1;
CREATE SEQUENCE seq_test START WITH 2 INCREMENT BY 1;
CREATE SEQUENCE seq_question START WITH 4 INCREMENT BY 1;
CREATE SEQUENCE seq_answer_option START WITH 4 INCREMENT BY 1;
CREATE SEQUENCE seq_question_in_test START WITH 4 INCREMENT BY 1;
CREATE SEQUENCE seq_test_access START WITH 2 INCREMENT BY 1;
CREATE SEQUENCE seq_attempt START WITH 2 INCREMENT BY 1;
CREATE SEQUENCE seq_answer START WITH 4 INCREMENT BY 1;
CREATE SEQUENCE seq_answer_selected_option START WITH 2 INCREMENT BY 1;

BEGIN
    DBMS_OUTPUT.PUT_LINE('Test data loaded.');
    DBMS_OUTPUT.PUT_LINE('admin1 user_id=1000 password=adminpass');
    DBMS_OUTPUT.PUT_LINE('author1 user_id=1001 password=authorpass');
    DBMS_OUTPUT.PUT_LINE('user1 user_id=1002 password=userpass');
    DBMS_OUTPUT.PUT_LINE('test_id=1');
END;

