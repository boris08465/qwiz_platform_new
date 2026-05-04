CREATE TABLE role (
    id_role NUMBER PRIMARY KEY,
    role_name VARCHAR2(30) NOT NULL UNIQUE,
    role_description VARCHAR2(100)
);

CREATE TABLE users (
    uid NUMBER PRIMARY KEY,
    id_role NUMBER NOT NULL,
    password_hash VARCHAR2(500) NOT NULL,
    user_name VARCHAR2(100) NOT NULL,
    created_at DATE NOT NULL,
    is_active NUMBER(1) NOT NULL,
    CONSTRAINT fk_users_role FOREIGN KEY (id_role) REFERENCES role(id_role),
    CONSTRAINT ck_users_is_active CHECK (is_active IN (0,1))
);

CREATE TABLE category (
    id_category NUMBER PRIMARY KEY,
    category_name VARCHAR2(100) NOT NULL UNIQUE,
    category_description VARCHAR2(500)
);

CREATE TABLE difficulty_level (
    id_level NUMBER PRIMARY KEY,
    level_name VARCHAR2(50) NOT NULL UNIQUE
);

CREATE TABLE question_type (
    type_id NUMBER PRIMARY KEY,
    type_name VARCHAR2(50) NOT NULL UNIQUE
);

CREATE TABLE test (
    id_test NUMBER PRIMARY KEY,
    uid_author NUMBER NOT NULL,
    id_category NUMBER,
    id_level NUMBER,
    test_name VARCHAR2(100) NOT NULL,
    test_description VARCHAR2(500),
    created_at DATE NOT NULL,
    time_limit NUMBER,
    attempt_limit NUMBER NOT NULL,
    question_count NUMBER,
    show_feedback NUMBER(1) NOT NULL,
    is_active NUMBER(1) NOT NULL,
    CONSTRAINT fk_test_author FOREIGN KEY (uid_author) REFERENCES users(uid),
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
    question_text VARCHAR2(500) NOT NULL,
    explanation VARCHAR2(500),
    correct_text VARCHAR2(500),
    correct_number NUMBER,
    tolerance NUMBER,
    created_at DATE NOT NULL,
    is_active NUMBER(1) NOT NULL,
    CONSTRAINT fk_question_author FOREIGN KEY (uid_author) REFERENCES users(uid),
    CONSTRAINT fk_question_category FOREIGN KEY (id_category) REFERENCES category(id_category),
    CONSTRAINT fk_question_level FOREIGN KEY (id_level) REFERENCES difficulty_level(id_level),
    CONSTRAINT fk_question_type FOREIGN KEY (type_id) REFERENCES question_type(type_id),
    CONSTRAINT ck_question_is_active CHECK (is_active IN (0,1)),
    CONSTRAINT ck_question_tolerance CHECK (tolerance IS NULL OR tolerance >= 0)
);

CREATE TABLE answer_option (
    id_option NUMBER PRIMARY KEY,
    id_question NUMBER NOT NULL,
    option_text VARCHAR2(500) NOT NULL,
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
    uid NUMBER NOT NULL,
    id_test NUMBER NOT NULL,
    granted_at DATE NOT NULL,
    is_active NUMBER(1) NOT NULL,
    CONSTRAINT fk_access_user FOREIGN KEY (uid) REFERENCES users(uid),
    CONSTRAINT fk_access_test FOREIGN KEY (id_test) REFERENCES test(id_test),
    CONSTRAINT uq_access_user_test UNIQUE (uid, id_test),
    CONSTRAINT ck_access_is_active CHECK (is_active IN (0,1))
);

CREATE TABLE attempt (
    id_attempt NUMBER PRIMARY KEY,
    uid NUMBER NOT NULL,
    id_test NUMBER NOT NULL,
    attempt_number NUMBER NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    status VARCHAR2(30) NOT NULL,
    score NUMBER,
    percent_result NUMBER,
    finished_in_time NUMBER(1) NOT NULL,
    CONSTRAINT fk_attempt_user FOREIGN KEY (uid) REFERENCES users(uid),
    CONSTRAINT fk_attempt_test FOREIGN KEY (id_test) REFERENCES test(id_test),
    CONSTRAINT uq_attempt_user_test_num UNIQUE (uid, id_test, attempt_number),
    CONSTRAINT ck_attempt_finished_in_time CHECK (finished_in_time IN (0,1)),
    CONSTRAINT ck_attempt_status CHECK (status IN ('STARTED', 'FINISHED', 'TIME_EXPIRED', 'INTERRUPTED')),
    CONSTRAINT ck_attempt_attempt_number CHECK (attempt_number > 0),
    CONSTRAINT ck_attempt_percent_result CHECK (percent_result IS NULL OR (percent_result >= 0 AND percent_result <= 100))
);

CREATE TABLE answer (
    id_answer NUMBER PRIMARY KEY,
    id_attempt NUMBER NOT NULL,
    id_qt NUMBER NOT NULL,
    answer_text VARCHAR2(500),
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

