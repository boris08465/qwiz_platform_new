
-- DBeaver: execute this file as a script (Alt+X).
-- The file is self-contained and does not require SQL*Plus @@ includes.

BEGIN
    FOR obj IN (
        SELECT 'PACKAGE' object_type, 'quiz_platform' object_name FROM dual UNION ALL
        SELECT 'TRIGGER', 'trg_answer_selected_option_bi' FROM dual UNION ALL
        SELECT 'TRIGGER', 'trg_answer_bi' FROM dual UNION ALL
        SELECT 'TRIGGER', 'trg_attempt_bi' FROM dual UNION ALL
        SELECT 'TRIGGER', 'trg_test_access_bi' FROM dual UNION ALL
        SELECT 'TRIGGER', 'trg_question_in_test_bi' FROM dual UNION ALL
        SELECT 'TRIGGER', 'trg_answer_option_bi' FROM dual UNION ALL
        SELECT 'TRIGGER', 'trg_question_bi' FROM dual UNION ALL
        SELECT 'TRIGGER', 'trg_test_bi' FROM dual UNION ALL
        SELECT 'TRIGGER', 'trg_question_type_bi' FROM dual UNION ALL
        SELECT 'TRIGGER', 'trg_difficulty_level_bi' FROM dual UNION ALL
        SELECT 'TRIGGER', 'trg_category_bi' FROM dual UNION ALL
        SELECT 'TRIGGER', 'trg_users_bi' FROM dual UNION ALL
        SELECT 'TRIGGER', 'trg_role_bi' FROM dual UNION ALL
        SELECT 'TABLE', 'answer_selected_option' FROM dual UNION ALL
        SELECT 'TABLE', 'answer' FROM dual UNION ALL
        SELECT 'TABLE', 'attempt' FROM dual UNION ALL
        SELECT 'TABLE', 'attempt_status' FROM dual UNION ALL
        SELECT 'TABLE', 'test_access' FROM dual UNION ALL
        SELECT 'TABLE', 'question_in_test' FROM dual UNION ALL
        SELECT 'TABLE', 'answer_option' FROM dual UNION ALL
        SELECT 'TABLE', 'question' FROM dual UNION ALL
        SELECT 'TABLE', 'test' FROM dual UNION ALL
        SELECT 'TABLE', 'question_type' FROM dual UNION ALL
        SELECT 'TABLE', 'difficulty_level' FROM dual UNION ALL
        SELECT 'TABLE', 'category' FROM dual UNION ALL
        SELECT 'TABLE', 'users' FROM dual UNION ALL
        SELECT 'TABLE', 'role' FROM dual UNION ALL
        SELECT 'SEQUENCE', 'seq_answer_selected_option' FROM dual UNION ALL
        SELECT 'SEQUENCE', 'seq_answer' FROM dual UNION ALL
        SELECT 'SEQUENCE', 'seq_attempt' FROM dual UNION ALL
        SELECT 'SEQUENCE', 'seq_test_access' FROM dual UNION ALL
        SELECT 'SEQUENCE', 'seq_question_in_test' FROM dual UNION ALL
        SELECT 'SEQUENCE', 'seq_answer_option' FROM dual UNION ALL
        SELECT 'SEQUENCE', 'seq_question' FROM dual UNION ALL
        SELECT 'SEQUENCE', 'seq_test' FROM dual UNION ALL
        SELECT 'SEQUENCE', 'seq_question_type' FROM dual UNION ALL
        SELECT 'SEQUENCE', 'seq_difficulty_level' FROM dual UNION ALL
        SELECT 'SEQUENCE', 'seq_category' FROM dual UNION ALL
        SELECT 'SEQUENCE', 'seq_users' FROM dual UNION ALL
        SELECT 'SEQUENCE', 'seq_role' FROM dual
    ) LOOP
        BEGIN
            IF obj.object_type = 'TABLE' THEN
                EXECUTE IMMEDIATE 'DROP TABLE ' || obj.object_name || ' CASCADE CONSTRAINTS PURGE';
            ELSE
                EXECUTE IMMEDIATE 'DROP ' || obj.object_type || ' ' || obj.object_name;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;
    END LOOP;
END;
/


-- 01_create_tables.sql
CREATE TABLE role (
    id_role NUMBER PRIMARY KEY,
    role_name VARCHAR2(30 CHAR) NOT NULL UNIQUE,
    role_description VARCHAR2(100 CHAR)
);

CREATE TABLE users (
    user_id NUMBER PRIMARY KEY,
    id_role NUMBER NOT NULL,
    password_hash VARCHAR2(500 CHAR) NOT NULL,
    user_name VARCHAR2(100 CHAR) NOT NULL,
    created_at DATE NOT NULL,
    is_active NUMBER(1) NOT NULL,
    CONSTRAINT fk_users_role FOREIGN KEY (id_role) REFERENCES role(id_role),
    CONSTRAINT ck_users_is_active CHECK (is_active IN (0,1))
);

CREATE TABLE category (
    id_category NUMBER PRIMARY KEY,
    category_name VARCHAR2(100 CHAR) NOT NULL UNIQUE,
    category_description VARCHAR2(500 CHAR)
);

CREATE TABLE difficulty_level (
    id_level NUMBER PRIMARY KEY,
    level_name VARCHAR2(50 CHAR) NOT NULL UNIQUE
);

CREATE TABLE question_type (
    type_id NUMBER PRIMARY KEY,
    type_code VARCHAR2(30 CHAR) NOT NULL UNIQUE,
    type_name VARCHAR2(50 CHAR) NOT NULL UNIQUE,
    uses_options NUMBER(1) NOT NULL,
    is_multi_select NUMBER(1) NOT NULL,
    is_numeric_answer NUMBER(1) NOT NULL,
    is_text_answer NUMBER(1) NOT NULL,
    CONSTRAINT ck_qtype_uses_options CHECK (uses_options IN (0,1)),
    CONSTRAINT ck_qtype_is_multi_select CHECK (is_multi_select IN (0,1)),
    CONSTRAINT ck_qtype_is_numeric_answer CHECK (is_numeric_answer IN (0,1)),
    CONSTRAINT ck_qtype_is_text_answer CHECK (is_text_answer IN (0,1))
);

CREATE TABLE attempt_status (
    status_code VARCHAR2(30 CHAR) PRIMARY KEY,
    status_name VARCHAR2(100 CHAR) NOT NULL,
    is_terminal NUMBER(1) NOT NULL,
    is_successful NUMBER(1) NOT NULL,
    CONSTRAINT ck_attempt_status_terminal CHECK (is_terminal IN (0,1)),
    CONSTRAINT ck_attempt_status_successful CHECK (is_successful IN (0,1))
);

CREATE TABLE test (
    id_test NUMBER PRIMARY KEY,
    uid_author NUMBER NOT NULL,
    id_category NUMBER,
    id_level NUMBER,
    test_name VARCHAR2(100 CHAR) NOT NULL,
    test_description VARCHAR2(500 CHAR),
    created_at DATE NOT NULL,
    time_limit NUMBER,
    attempt_limit NUMBER NOT NULL,
    question_count NUMBER,
    show_feedback NUMBER(1) NOT NULL,
    is_active NUMBER(1) NOT NULL,
    CONSTRAINT fk_test_author FOREIGN KEY (uid_author) REFERENCES users(user_id),
    CONSTRAINT fk_test_category FOREIGN KEY (id_category) REFERENCES category(id_category),
    CONSTRAINT fk_test_level FOREIGN KEY (id_level) REFERENCES difficulty_level(id_level),
    CONSTRAINT ck_test_show_feedback CHECK (show_feedback IN (0,1)),
    CONSTRAINT ck_test_is_active CHECK (is_active IN (0,1)),
    CONSTRAINT ck_test_attempt_limit CHECK (attempt_limit > 0),
    CONSTRAINT ck_test_time_limit CHECK (time_limit IS NULL OR time_limit > 0),
    CONSTRAINT ck_test_question_count CHECK (question_count IS NULL OR question_count > 0)
);

CREATE TABLE question (
    id_question NUMBER PRIMARY KEY,
    uid_author NUMBER NOT NULL,
    id_category NUMBER NOT NULL,
    id_level NUMBER NOT NULL,
    type_id NUMBER NOT NULL,
    question_text VARCHAR2(500 CHAR) NOT NULL,
    image_path VARCHAR2(255 CHAR),
    explanation VARCHAR2(500 CHAR),
    correct_text VARCHAR2(500 CHAR),
    correct_number NUMBER,
    tolerance NUMBER,
    created_at DATE NOT NULL,
    is_active NUMBER(1) NOT NULL,
    CONSTRAINT fk_question_author FOREIGN KEY (uid_author) REFERENCES users(user_id),
    CONSTRAINT fk_question_category FOREIGN KEY (id_category) REFERENCES category(id_category),
    CONSTRAINT fk_question_level FOREIGN KEY (id_level) REFERENCES difficulty_level(id_level),
    CONSTRAINT fk_question_type FOREIGN KEY (type_id) REFERENCES question_type(type_id),
    CONSTRAINT ck_question_is_active CHECK (is_active IN (0,1)),
    CONSTRAINT ck_question_tolerance CHECK (tolerance IS NULL OR tolerance >= 0)
);

CREATE TABLE answer_option (
    id_option NUMBER PRIMARY KEY,
    id_question NUMBER NOT NULL,
    option_text VARCHAR2(500 CHAR) NOT NULL,
    is_correct NUMBER(1) NOT NULL,
    CONSTRAINT fk_option_question FOREIGN KEY (id_question) REFERENCES question(id_question),
    CONSTRAINT ck_option_is_correct CHECK (is_correct IN (0,1))
);

CREATE TABLE question_in_test (
    id_qt NUMBER PRIMARY KEY,
    id_test NUMBER NOT NULL,
    id_question NUMBER NOT NULL,
    weight NUMBER NOT NULL,
    order_num NUMBER NOT NULL,
    is_required NUMBER(1) NOT NULL,
    time_limit NUMBER,
    CONSTRAINT fk_qt_test FOREIGN KEY (id_test) REFERENCES test(id_test),
    CONSTRAINT fk_qt_question FOREIGN KEY (id_question) REFERENCES question(id_question),
    CONSTRAINT uq_qt_test_question UNIQUE (id_test, id_question),
    CONSTRAINT uq_qt_test_order UNIQUE (id_test, order_num),
    CONSTRAINT ck_qt_is_required CHECK (is_required IN (0,1)),
    CONSTRAINT ck_qt_weight CHECK (weight > 0),
    CONSTRAINT ck_qt_order_num CHECK (order_num > 0),
    CONSTRAINT ck_qt_time_limit CHECK (time_limit IS NULL OR time_limit > 0)
);

CREATE TABLE test_access (
    id_access NUMBER PRIMARY KEY,
    user_id NUMBER NOT NULL,
    id_test NUMBER NOT NULL,
    granted_at DATE NOT NULL,
    is_active NUMBER(1) NOT NULL,
    CONSTRAINT fk_access_user FOREIGN KEY (user_id) REFERENCES users(user_id),
    CONSTRAINT fk_access_test FOREIGN KEY (id_test) REFERENCES test(id_test),
    CONSTRAINT uq_access_user_test UNIQUE (user_id, id_test),
    CONSTRAINT ck_access_is_active CHECK (is_active IN (0,1))
);

CREATE TABLE attempt (
    id_attempt NUMBER PRIMARY KEY,
    user_id NUMBER NOT NULL,
    id_test NUMBER NOT NULL,
    attempt_number NUMBER NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    status VARCHAR2(30 CHAR) NOT NULL,
    score NUMBER,
    percent_result NUMBER,
    finished_in_time NUMBER(1) NOT NULL,
    CONSTRAINT fk_attempt_user FOREIGN KEY (user_id) REFERENCES users(user_id),
    CONSTRAINT fk_attempt_test FOREIGN KEY (id_test) REFERENCES test(id_test),
    CONSTRAINT fk_attempt_status FOREIGN KEY (status) REFERENCES attempt_status(status_code),
    CONSTRAINT uq_attempt_user_test_num UNIQUE (user_id, id_test, attempt_number),
    CONSTRAINT ck_attempt_finished_in_time CHECK (finished_in_time IN (0,1)),
    CONSTRAINT ck_attempt_attempt_number CHECK (attempt_number > 0),
    CONSTRAINT ck_attempt_percent_result CHECK (percent_result IS NULL OR (percent_result >= 0 AND percent_result <= 100))
);

CREATE TABLE answer (
    id_answer NUMBER PRIMARY KEY,
    id_attempt NUMBER NOT NULL,
    id_qt NUMBER NOT NULL,
    answer_text VARCHAR2(500 CHAR),
    answer_number NUMBER,
    is_correct NUMBER(1),
    earned_score NUMBER,
    is_checked NUMBER(1),
    answer_date DATE,
    answer_time NUMBER,
    CONSTRAINT fk_answer_attempt FOREIGN KEY (id_attempt) REFERENCES attempt(id_attempt),
    CONSTRAINT fk_answer_qt FOREIGN KEY (id_qt) REFERENCES question_in_test(id_qt),
    CONSTRAINT uq_answer_attempt_qt UNIQUE (id_attempt, id_qt),
    CONSTRAINT ck_answer_is_correct CHECK (is_correct IN (0,1)),
    CONSTRAINT ck_answer_is_checked CHECK (is_checked IN (0,1)),
    CONSTRAINT ck_answer_time CHECK (answer_time IS NULL OR answer_time >= 0),
    CONSTRAINT ck_answer_single_payload CHECK (
        (answer_text IS NOT NULL AND answer_number IS NULL) OR
        (answer_text IS NULL AND answer_number IS NOT NULL) OR
        (answer_text IS NULL AND answer_number IS NULL)
    )
);

CREATE TABLE answer_selected_option (
    id_selected NUMBER PRIMARY KEY,
    id_answer NUMBER NOT NULL,
    id_option NUMBER NOT NULL,
    CONSTRAINT fk_selected_answer FOREIGN KEY (id_answer) REFERENCES answer(id_answer),
    CONSTRAINT fk_selected_option FOREIGN KEY (id_option) REFERENCES answer_option(id_option),
    CONSTRAINT uq_selected_answer_option UNIQUE (id_answer, id_option)
);

-- 03_sequences.sql
CREATE SEQUENCE seq_role START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_users START WITH 1000 INCREMENT BY 1;
CREATE SEQUENCE seq_category START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_difficulty_level START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_question_type START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_test START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_question START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_answer_option START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_question_in_test START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_test_access START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_attempt START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_answer START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_answer_selected_option START WITH 1 INCREMENT BY 1;


-- 02_constraints.sql
CREATE INDEX idx_attempt_user_test ON attempt(user_id, id_test);
CREATE INDEX idx_answer_attempt ON answer(id_attempt);
CREATE INDEX idx_question_category_level ON question(id_category, id_level);
CREATE INDEX idx_question_in_test_test ON question_in_test(id_test);

-- 06_triggers.sql
CREATE OR REPLACE TRIGGER trg_role_bi
BEFORE INSERT ON role
FOR EACH ROW
BEGIN
    IF :NEW.id_role IS NULL THEN
        :NEW.id_role := seq_role.NEXTVAL;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_users_bi
BEFORE INSERT ON users
FOR EACH ROW
BEGIN
    IF :NEW.user_id IS NULL THEN
        :NEW.user_id := seq_users.NEXTVAL;
    END IF;
    IF :NEW.created_at IS NULL THEN
        :NEW.created_at := SYSDATE;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_category_bi
BEFORE INSERT ON category
FOR EACH ROW
BEGIN
    IF :NEW.id_category IS NULL THEN
        :NEW.id_category := seq_category.NEXTVAL;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_difficulty_level_bi
BEFORE INSERT ON difficulty_level
FOR EACH ROW
BEGIN
    IF :NEW.id_level IS NULL THEN
        :NEW.id_level := seq_difficulty_level.NEXTVAL;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_question_type_bi
BEFORE INSERT ON question_type
FOR EACH ROW
BEGIN
    IF :NEW.type_id IS NULL THEN
        :NEW.type_id := seq_question_type.NEXTVAL;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_test_bi
BEFORE INSERT ON test
FOR EACH ROW
BEGIN
    IF :NEW.id_test IS NULL THEN
        :NEW.id_test := seq_test.NEXTVAL;
    END IF;
    IF :NEW.created_at IS NULL THEN
        :NEW.created_at := SYSDATE;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_question_bi
BEFORE INSERT ON question
FOR EACH ROW
BEGIN
    IF :NEW.id_question IS NULL THEN
        :NEW.id_question := seq_question.NEXTVAL;
    END IF;
    IF :NEW.created_at IS NULL THEN
        :NEW.created_at := SYSDATE;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_answer_option_bi
BEFORE INSERT ON answer_option
FOR EACH ROW
BEGIN
    IF :NEW.id_option IS NULL THEN
        :NEW.id_option := seq_answer_option.NEXTVAL;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_question_in_test_bi
BEFORE INSERT ON question_in_test
FOR EACH ROW
BEGIN
    IF :NEW.id_qt IS NULL THEN
        :NEW.id_qt := seq_question_in_test.NEXTVAL;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_test_access_bi
BEFORE INSERT ON test_access
FOR EACH ROW
BEGIN
    IF :NEW.id_access IS NULL THEN
        :NEW.id_access := seq_test_access.NEXTVAL;
    END IF;
    IF :NEW.granted_at IS NULL THEN
        :NEW.granted_at := SYSDATE;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_attempt_bi
BEFORE INSERT ON attempt
FOR EACH ROW
BEGIN
    IF :NEW.id_attempt IS NULL THEN
        :NEW.id_attempt := seq_attempt.NEXTVAL;
    END IF;
    IF :NEW.start_date IS NULL THEN
        :NEW.start_date := SYSDATE;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_answer_bi
BEFORE INSERT ON answer
FOR EACH ROW
BEGIN
    IF :NEW.id_answer IS NULL THEN
        :NEW.id_answer := seq_answer.NEXTVAL;
    END IF;
    IF :NEW.answer_date IS NULL THEN
        :NEW.answer_date := SYSDATE;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_answer_selected_option_bi
BEFORE INSERT ON answer_selected_option
FOR EACH ROW
BEGIN
    IF :NEW.id_selected IS NULL THEN
        :NEW.id_selected := seq_answer_selected_option.NEXTVAL;
    END IF;
END;
/


-- 07_seed_reference_data.sql
MERGE INTO role r
USING (
    SELECT 1 id_role, 'USER' role_name, 'Обычный пользователь' role_description FROM dual UNION ALL
    SELECT 2, 'AUTHOR', 'Автор тестов' FROM dual UNION ALL
    SELECT 3, 'ADMIN', 'Администратор' FROM dual
) src
ON (r.id_role = src.id_role)
WHEN MATCHED THEN UPDATE SET r.role_name = src.role_name, r.role_description = src.role_description
WHEN NOT MATCHED THEN INSERT (id_role, role_name, role_description) VALUES (src.id_role, src.role_name, src.role_description);

MERGE INTO difficulty_level d
USING (
    SELECT 1 id_level, 'Легкий' level_name FROM dual UNION ALL
    SELECT 2, 'Средний' FROM dual UNION ALL
    SELECT 3, 'Сложный' FROM dual
) src
ON (d.id_level = src.id_level)
WHEN MATCHED THEN UPDATE SET d.level_name = src.level_name
WHEN NOT MATCHED THEN INSERT (id_level, level_name) VALUES (src.id_level, src.level_name);

MERGE INTO question_type qt
USING (
    SELECT 1 type_id, 'SINGLE_CHOICE' type_code, 'Один правильный ответ' type_name, 1 uses_options, 0 is_multi_select, 0 is_numeric_answer, 0 is_text_answer FROM dual UNION ALL
    SELECT 2, 'MULTIPLE_CHOICE', 'Несколько правильных ответов', 1, 1, 0, 0 FROM dual UNION ALL
    SELECT 3, 'TEXT', 'Текстовый ответ', 0, 0, 0, 1 FROM dual UNION ALL
    SELECT 4, 'NUMBER', 'Числовой ответ', 0, 0, 1, 0 FROM dual UNION ALL
    SELECT 5, 'TRUE_FALSE', 'Верно / неверно', 1, 0, 0, 0 FROM dual UNION ALL
    SELECT 6, 'SHORT_TEXT', 'Короткий ответ', 0, 0, 0, 1 FROM dual
) src
ON (qt.type_code = src.type_code)
WHEN MATCHED THEN UPDATE SET
    qt.type_name = src.type_name,
    qt.uses_options = src.uses_options,
    qt.is_multi_select = src.is_multi_select,
    qt.is_numeric_answer = src.is_numeric_answer,
    qt.is_text_answer = src.is_text_answer
WHEN NOT MATCHED THEN INSERT (type_id, type_code, type_name, uses_options, is_multi_select, is_numeric_answer, is_text_answer)
VALUES (src.type_id, src.type_code, src.type_name, src.uses_options, src.is_multi_select, src.is_numeric_answer, src.is_text_answer);

MERGE INTO attempt_status s
USING (
    SELECT 'STARTED' status_code, 'Начата' status_name, 0 is_terminal, 0 is_successful FROM dual UNION ALL
    SELECT 'FINISHED', 'Завершена', 1, 1 FROM dual UNION ALL
    SELECT 'TIME_EXPIRED', 'Время истекло', 1, 1 FROM dual UNION ALL
    SELECT 'INTERRUPTED', 'Прервана', 1, 0 FROM dual
) src
ON (s.status_code = src.status_code)
WHEN MATCHED THEN UPDATE SET
    s.status_name = src.status_name,
    s.is_terminal = src.is_terminal,
    s.is_successful = src.is_successful
WHEN NOT MATCHED THEN INSERT (status_code, status_name, is_terminal, is_successful)
VALUES (src.status_code, src.status_name, src.is_terminal, src.is_successful);

COMMIT;

-- 04_package_spec.sql
CREATE OR REPLACE PACKAGE quiz_platform AS
    PROCEDURE info;
    PROCEDURE register_user(p_user_name VARCHAR2, p_password VARCHAR2);
    FUNCTION register_user_id(p_user_name VARCHAR2, p_password VARCHAR2) RETURN NUMBER;
    FUNCTION login_user(p_uid NUMBER, p_password VARCHAR2) RETURN NUMBER;
    FUNCTION check_author_role(p_uid NUMBER) RETURN NUMBER;
    FUNCTION check_admin_role(p_uid NUMBER) RETURN NUMBER;
    FUNCTION get_user(p_uid NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION list_categories RETURN SYS_REFCURSOR;
    FUNCTION list_difficulty_levels RETURN SYS_REFCURSOR;
    FUNCTION list_question_types RETURN SYS_REFCURSOR;
    PROCEDURE create_test(p_uid_author NUMBER, p_test_name VARCHAR2, p_test_description VARCHAR2, p_id_category NUMBER, p_id_level NUMBER, p_time_limit NUMBER, p_attempt_limit NUMBER, p_show_feedback NUMBER, p_question_count NUMBER);
    FUNCTION create_test_id(p_uid_author NUMBER, p_test_name VARCHAR2, p_test_description VARCHAR2, p_id_category NUMBER, p_id_level NUMBER, p_time_limit NUMBER, p_attempt_limit NUMBER, p_show_feedback NUMBER, p_question_count NUMBER) RETURN NUMBER;
    PROCEDURE publish_test(p_uid_author NUMBER, p_id_test NUMBER, p_direct_call NUMBER DEFAULT 1);
    PROCEDURE generate_test_questions(p_uid_author NUMBER, p_id_test NUMBER);
    PROCEDURE add_question(p_uid_author NUMBER, p_question_text VARCHAR2, p_id_category NUMBER, p_id_level NUMBER, p_type_id NUMBER, p_correct_text VARCHAR2, p_correct_number NUMBER, p_tolerance NUMBER, p_explanation VARCHAR2);
    FUNCTION add_question_id(p_uid_author NUMBER, p_question_text VARCHAR2, p_id_category NUMBER, p_id_level NUMBER, p_type_id NUMBER, p_correct_text VARCHAR2, p_correct_number NUMBER, p_tolerance NUMBER, p_explanation VARCHAR2) RETURN NUMBER;
    PROCEDURE add_answer_option(p_id_question NUMBER, p_option_text VARCHAR2, p_is_correct NUMBER);
    PROCEDURE add_question_type(p_type_name VARCHAR2);
    PROCEDURE add_category(p_category_name VARCHAR2, p_category_description VARCHAR2);
    PROCEDURE add_difficulty_level(p_level_name VARCHAR2);
    PROCEDURE deactivate_question(p_id_question NUMBER, p_uid_author NUMBER);
    PROCEDURE include_question_in_test(p_uid_author NUMBER, p_id_test NUMBER, p_id_question NUMBER, p_weight NUMBER, p_order_num NUMBER, p_is_required NUMBER, p_time_limit NUMBER);
    PROCEDURE grant_test_access(p_uid_author NUMBER, p_id_test NUMBER, p_uid NUMBER);
    PROCEDURE deactivate_test_access(p_id_test NUMBER, p_uid NUMBER, p_uid_author NUMBER);
    FUNCTION check_access(p_id_test NUMBER, p_uid NUMBER) RETURN NUMBER;
    PROCEDURE start_attempt(p_id_test NUMBER, p_uid NUMBER);
    FUNCTION start_attempt_id(p_id_test NUMBER, p_uid NUMBER) RETURN NUMBER;
    PROCEDURE save_answer(p_id_attempt NUMBER, p_id_qt NUMBER, p_answer_text VARCHAR2, p_answer_number NUMBER, p_answer_time NUMBER, p_uid NUMBER);
    FUNCTION save_answer_id(p_id_attempt NUMBER, p_id_qt NUMBER, p_answer_text VARCHAR2, p_answer_number NUMBER, p_answer_time NUMBER, p_uid NUMBER) RETURN NUMBER;
    PROCEDURE save_selected_option(p_id_answer NUMBER, p_id_option NUMBER);
    FUNCTION check_answer(p_id_answer NUMBER) RETURN NUMBER;
    FUNCTION calc_answer_score(p_id_answer NUMBER) RETURN NUMBER;
    PROCEDURE finish_attempt(p_id_attempt NUMBER, p_uid NUMBER);
    PROCEDURE calc_result(p_id_attempt NUMBER);
    FUNCTION list_author_questions(p_uid_author NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION get_author_question(p_id_question NUMBER, p_uid_author NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION list_answer_options(p_id_question NUMBER, p_uid_author NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION list_available_tests(p_uid NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION get_available_test(p_id_test NUMBER, p_uid NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION get_attempt(p_id_attempt NUMBER, p_uid NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION list_attempt_questions(p_id_attempt NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION list_attempt_answers(p_id_attempt NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION list_attempt_selected_options(p_id_attempt NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION list_attempt_question_options(p_id_attempt NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION get_attempt_result(p_id_attempt NUMBER, p_uid NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION list_result_answers(p_id_attempt NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION list_result_selected_options(p_id_attempt NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION list_result_correct_options(p_id_attempt NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION list_user_attempts(p_uid NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION list_author_tests(p_uid_author NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION get_author_test(p_id_test NUMBER, p_uid_author NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION list_test_questions(p_id_test NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION list_selected_test_questions(p_id_test NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION list_question_pool(p_id_test NUMBER, p_uid_author NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION get_author_test_access_header(p_id_test NUMBER, p_uid_author NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION list_test_access(p_id_test NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION get_test_statistics_summary(p_id_test NUMBER, p_uid_author NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION list_test_statistics_questions(p_id_test NUMBER, p_uid_author NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION list_admin_users(p_uid_admin NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION list_admin_tests(p_uid_admin NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION list_admin_questions(p_uid_admin NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION get_admin_statistics(p_uid_admin NUMBER) RETURN SYS_REFCURSOR;
    PROCEDURE show_result(p_id_attempt NUMBER);
    PROCEDURE show_user_attempts(p_uid NUMBER);
    PROCEDURE show_test_statistics(p_id_test NUMBER);
END quiz_platform;
/

-- 05_package_body.sql
CREATE OR REPLACE PACKAGE BODY quiz_platform AS
    PROCEDURE info IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('quiz_platform package loaded');
    END;

    FUNCTION has_role(p_uid NUMBER, p_role_name VARCHAR2) RETURN NUMBER IS
        v_cnt NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_cnt
        FROM users u
        JOIN role r ON r.id_role = u.id_role
        WHERE u.user_id = p_uid
          AND u.is_active = 1
          AND r.role_name = p_role_name;

        IF v_cnt > 0 THEN
            RETURN 1;
        END IF;
        RETURN 0;
    END;

    PROCEDURE require_author(p_uid NUMBER) IS
        v_cnt NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_cnt
        FROM users u
        JOIN role r ON r.id_role = u.id_role
        WHERE u.user_id = p_uid
          AND u.is_active = 1
          AND r.role_name IN ('AUTHOR', 'ADMIN');

        IF v_cnt = 0 THEN
            RAISE_APPLICATION_ERROR(-20030, 'Доступ разрешен только автору или администратору');
        END IF;
    END;

    FUNCTION check_author_role(p_uid NUMBER) RETURN NUMBER IS
        v_cnt NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_cnt
        FROM users u
        JOIN role r ON r.id_role = u.id_role
        WHERE u.user_id = p_uid
          AND u.is_active = 1
          AND r.role_name IN ('AUTHOR', 'ADMIN');

        IF v_cnt > 0 THEN
            RETURN 1;
        END IF;
        RETURN 0;
    END;

    FUNCTION check_admin_role(p_uid NUMBER) RETURN NUMBER IS
    BEGIN
        RETURN has_role(p_uid, 'ADMIN');
    END;

    PROCEDURE require_admin(p_uid NUMBER) IS
    BEGIN
        IF check_admin_role(p_uid) <> 1 THEN
            RAISE_APPLICATION_ERROR(-20031, 'Доступ разрешен только администратору');
        END IF;
    END;

    FUNCTION is_terminal_attempt_status(p_status VARCHAR2) RETURN NUMBER IS
        v_terminal NUMBER;
    BEGIN
        SELECT is_terminal
        INTO v_terminal
        FROM attempt_status
        WHERE status_code = p_status;
        RETURN v_terminal;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 0;
    END;

    PROCEDURE register_user(p_user_name VARCHAR2, p_password VARCHAR2) IS
        v_user_id users.user_id%TYPE;
    BEGIN
        v_user_id := register_user_id(p_user_name, p_password);
    END;

    FUNCTION register_user_id(p_user_name VARCHAR2, p_password VARCHAR2) RETURN NUMBER IS
        v_password_hash users.password_hash%TYPE;
        v_user_id users.user_id%TYPE;
        v_role_id role.id_role%TYPE;
    BEGIN
        IF p_user_name IS NULL OR LENGTH(TRIM(p_user_name)) = 0 THEN
            RAISE_APPLICATION_ERROR(-20010, 'Имя пользователя не может быть пустым');
        END IF;
        IF p_password IS NULL OR LENGTH(p_password) < 4 THEN
            RAISE_APPLICATION_ERROR(-20011, 'Пароль слишком короткий');
        END IF;

        SELECT STANDARD_HASH(p_password, 'SHA256') INTO v_password_hash FROM dual;
        SELECT id_role INTO v_role_id FROM role WHERE role_name = 'USER';

        INSERT INTO users (id_role, password_hash, user_name, created_at, is_active)
        VALUES (v_role_id, v_password_hash, TRIM(p_user_name), SYSDATE, 1)
        RETURNING user_id INTO v_user_id;

        RETURN v_user_id;
    END;

    FUNCTION login_user(p_uid NUMBER, p_password VARCHAR2) RETURN NUMBER IS
        v_role_id users.id_role%TYPE;
        v_hash users.password_hash%TYPE;
        v_password_hash users.password_hash%TYPE;
        v_active users.is_active%TYPE;
    BEGIN
        BEGIN
            SELECT id_role, password_hash, is_active
            INTO v_role_id, v_hash, v_active
            FROM users
            WHERE user_id = p_uid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20001, 'Неверный user_id');
        END;

        IF v_active <> 1 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Пользователь неактивен');
        END IF;

        SELECT STANDARD_HASH(p_password, 'SHA256') INTO v_password_hash FROM dual;

        IF v_hash <> v_password_hash THEN
            RAISE_APPLICATION_ERROR(-20003, 'Неверный пароль');
        END IF;

        RETURN v_role_id;
    END;

    PROCEDURE create_test(
        p_uid_author NUMBER,
        p_test_name VARCHAR2,
        p_test_description VARCHAR2,
        p_id_category NUMBER,
        p_id_level NUMBER,
        p_time_limit NUMBER,
        p_attempt_limit NUMBER,
        p_show_feedback NUMBER,
        p_question_count NUMBER
    ) IS
        v_test_id test.id_test%TYPE;
    BEGIN
        v_test_id := create_test_id(
            p_uid_author, p_test_name, p_test_description, p_id_category, p_id_level,
            p_time_limit, p_attempt_limit, p_show_feedback, p_question_count
        );
    END;

    FUNCTION create_test_id(
        p_uid_author NUMBER,
        p_test_name VARCHAR2,
        p_test_description VARCHAR2,
        p_id_category NUMBER,
        p_id_level NUMBER,
        p_time_limit NUMBER,
        p_attempt_limit NUMBER,
        p_show_feedback NUMBER,
        p_question_count NUMBER
    ) RETURN NUMBER IS
        v_test_id test.id_test%TYPE;
    BEGIN
        IF p_test_name IS NULL OR LENGTH(TRIM(p_test_name)) = 0 THEN
            RAISE_APPLICATION_ERROR(-20100, 'Название теста обязательно');
        END IF;
        IF p_attempt_limit IS NULL OR p_attempt_limit <= 0 THEN
            RAISE_APPLICATION_ERROR(-20101, 'Лимит попыток должен быть больше 0');
        END IF;
        IF p_show_feedback NOT IN (0, 1) THEN
            RAISE_APPLICATION_ERROR(-20102, 'show_feedback должен быть 0 или 1');
        END IF;

        require_author(p_uid_author);

        INSERT INTO test (
            uid_author, id_category, id_level, test_name, test_description,
            created_at, time_limit, attempt_limit, question_count, show_feedback, is_active
        ) VALUES (
            p_uid_author, p_id_category, p_id_level, TRIM(p_test_name), p_test_description,
            SYSDATE, p_time_limit, p_attempt_limit, p_question_count, p_show_feedback, 0
        )
        RETURNING id_test INTO v_test_id;

        RETURN v_test_id;
    END;

    PROCEDURE publish_test(p_uid_author NUMBER, p_id_test NUMBER, p_direct_call NUMBER DEFAULT 1) IS
        v_active NUMBER;
        v_q_count NUMBER;
    BEGIN
        require_author(p_uid_author);

        SELECT is_active
        INTO v_active
        FROM test
        WHERE id_test = p_id_test
          AND uid_author = p_uid_author;
        SELECT COUNT(*) INTO v_q_count FROM question_in_test WHERE id_test = p_id_test;

        IF v_active = 0 THEN
            IF v_q_count = 0 THEN
                RAISE_APPLICATION_ERROR(-20104, 'Нельзя опубликовать тест без вопросов');
            END IF;
            UPDATE test SET is_active = 1 WHERE id_test = p_id_test;
        ELSE
            IF p_direct_call = 1 THEN
                UPDATE test SET is_active = 0 WHERE id_test = p_id_test;
            END IF;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20105, 'Тест не найден');
    END;

    PROCEDURE include_question_in_test(
        p_uid_author NUMBER,
        p_id_test NUMBER,
        p_id_question NUMBER,
        p_weight NUMBER,
        p_order_num NUMBER,
        p_is_required NUMBER,
        p_time_limit NUMBER
    ) IS
        v_question_active NUMBER;
        v_test_exists NUMBER;
    BEGIN
        require_author(p_uid_author);

        IF p_is_required NOT IN (0, 1) THEN
            RAISE_APPLICATION_ERROR(-20106, 'is_required должен быть 0 или 1');
        END IF;

        SELECT COUNT(*)
        INTO v_test_exists
        FROM test
        WHERE id_test = p_id_test
          AND uid_author = p_uid_author;
        IF v_test_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20105, 'Тест не найден');
        END IF;

        SELECT is_active
        INTO v_question_active
        FROM question
        WHERE id_question = p_id_question
          AND uid_author = p_uid_author;
        IF v_question_active <> 1 THEN
            RAISE_APPLICATION_ERROR(-20107, 'Нельзя добавить неактивный вопрос');
        END IF;

        INSERT INTO question_in_test (id_test, id_question, weight, order_num, is_required, time_limit)
        VALUES (p_id_test, p_id_question, NVL(p_weight, 1), p_order_num, p_is_required, p_time_limit);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20108, 'Вопрос не найден');
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20109, 'Вопрос уже добавлен или занят порядок вопроса');
    END;

    PROCEDURE generate_test_questions(p_uid_author NUMBER, p_id_test NUMBER) IS
        v_id_level test.id_level%TYPE;
        v_question_count test.question_count%TYPE;
        v_id_category test.id_category%TYPE;
        v_exists NUMBER;
        v_order NUMBER := 1;
    BEGIN
        require_author(p_uid_author);

        SELECT id_level, question_count, id_category
        INTO v_id_level, v_question_count, v_id_category
        FROM test
        WHERE id_test = p_id_test
          AND uid_author = p_uid_author;

        IF v_id_level IS NULL OR v_question_count IS NULL OR v_question_count <= 0 THEN
            RAISE_APPLICATION_ERROR(-20110, 'Для автогенерации заполните сложность и количество вопросов');
        END IF;

        DELETE FROM question_in_test WHERE id_test = p_id_test;

        FOR rec IN (
            SELECT id_question
            FROM (
                SELECT q.id_question
                FROM question q
                WHERE q.is_active = 1
                  AND q.id_level = v_id_level
                  AND (v_id_category IS NULL OR q.id_category = v_id_category)
                ORDER BY DBMS_RANDOM.VALUE
            )
            WHERE ROWNUM <= v_question_count
        ) LOOP
            INSERT INTO question_in_test (id_test, id_question, weight, order_num, is_required, time_limit)
            VALUES (p_id_test, rec.id_question, 1, v_order, 1, NULL);
            v_order := v_order + 1;
        END LOOP;

        SELECT COUNT(*) INTO v_exists FROM question_in_test WHERE id_test = p_id_test;
        IF v_exists < v_question_count THEN
            RAISE_APPLICATION_ERROR(-20111, 'Недостаточно вопросов для генерации');
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20105, 'Тест не найден');
    END;

    PROCEDURE add_question_type(p_type_name VARCHAR2) IS
    BEGIN
        IF p_type_name IS NULL OR LENGTH(TRIM(p_type_name)) = 0 THEN
            RAISE_APPLICATION_ERROR(-20020, 'Название типа вопроса не может быть пустым');
        END IF;
        INSERT INTO question_type (type_code, type_name, uses_options, is_multi_select, is_numeric_answer, is_text_answer)
        VALUES (UPPER(REPLACE(TRIM(p_type_name), ' ', '_')), TRIM(p_type_name), 0, 0, 0, 1);
    END;

    PROCEDURE add_category(p_category_name VARCHAR2, p_category_description VARCHAR2) IS
    BEGIN
        IF p_category_name IS NULL OR LENGTH(TRIM(p_category_name)) = 0 THEN
            RAISE_APPLICATION_ERROR(-20026, 'Название категории не может быть пустым');
        END IF;

        INSERT INTO category (category_name, category_description)
        VALUES (TRIM(p_category_name), p_category_description);
    END;

    PROCEDURE add_difficulty_level(p_level_name VARCHAR2) IS
    BEGIN
        IF p_level_name IS NULL OR LENGTH(TRIM(p_level_name)) = 0 THEN
            RAISE_APPLICATION_ERROR(-20027, 'Название уровня сложности не может быть пустым');
        END IF;

        INSERT INTO difficulty_level (level_name)
        VALUES (TRIM(p_level_name));
    END;

    PROCEDURE add_question(p_uid_author NUMBER, p_question_text VARCHAR2, p_id_category NUMBER, p_id_level NUMBER, p_type_id NUMBER, p_correct_text VARCHAR2, p_correct_number NUMBER, p_tolerance NUMBER, p_explanation VARCHAR2) IS
        v_question_id question.id_question%TYPE;
    BEGIN
        v_question_id := add_question_id(
            p_uid_author, p_question_text, p_id_category, p_id_level, p_type_id,
            p_correct_text, p_correct_number, p_tolerance, p_explanation
        );
    END;

    FUNCTION add_question_id(p_uid_author NUMBER, p_question_text VARCHAR2, p_id_category NUMBER, p_id_level NUMBER, p_type_id NUMBER, p_correct_text VARCHAR2, p_correct_number NUMBER, p_tolerance NUMBER, p_explanation VARCHAR2) RETURN NUMBER IS
        v_question_id question.id_question%TYPE;
    BEGIN
        IF p_question_text IS NULL OR LENGTH(TRIM(p_question_text)) = 0 THEN
            RAISE_APPLICATION_ERROR(-20021, 'Текст вопроса не может быть пустым');
        END IF;
        require_author(p_uid_author);

        INSERT INTO question (uid_author, id_category, id_level, type_id, question_text, explanation, correct_text, correct_number, tolerance, created_at, is_active)
        VALUES (p_uid_author, p_id_category, p_id_level, p_type_id, TRIM(p_question_text), p_explanation, p_correct_text, p_correct_number, p_tolerance, SYSDATE, 1)
        RETURNING id_question INTO v_question_id;

        RETURN v_question_id;
    END;

    PROCEDURE add_answer_option(p_id_question NUMBER, p_option_text VARCHAR2, p_is_correct NUMBER) IS
        v_question_cnt NUMBER;
    BEGIN
        IF p_option_text IS NULL OR LENGTH(TRIM(p_option_text)) = 0 THEN
            RAISE_APPLICATION_ERROR(-20023, 'Текст варианта не может быть пустым');
        END IF;
        IF p_is_correct NOT IN (0, 1) THEN
            RAISE_APPLICATION_ERROR(-20024, 'Признак правильности должен быть 0 или 1');
        END IF;

        SELECT COUNT(*) INTO v_question_cnt FROM question WHERE id_question = p_id_question;
        IF v_question_cnt = 0 THEN
            RAISE_APPLICATION_ERROR(-20025, 'Вопрос не найден');
        END IF;

        INSERT INTO answer_option (id_question, option_text, is_correct)
        VALUES (p_id_question, TRIM(p_option_text), p_is_correct);
    END;

    PROCEDURE deactivate_question(p_id_question NUMBER, p_uid_author NUMBER) IS
    BEGIN
        require_author(p_uid_author);

        UPDATE question
        SET is_active = 0
        WHERE id_question = p_id_question
          AND uid_author = p_uid_author;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20028, 'Вопрос не найден');
        END IF;
    END;

    PROCEDURE grant_test_access(p_uid_author NUMBER, p_id_test NUMBER, p_uid NUMBER) IS
        v_user_cnt NUMBER;
        v_test_cnt NUMBER;
    BEGIN
        require_author(p_uid_author);

        SELECT COUNT(*) INTO v_user_cnt FROM users WHERE user_id = p_uid AND is_active = 1;
        IF v_user_cnt = 0 THEN
            RAISE_APPLICATION_ERROR(-20200, 'Пользователь не найден или неактивен');
        END IF;

        SELECT COUNT(*)
        INTO v_test_cnt
        FROM test
        WHERE id_test = p_id_test
          AND uid_author = p_uid_author;
        IF v_test_cnt = 0 THEN
            RAISE_APPLICATION_ERROR(-20201, 'Тест не найден');
        END IF;

        MERGE INTO test_access ta
        USING (SELECT p_uid user_id, p_id_test id_test FROM dual) src
        ON (ta.user_id = src.user_id AND ta.id_test = src.id_test)
        WHEN MATCHED THEN
            UPDATE SET ta.is_active = 1, ta.granted_at = SYSDATE
        WHEN NOT MATCHED THEN
            INSERT (user_id, id_test, granted_at, is_active)
            VALUES (src.user_id, src.id_test, SYSDATE, 1);
    END;

    PROCEDURE deactivate_test_access(p_id_test NUMBER, p_uid NUMBER, p_uid_author NUMBER) IS
    BEGIN
        require_author(p_uid_author);

        UPDATE test_access ta
        SET ta.is_active = 0
        WHERE ta.id_test = p_id_test
          AND ta.user_id = p_uid
          AND EXISTS (
            SELECT 1
            FROM test t
            WHERE t.id_test = ta.id_test
              AND t.uid_author = p_uid_author
          );

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20202, 'Доступ к тесту не найден');
        END IF;
    END;

    FUNCTION check_access(p_id_test NUMBER, p_uid NUMBER) RETURN NUMBER IS
        v_cnt NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_cnt
        FROM test_access ta
        JOIN test t ON t.id_test = ta.id_test
        JOIN users u ON u.user_id = ta.user_id
        WHERE ta.id_test = p_id_test
          AND ta.user_id = p_uid
          AND ta.is_active = 1
          AND t.is_active = 1
          AND u.is_active = 1;

        IF v_cnt > 0 THEN
            RETURN 1;
        END IF;
        RETURN 0;
    END;
    PROCEDURE start_attempt(p_id_test NUMBER, p_uid NUMBER) IS
        v_attempt_id attempt.id_attempt%TYPE;
    BEGIN
        v_attempt_id := start_attempt_id(p_id_test, p_uid);
    END;

    FUNCTION start_attempt_id(p_id_test NUMBER, p_uid NUMBER) RETURN NUMBER IS
        v_user_active NUMBER;
        v_test_active NUMBER;
        v_access NUMBER;
        v_attempt_limit NUMBER;
        v_attempts_used NUMBER;
        v_attempt_no NUMBER;
        v_attempt_id attempt.id_attempt%TYPE;
    BEGIN
        SELECT is_active INTO v_user_active FROM users WHERE user_id = p_uid;
        IF v_user_active <> 1 THEN
            RAISE_APPLICATION_ERROR(-20300, 'Пользователь неактивен');
        END IF;

        SELECT is_active, attempt_limit
        INTO v_test_active, v_attempt_limit
        FROM test
        WHERE id_test = p_id_test;
        IF v_test_active <> 1 THEN
            RAISE_APPLICATION_ERROR(-20301, 'Тест скрыт');
        END IF;

        v_access := check_access(p_id_test, p_uid);
        IF v_access <> 1 THEN
            RAISE_APPLICATION_ERROR(-20302, 'Нет доступа к тесту');
        END IF;

        SELECT NVL(MAX(attempt_number), 0)
        INTO v_attempts_used
        FROM attempt
        WHERE user_id = p_uid AND id_test = p_id_test;
        IF v_attempts_used >= v_attempt_limit THEN
            RAISE_APPLICATION_ERROR(-20303, 'Превышен лимит попыток');
        END IF;

        v_attempt_no := v_attempts_used + 1;
        INSERT INTO attempt (user_id, id_test, attempt_number, start_date, status, finished_in_time)
        VALUES (p_uid, p_id_test, v_attempt_no, SYSDATE, 'STARTED', 1)
        RETURNING id_attempt INTO v_attempt_id;

        RETURN v_attempt_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20304, 'Пользователь или тест не найден');
    END;

    PROCEDURE save_answer(
        p_id_attempt NUMBER,
        p_id_qt NUMBER,
        p_answer_text VARCHAR2,
        p_answer_number NUMBER,
        p_answer_time NUMBER,
        p_uid NUMBER
    ) IS
        v_answer_id answer.id_answer%TYPE;
    BEGIN
        v_answer_id := save_answer_id(p_id_attempt, p_id_qt, p_answer_text, p_answer_number, p_answer_time, p_uid);
    END;

    FUNCTION save_answer_id(
        p_id_attempt NUMBER,
        p_id_qt NUMBER,
        p_answer_text VARCHAR2,
        p_answer_number NUMBER,
        p_answer_time NUMBER,
        p_uid NUMBER
    ) RETURN NUMBER IS
        v_status attempt.status%TYPE;
        v_attempt_uid attempt.user_id%TYPE;
        v_test_id attempt.id_test%TYPE;
        v_started DATE;
        v_test_time_limit NUMBER;
        v_answer_id answer.id_answer%TYPE;
        v_qt_cnt NUMBER;
    BEGIN
        SELECT a.status, a.user_id, a.id_test, a.start_date, t.time_limit
        INTO v_status, v_attempt_uid, v_test_id, v_started, v_test_time_limit
        FROM attempt a
        JOIN test t ON t.id_test = a.id_test
        WHERE a.id_attempt = p_id_attempt;

        IF v_attempt_uid <> p_uid THEN
            RAISE_APPLICATION_ERROR(-20313, 'Попытка не принадлежит пользователю');
        END IF;

        IF v_status <> 'STARTED' THEN
            RAISE_APPLICATION_ERROR(-20305, 'Попытка завершена');
        END IF;

        SELECT COUNT(*)
        INTO v_qt_cnt
        FROM question_in_test
        WHERE id_qt = p_id_qt
          AND id_test = v_test_id;

        IF v_qt_cnt = 0 THEN
            RAISE_APPLICATION_ERROR(-20312, 'Вопрос не относится к данной попытке');
        END IF;

        IF v_test_time_limit IS NOT NULL
           AND (SYSDATE - v_started) * 86400 > v_test_time_limit THEN
            UPDATE attempt
            SET status = 'TIME_EXPIRED', end_date = SYSDATE, finished_in_time = 0
            WHERE id_attempt = p_id_attempt;
            RAISE_APPLICATION_ERROR(-20306, 'Время теста истекло');
        END IF;

        INSERT INTO answer (
            id_attempt, id_qt, answer_text, answer_number,
            answer_date, answer_time, is_checked
        ) VALUES (
            p_id_attempt, p_id_qt, p_answer_text, p_answer_number,
            SYSDATE, p_answer_time, 0
        )
        RETURNING id_answer INTO v_answer_id;

        RETURN v_answer_id;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20307, 'Ответ уже сохранен');
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20308, 'Попытка не найдена');
    END;

    PROCEDURE save_selected_option(p_id_answer NUMBER, p_id_option NUMBER) IS
        v_id_question NUMBER;
        v_opt_question NUMBER;
    BEGIN
        SELECT qt.id_question
        INTO v_id_question
        FROM answer a
        JOIN question_in_test qt ON qt.id_qt = a.id_qt
        WHERE a.id_answer = p_id_answer;

        SELECT id_question INTO v_opt_question
        FROM answer_option
        WHERE id_option = p_id_option;

        IF v_id_question <> v_opt_question THEN
            RAISE_APPLICATION_ERROR(-20309, 'Вариант не относится к вопросу ответа');
        END IF;

        INSERT INTO answer_selected_option (id_answer, id_option)
        VALUES (p_id_answer, p_id_option);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20310, 'Ответ или вариант не найден');
        WHEN DUP_VAL_ON_INDEX THEN
            NULL;
    END;

    FUNCTION check_answer(p_id_answer NUMBER) RETURN NUMBER IS
        v_uses_options NUMBER;
        v_is_multi_select NUMBER;
        v_is_numeric_answer NUMBER;
        v_is_text_answer NUMBER;
        v_correct_text VARCHAR2(500);
        v_correct_number NUMBER;
        v_tolerance NUMBER;
        v_answer_text VARCHAR2(500);
        v_answer_number NUMBER;
        v_cnt NUMBER;
        v_correct NUMBER := 0;
        v_selected_wrong NUMBER := 0;
        v_selected_correct NUMBER := 0;
        v_total_correct NUMBER := 0;
    BEGIN
        SELECT qt_type.uses_options, qt_type.is_multi_select, qt_type.is_numeric_answer, qt_type.is_text_answer,
               q.correct_text, q.correct_number, NVL(q.tolerance, 0), a.answer_text, a.answer_number
        INTO v_uses_options, v_is_multi_select, v_is_numeric_answer, v_is_text_answer,
             v_correct_text, v_correct_number, v_tolerance, v_answer_text, v_answer_number
        FROM answer a
        JOIN question_in_test qt ON qt.id_qt = a.id_qt
        JOIN question q ON q.id_question = qt.id_question
        JOIN question_type qt_type ON qt_type.type_id = q.type_id
        WHERE a.id_answer = p_id_answer;

        IF v_uses_options = 1 AND v_is_multi_select = 0 THEN
            SELECT COUNT(*)
            INTO v_cnt
            FROM answer_selected_option aso
            JOIN answer_option ao ON ao.id_option = aso.id_option
            WHERE aso.id_answer = p_id_answer
              AND ao.is_correct = 1;
            IF v_cnt = 1 THEN
                SELECT COUNT(*)
                INTO v_cnt
                FROM answer_selected_option
                WHERE id_answer = p_id_answer;
                IF v_cnt = 1 THEN
                    v_correct := 1;
                END IF;
            END IF;
        ELSIF v_uses_options = 1 AND v_is_multi_select = 1 THEN
            SELECT COUNT(*) INTO v_selected_wrong
            FROM answer_selected_option aso
            JOIN answer_option ao ON ao.id_option = aso.id_option
            WHERE aso.id_answer = p_id_answer
              AND ao.is_correct = 0;
            IF v_selected_wrong = 0 THEN
                SELECT COUNT(*) INTO v_selected_correct
                FROM answer_selected_option aso
                JOIN answer_option ao ON ao.id_option = aso.id_option
                WHERE aso.id_answer = p_id_answer
                  AND ao.is_correct = 1;
                SELECT COUNT(*) INTO v_total_correct
                FROM answer_option ao
                JOIN answer a ON a.id_answer = p_id_answer
                JOIN question_in_test qt ON qt.id_qt = a.id_qt
                WHERE ao.id_question = qt.id_question
                  AND ao.is_correct = 1;
                IF v_total_correct > 0 AND v_selected_correct = v_total_correct THEN
                    v_correct := 1;
                END IF;
            END IF;
        ELSIF v_is_text_answer = 1 THEN
            IF LOWER(TRIM(NVL(v_answer_text, ''))) = LOWER(TRIM(NVL(v_correct_text, '#NULL#'))) THEN
                v_correct := 1;
            END IF;
        ELSIF v_is_numeric_answer = 1 THEN
            IF v_answer_number IS NOT NULL
               AND v_correct_number IS NOT NULL
               AND ABS(v_answer_number - v_correct_number) <= v_tolerance THEN
                v_correct := 1;
            END IF;
        END IF;

        UPDATE answer SET is_correct = v_correct, is_checked = 1 WHERE id_answer = p_id_answer;
        RETURN v_correct;
    END;

    FUNCTION calc_answer_score(p_id_answer NUMBER) RETURN NUMBER IS
        v_is_multi_select NUMBER;
        v_weight NUMBER;
        v_q_time_limit NUMBER;
        v_ans_time NUMBER;
        v_score NUMBER := 0;
        v_correct NUMBER;
        v_selected_wrong NUMBER := 0;
        v_selected_correct NUMBER := 0;
        v_total_correct NUMBER := 0;
    BEGIN
        SELECT qt_type.is_multi_select, qt.weight, qt.time_limit, NVL(a.answer_time, 0)
        INTO v_is_multi_select, v_weight, v_q_time_limit, v_ans_time
        FROM answer a
        JOIN question_in_test qt ON qt.id_qt = a.id_qt
        JOIN question q ON q.id_question = qt.id_question
        JOIN question_type qt_type ON qt_type.type_id = q.type_id
        WHERE a.id_answer = p_id_answer;

        IF v_q_time_limit IS NOT NULL AND v_ans_time > v_q_time_limit THEN
            v_score := 0;
            UPDATE answer SET earned_score = v_score WHERE id_answer = p_id_answer;
            RETURN v_score;
        END IF;

        v_correct := check_answer(p_id_answer);

        IF v_is_multi_select = 1 THEN
            SELECT COUNT(*) INTO v_selected_wrong
            FROM answer_selected_option aso
            JOIN answer_option ao ON ao.id_option = aso.id_option
            WHERE aso.id_answer = p_id_answer AND ao.is_correct = 0;

            IF v_selected_wrong = 0 THEN
                SELECT COUNT(*) INTO v_selected_correct
                FROM answer_selected_option aso
                JOIN answer_option ao ON ao.id_option = aso.id_option
                WHERE aso.id_answer = p_id_answer AND ao.is_correct = 1;
                SELECT COUNT(*) INTO v_total_correct
                FROM answer_option ao
                JOIN answer a ON a.id_answer = p_id_answer
                JOIN question_in_test qt ON qt.id_qt = a.id_qt
                WHERE ao.id_question = qt.id_question
                  AND ao.is_correct = 1;
                IF v_total_correct > 0 THEN
                    v_score := v_weight * v_selected_correct / v_total_correct;
                END IF;
            END IF;
        ELSE
            IF v_correct = 1 THEN
                v_score := v_weight;
            ELSE
                v_score := 0;
            END IF;
        END IF;

        UPDATE answer SET earned_score = v_score WHERE id_answer = p_id_answer;
        RETURN v_score;
    END;

    PROCEDURE calc_result(p_id_attempt NUMBER) IS
        v_total_weight NUMBER := 0;
        v_total_score NUMBER := 0;
        v_percent NUMBER := 0;
    BEGIN
        FOR r IN (
            SELECT a.id_answer
            FROM answer a
            WHERE a.id_attempt = p_id_attempt
        ) LOOP
            v_total_score := v_total_score + NVL(calc_answer_score(r.id_answer), 0);
        END LOOP;

        SELECT NVL(SUM(qt.weight), 0)
        INTO v_total_weight
        FROM question_in_test qt
        JOIN attempt at ON at.id_test = qt.id_test
        WHERE at.id_attempt = p_id_attempt;

        IF v_total_weight > 0 THEN
            v_percent := ROUND(v_total_score / v_total_weight * 100, 2);
        END IF;

        UPDATE attempt
        SET score = v_total_score,
            percent_result = v_percent
        WHERE id_attempt = p_id_attempt;
    END;

    PROCEDURE finish_attempt(p_id_attempt NUMBER, p_uid NUMBER) IS
        v_status attempt.status%TYPE;
        v_attempt_uid attempt.user_id%TYPE;
        v_started DATE;
        v_time_limit NUMBER;
        v_new_status VARCHAR2(30);
        v_finished_in_time NUMBER := 1;
    BEGIN
        SELECT a.status, a.user_id, a.start_date, t.time_limit
        INTO v_status, v_attempt_uid, v_started, v_time_limit
        FROM attempt a
        JOIN test t ON t.id_test = a.id_test
        WHERE a.id_attempt = p_id_attempt;

        IF v_attempt_uid <> p_uid THEN
            RAISE_APPLICATION_ERROR(-20313, 'Попытка не принадлежит пользователю');
        END IF;

        IF v_status <> 'STARTED' THEN
            RAISE_APPLICATION_ERROR(-20311, 'Попытка уже завершена');
        END IF;

        v_new_status := 'FINISHED';
        IF v_time_limit IS NOT NULL
           AND (SYSDATE - v_started) * 86400 > v_time_limit THEN
            v_new_status := 'TIME_EXPIRED';
            v_finished_in_time := 0;
        END IF;

        UPDATE attempt
        SET end_date = SYSDATE,
            status = v_new_status,
            finished_in_time = v_finished_in_time
        WHERE id_attempt = p_id_attempt;

        calc_result(p_id_attempt);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20308, 'Попытка не найдена');
    END;

    FUNCTION get_user(p_uid NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR
            SELECT u.user_id, u.user_name, u.id_role, r.role_name, r.role_description, u.is_active
            FROM users u
            JOIN role r ON r.id_role = u.id_role
            WHERE u.user_id = p_uid;
        RETURN rc;
    END;

    FUNCTION list_categories RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR SELECT id_category, category_name, category_description FROM category ORDER BY category_name;
        RETURN rc;
    END;

    FUNCTION list_difficulty_levels RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR SELECT id_level, level_name FROM difficulty_level ORDER BY id_level;
        RETURN rc;
    END;

    FUNCTION list_question_types RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR SELECT type_id, type_name, type_code, uses_options, is_multi_select, is_numeric_answer, is_text_answer FROM question_type ORDER BY type_id;
        RETURN rc;
    END;

    FUNCTION list_author_questions(p_uid_author NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR
            SELECT q.id_question, q.question_text, qt.type_name, c.category_name, d.level_name, q.is_active, q.image_path
            FROM question q
            JOIN question_type qt ON qt.type_id = q.type_id
            JOIN category c ON c.id_category = q.id_category
            JOIN difficulty_level d ON d.id_level = q.id_level
            WHERE q.uid_author = p_uid_author
            ORDER BY q.id_question DESC;
        RETURN rc;
    END;

    FUNCTION get_author_question(p_id_question NUMBER, p_uid_author NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR
            SELECT q.id_question, q.question_text, q.explanation, q.correct_text, q.correct_number, q.tolerance,
                   q.is_active, qt.type_name, c.category_name, d.level_name, q.image_path
            FROM question q
            JOIN question_type qt ON qt.type_id = q.type_id
            JOIN category c ON c.id_category = q.id_category
            JOIN difficulty_level d ON d.id_level = q.id_level
            WHERE q.id_question = p_id_question AND q.uid_author = p_uid_author;
        RETURN rc;
    END;

    FUNCTION list_answer_options(p_id_question NUMBER, p_uid_author NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR
            SELECT ao.id_option, ao.option_text, ao.is_correct
            FROM answer_option ao
            JOIN question q ON q.id_question = ao.id_question
            WHERE ao.id_question = p_id_question
              AND q.uid_author = p_uid_author
            ORDER BY ao.id_option;
        RETURN rc;
    END;

    FUNCTION list_available_tests(p_uid NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR
            SELECT t.id_test, t.test_name, t.test_description, c.category_name, d.level_name,
                   t.time_limit, t.attempt_limit, t.question_count, t.show_feedback,
                   NVL((SELECT MAX(a.attempt_number) FROM attempt a WHERE a.user_id = p_uid AND a.id_test = t.id_test), 0) AS used_attempts
            FROM test_access ta
            JOIN test t ON t.id_test = ta.id_test
            LEFT JOIN category c ON c.id_category = t.id_category
            LEFT JOIN difficulty_level d ON d.id_level = t.id_level
            WHERE ta.user_id = p_uid
              AND ta.is_active = 1
              AND t.is_active = 1
            ORDER BY t.id_test DESC;
        RETURN rc;
    END;

    FUNCTION get_available_test(p_id_test NUMBER, p_uid NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR
            SELECT t.id_test, t.test_name, t.test_description, c.category_name, d.level_name,
                   t.time_limit, t.attempt_limit, t.question_count, t.show_feedback,
                   NVL((SELECT MAX(a.attempt_number) FROM attempt a WHERE a.user_id = p_uid AND a.id_test = t.id_test), 0) AS used_attempts
            FROM test t
            LEFT JOIN category c ON c.id_category = t.id_category
            LEFT JOIN difficulty_level d ON d.id_level = t.id_level
            WHERE t.id_test = p_id_test AND t.is_active = 1;
        RETURN rc;
    END;

    FUNCTION get_attempt(p_id_attempt NUMBER, p_uid NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR
            SELECT a.id_attempt, a.status, a.start_date, a.end_date, t.id_test, t.test_name,
                   t.time_limit, FLOOR((SYSDATE - a.start_date) * 86400) AS elapsed_seconds,
                   CASE WHEN t.time_limit IS NULL THEN NULL ELSE GREATEST(0, t.time_limit - FLOOR((SYSDATE - a.start_date) * 86400)) END AS remaining_seconds
            FROM attempt a
            JOIN test t ON t.id_test = a.id_test
            WHERE a.id_attempt = p_id_attempt AND a.user_id = p_uid;
        RETURN rc;
    END;

    FUNCTION list_attempt_questions(p_id_attempt NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR
            SELECT qt.id_qt, qt.order_num, qt.weight, qt.time_limit,
                   q.id_question, q.question_text, q.type_id, q.explanation,
                   qt_type.uses_options, qt_type.is_multi_select, qt_type.is_numeric_answer, qt_type.is_text_answer,
                   q.image_path
            FROM question_in_test qt
            JOIN question q ON q.id_question = qt.id_question
            JOIN question_type qt_type ON qt_type.type_id = q.type_id
            JOIN attempt a ON a.id_test = qt.id_test
            WHERE a.id_attempt = p_id_attempt
            ORDER BY qt.order_num;
        RETURN rc;
    END;

    FUNCTION list_attempt_answers(p_id_attempt NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR
            SELECT id_answer, id_qt, answer_text, answer_number, is_correct, earned_score, answer_time
            FROM answer
            WHERE id_attempt = p_id_attempt;
        RETURN rc;
    END;

    FUNCTION list_attempt_selected_options(p_id_attempt NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR
            SELECT aso.id_answer, aso.id_option, ao.option_text
            FROM answer_selected_option aso
            JOIN answer a ON a.id_answer = aso.id_answer
            JOIN answer_option ao ON ao.id_option = aso.id_option
            WHERE a.id_attempt = p_id_attempt
            ORDER BY ao.id_option;
        RETURN rc;
    END;

    FUNCTION list_attempt_question_options(p_id_attempt NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR
            SELECT ao.id_option, ao.id_question, ao.option_text
            FROM answer_option ao
            JOIN question q ON q.id_question = ao.id_question
            JOIN question_in_test qt ON qt.id_question = q.id_question
            JOIN attempt a ON a.id_test = qt.id_test
            WHERE a.id_attempt = p_id_attempt
            ORDER BY ao.id_option;
        RETURN rc;
    END;

    FUNCTION get_attempt_result(p_id_attempt NUMBER, p_uid NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR
            SELECT a.id_attempt, a.attempt_number, a.start_date, a.end_date, a.status, a.score, a.percent_result,
                   t.id_test, t.test_name, t.show_feedback,
                   NVL((
                       SELECT AVG(x.percent_result)
                       FROM attempt x
                       WHERE x.id_test = a.id_test
                         AND EXISTS (
                             SELECT 1
                             FROM attempt_status s
                             WHERE s.status_code = x.status
                               AND s.is_successful = 1
                         )
                         AND x.percent_result IS NOT NULL
                   ), 0) AS avg_percent
            FROM attempt a
            JOIN test t ON t.id_test = a.id_test
            WHERE a.id_attempt = p_id_attempt AND a.user_id = p_uid;
        RETURN rc;
    END;

    FUNCTION list_result_answers(p_id_attempt NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR
            SELECT qt.order_num, q.question_text, q.type_id, a.id_answer, a.answer_text, a.answer_number,
                   a.is_correct, a.earned_score, q.correct_text, q.correct_number, q.explanation,
                   qt_type.uses_options, qt_type.is_multi_select, qt_type.is_numeric_answer, qt_type.is_text_answer,
                   q.image_path
            FROM question_in_test qt
            JOIN question q ON q.id_question = qt.id_question
            JOIN question_type qt_type ON qt_type.type_id = q.type_id
            JOIN attempt at ON at.id_test = qt.id_test
            LEFT JOIN answer a ON a.id_qt = qt.id_qt AND a.id_attempt = at.id_attempt
            WHERE at.id_attempt = p_id_attempt
            ORDER BY qt.order_num;
        RETURN rc;
    END;

    FUNCTION list_result_selected_options(p_id_attempt NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR
            SELECT aso.id_answer, ao.option_text
            FROM answer_selected_option aso
            JOIN answer_option ao ON ao.id_option = aso.id_option
            JOIN answer a ON a.id_answer = aso.id_answer
            WHERE a.id_attempt = p_id_attempt
            ORDER BY ao.id_option;
        RETURN rc;
    END;

    FUNCTION list_result_correct_options(p_id_attempt NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR
            SELECT qt.order_num, ao.option_text
            FROM question_in_test qt
            JOIN attempt at ON at.id_test = qt.id_test
            JOIN answer_option ao ON ao.id_question = qt.id_question
            WHERE at.id_attempt = p_id_attempt
              AND ao.is_correct = 1
            ORDER BY qt.order_num, ao.id_option;
        RETURN rc;
    END;

    FUNCTION list_user_attempts(p_uid NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR
            SELECT a.id_attempt, t.test_name, a.attempt_number, a.status, a.score, a.percent_result, a.start_date, a.end_date
            FROM attempt a
            JOIN test t ON t.id_test = a.id_test
            WHERE a.user_id = p_uid
            ORDER BY a.id_attempt DESC;
        RETURN rc;
    END;

    FUNCTION list_author_tests(p_uid_author NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR
            SELECT t.id_test, t.test_name, t.test_description, t.is_active,
                   t.question_count, t.attempt_limit, t.time_limit, t.show_feedback,
                   c.category_name, d.level_name
            FROM test t
            LEFT JOIN category c ON c.id_category = t.id_category
            LEFT JOIN difficulty_level d ON d.id_level = t.id_level
            WHERE t.uid_author = p_uid_author
            ORDER BY t.id_test DESC;
        RETURN rc;
    END;

    FUNCTION get_author_test(p_id_test NUMBER, p_uid_author NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR
            SELECT t.id_test, t.test_name, t.test_description, t.is_active, t.question_count, t.attempt_limit, t.time_limit,
                   t.show_feedback, c.category_name, d.level_name
            FROM test t
            LEFT JOIN category c ON c.id_category = t.id_category
            LEFT JOIN difficulty_level d ON d.id_level = t.id_level
            WHERE t.id_test = p_id_test AND t.uid_author = p_uid_author;
        RETURN rc;
    END;

    FUNCTION list_test_questions(p_id_test NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR
            SELECT qt.id_qt, qt.order_num, qt.weight, qt.is_required, qt.time_limit, q.id_question, q.question_text, q.image_path
            FROM question_in_test qt
            JOIN question q ON q.id_question = qt.id_question
            WHERE qt.id_test = p_id_test
            ORDER BY qt.order_num;
        RETURN rc;
    END;

    FUNCTION list_selected_test_questions(p_id_test NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR
            SELECT qt.order_num, q.id_question, q.question_text, qt.weight, qt.is_required, qt.time_limit, q.image_path
            FROM question_in_test qt
            JOIN question q ON q.id_question = qt.id_question
            WHERE qt.id_test = p_id_test
            ORDER BY qt.order_num;
        RETURN rc;
    END;

    FUNCTION list_question_pool(p_id_test NUMBER, p_uid_author NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR
            SELECT q.id_question, q.question_text, q.image_path
            FROM question q
            JOIN test t ON t.uid_author = q.uid_author
            WHERE t.id_test = p_id_test
              AND q.uid_author = p_uid_author
              AND q.is_active = 1
              AND NOT EXISTS (
                  SELECT 1 FROM question_in_test x WHERE x.id_test = p_id_test AND x.id_question = q.id_question
              )
            ORDER BY q.id_question DESC;
        RETURN rc;
    END;

    FUNCTION get_author_test_access_header(p_id_test NUMBER, p_uid_author NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR
            SELECT id_test, test_name
            FROM test
            WHERE id_test = p_id_test AND uid_author = p_uid_author;
        RETURN rc;
    END;

    FUNCTION list_test_access(p_id_test NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR
            SELECT ta.user_id, u.user_name, ta.is_active, ta.granted_at
            FROM test_access ta
            JOIN users u ON u.user_id = ta.user_id
            WHERE ta.id_test = p_id_test
            ORDER BY ta.granted_at DESC;
        RETURN rc;
    END;

    FUNCTION get_test_statistics_summary(p_id_test NUMBER, p_uid_author NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR
            SELECT
                t.test_name,
                COUNT(a.id_attempt) AS total_attempts,
                SUM(CASE WHEN s.is_successful = 1 THEN 1 ELSE 0 END) AS finished_attempts,
                ROUND(AVG(CASE WHEN s.is_successful = 1 THEN a.score END), 2) AS avg_score,
                ROUND(AVG(CASE WHEN s.is_successful = 1 THEN a.percent_result END), 2) AS avg_percent,
                MIN(CASE WHEN s.is_successful = 1 THEN a.percent_result END) AS min_percent,
                MAX(CASE WHEN s.is_successful = 1 THEN a.percent_result END) AS max_percent
            FROM test t
            LEFT JOIN attempt a ON a.id_test = t.id_test
            LEFT JOIN attempt_status s ON s.status_code = a.status
            WHERE t.id_test = p_id_test
              AND t.uid_author = p_uid_author
            GROUP BY t.test_name;
        RETURN rc;
    END;

    FUNCTION list_test_statistics_questions(p_id_test NUMBER, p_uid_author NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        OPEN rc FOR
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
            FROM test t
            JOIN question_in_test qt ON qt.id_test = t.id_test
            JOIN question q ON q.id_question = qt.id_question
            LEFT JOIN answer a ON a.id_qt = qt.id_qt
                AND EXISTS (
                    SELECT 1
                    FROM attempt at
                    JOIN attempt_status s ON s.status_code = at.status
                    WHERE at.id_attempt = a.id_attempt
                      AND s.is_successful = 1
                )
            WHERE t.id_test = p_id_test
              AND t.uid_author = p_uid_author
            GROUP BY qt.order_num, q.question_text
            ORDER BY qt.order_num;
        RETURN rc;
    END;

    FUNCTION list_admin_users(p_uid_admin NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        require_admin(p_uid_admin);

        OPEN rc FOR
            SELECT u.user_id, u.user_name, r.role_name, u.is_active, u.created_at
            FROM users u
            JOIN role r ON r.id_role = u.id_role
            ORDER BY u.user_id DESC;
        RETURN rc;
    END;

    FUNCTION list_admin_tests(p_uid_admin NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        require_admin(p_uid_admin);

        OPEN rc FOR
            SELECT t.id_test, t.test_name, u.user_name, t.is_active, t.created_at, t.attempt_limit, t.question_count
            FROM test t
            JOIN users u ON u.user_id = t.uid_author
            ORDER BY t.id_test DESC;
        RETURN rc;
    END;

    FUNCTION list_admin_questions(p_uid_admin NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        require_admin(p_uid_admin);

        OPEN rc FOR
            SELECT q.id_question, q.question_text, u.user_name, qt.type_name, q.is_active, q.created_at, q.image_path
            FROM question q
            JOIN users u ON u.user_id = q.uid_author
            JOIN question_type qt ON qt.type_id = q.type_id
            ORDER BY q.id_question DESC;
        RETURN rc;
    END;

    FUNCTION get_admin_statistics(p_uid_admin NUMBER) RETURN SYS_REFCURSOR IS
        rc SYS_REFCURSOR;
    BEGIN
        require_admin(p_uid_admin);

        OPEN rc FOR
            SELECT
                (SELECT COUNT(*) FROM users) AS users_total,
                (SELECT COUNT(*) FROM users WHERE is_active = 1) AS users_active,
                (SELECT COUNT(*) FROM test) AS tests_total,
                (SELECT COUNT(*) FROM test WHERE is_active = 1) AS tests_published,
                (SELECT COUNT(*) FROM question) AS questions_total,
                (SELECT COUNT(*) FROM attempt) AS attempts_total
            FROM dual;
        RETURN rc;
    END;

    PROCEDURE show_result(p_id_attempt NUMBER) IS
        v_test_name test.test_name%TYPE;
        v_attempt_number attempt.attempt_number%TYPE;
        v_status attempt.status%TYPE;
        v_score attempt.score%TYPE;
        v_percent attempt.percent_result%TYPE;
        v_avg_percent NUMBER;
    BEGIN
        SELECT t.test_name, a.attempt_number, a.status, a.score, a.percent_result
        INTO v_test_name, v_attempt_number, v_status, v_score, v_percent
        FROM attempt a
        JOIN test t ON t.id_test = a.id_test
        WHERE a.id_attempt = p_id_attempt;

        SELECT NVL(AVG(x.percent_result), 0)
        INTO v_avg_percent
        FROM attempt x
        WHERE x.id_test = (SELECT id_test FROM attempt WHERE id_attempt = p_id_attempt)
          AND EXISTS (
              SELECT 1
              FROM attempt_status s
              WHERE s.status_code = x.status
                AND s.is_successful = 1
          )
          AND x.percent_result IS NOT NULL;

        DBMS_OUTPUT.PUT_LINE('Тест: ' || v_test_name);
        DBMS_OUTPUT.PUT_LINE('Номер попытки: ' || v_attempt_number);
        DBMS_OUTPUT.PUT_LINE('Статус: ' || v_status);
        DBMS_OUTPUT.PUT_LINE('Балл: ' || NVL(v_score, 0));
        DBMS_OUTPUT.PUT_LINE('Процент: ' || NVL(v_percent, 0));
        DBMS_OUTPUT.PUT_LINE('Средний процент по тесту: ' || ROUND(v_avg_percent, 2));
        DBMS_OUTPUT.PUT_LINE('Разница: ' || ROUND(NVL(v_percent, 0) - v_avg_percent, 2));
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20400, 'Попытка не найдена');
    END;

    PROCEDURE show_user_attempts(p_uid NUMBER) IS
        v_found NUMBER := 0;
    BEGIN
        FOR rec IN (
            SELECT a.id_attempt, t.test_name, a.attempt_number, a.status, a.score, a.percent_result
            FROM attempt a
            JOIN test t ON t.id_test = a.id_test
            WHERE a.user_id = p_uid
            ORDER BY a.id_attempt DESC
        ) LOOP
            v_found := 1;
            DBMS_OUTPUT.PUT_LINE(
                'Попытка #' || rec.id_attempt ||
                ' | Тест: ' || rec.test_name ||
                ' | Номер: ' || rec.attempt_number ||
                ' | Статус: ' || rec.status ||
                ' | Балл: ' || NVL(rec.score, 0) ||
                ' | Процент: ' || NVL(rec.percent_result, 0)
            );
        END LOOP;

        IF v_found = 0 THEN
            DBMS_OUTPUT.PUT_LINE('У пользователя нет попыток.');
        END IF;
    END;
    PROCEDURE show_test_statistics(p_id_test NUMBER) IS
        v_test_name test.test_name%TYPE;
        v_total_attempts NUMBER;
        v_finished_attempts NUMBER;
        v_avg_score NUMBER;
        v_avg_percent NUMBER;
        v_min_percent NUMBER;
        v_max_percent NUMBER;
    BEGIN
        SELECT test_name INTO v_test_name FROM test WHERE id_test = p_id_test;

        SELECT
            COUNT(*),
            SUM(CASE WHEN s.is_successful = 1 THEN 1 ELSE 0 END),
            ROUND(AVG(CASE WHEN s.is_successful = 1 THEN score END), 2),
            ROUND(AVG(CASE WHEN s.is_successful = 1 THEN percent_result END), 2),
            MIN(CASE WHEN s.is_successful = 1 THEN percent_result END),
            MAX(CASE WHEN s.is_successful = 1 THEN percent_result END)
        INTO
            v_total_attempts,
            v_finished_attempts,
            v_avg_score,
            v_avg_percent,
            v_min_percent,
            v_max_percent
        FROM attempt a
        LEFT JOIN attempt_status s ON s.status_code = a.status
        WHERE a.id_test = p_id_test;

        DBMS_OUTPUT.PUT_LINE('Статистика теста: ' || v_test_name || ' (#' || p_id_test || ')');
        DBMS_OUTPUT.PUT_LINE('Попыток: ' || NVL(v_total_attempts, 0));
        DBMS_OUTPUT.PUT_LINE('Завершено: ' || NVL(v_finished_attempts, 0));
        DBMS_OUTPUT.PUT_LINE('Средний балл: ' || NVL(v_avg_score, 0));
        DBMS_OUTPUT.PUT_LINE('Средний процент: ' || NVL(v_avg_percent, 0));
        DBMS_OUTPUT.PUT_LINE('Минимальный процент: ' || NVL(v_min_percent, 0));
        DBMS_OUTPUT.PUT_LINE('Максимальный процент: ' || NVL(v_max_percent, 0));

        FOR q IN (
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
                AND EXISTS (
                    SELECT 1
                    FROM attempt at
                    JOIN attempt_status s ON s.status_code = at.status
                    WHERE at.id_attempt = a.id_attempt
                      AND s.is_successful = 1
                )
            WHERE qt.id_test = p_id_test
            GROUP BY qt.order_num, q.question_text
            ORDER BY qt.order_num
        ) LOOP
            DBMS_OUTPUT.PUT_LINE(
                'Q' || q.order_num ||
                ' | ' || q.question_text ||
                ' | Ответов: ' || NVL(q.total_answers, 0) ||
                ' | Правильных: ' || NVL(q.correct_answers, 0) ||
                ' | %: ' || NVL(q.percent_correct, 0) ||
                ' | Ср. время: ' || NVL(q.avg_answer_time, 0) ||
                ' | Ср. балл: ' || NVL(q.avg_earned_score, 0)
            );
        END LOOP;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20401, 'Тест не найден');
    END;
END quiz_platform;
/
