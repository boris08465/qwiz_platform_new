CREATE OR REPLACE PACKAGE BODY quiz_platform AS
    PROCEDURE info IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('quiz_platform package loaded');
    END;

    PROCEDURE register_user(p_user_name VARCHAR2, p_password VARCHAR2) IS
    BEGIN
        IF p_user_name IS NULL OR LENGTH(TRIM(p_user_name)) = 0 THEN
            RAISE_APPLICATION_ERROR(-20010, 'Имя пользователя не может быть пустым');
        END IF;
        IF p_password IS NULL OR LENGTH(p_password) < 4 THEN
            RAISE_APPLICATION_ERROR(-20011, 'Пароль слишком короткий');
        END IF;

        INSERT INTO users (id_role, password_hash, user_name, created_at, is_active)
        VALUES (1, STANDARD_HASH(p_password, 'SHA256'), TRIM(p_user_name), SYSDATE, 1);
    END;

    FUNCTION login_user(p_uid NUMBER, p_password VARCHAR2) RETURN NUMBER IS
        v_role_id users.id_role%TYPE;
        v_hash users.password_hash%TYPE;
        v_active users.is_active%TYPE;
    BEGIN
        BEGIN
            SELECT id_role, password_hash, is_active
            INTO v_role_id, v_hash, v_active
            FROM users
            WHERE uid = p_uid;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20001, 'Неверный UID');
        END;

        IF v_active <> 1 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Пользователь неактивен');
        END IF;

        IF v_hash <> STANDARD_HASH(p_password, 'SHA256') THEN
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
        v_author_cnt NUMBER;
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

        SELECT COUNT(*) INTO v_author_cnt
        FROM users
        WHERE uid = p_uid_author AND is_active = 1;

        IF v_author_cnt = 0 THEN
            RAISE_APPLICATION_ERROR(-20103, 'Автор не найден или неактивен');
        END IF;

        INSERT INTO test (
            uid_author, id_category, id_level, test_name, test_description,
            created_at, time_limit, attempt_limit, question_count, show_feedback, is_active
        ) VALUES (
            p_uid_author, p_id_category, p_id_level, TRIM(p_test_name), p_test_description,
            SYSDATE, p_time_limit, p_attempt_limit, p_question_count, p_show_feedback, 0
        );
    END;

    PROCEDURE publish_test(p_id_test NUMBER, p_direct_call NUMBER DEFAULT 1) IS
        v_active NUMBER;
        v_q_count NUMBER;
    BEGIN
        SELECT is_active INTO v_active FROM test WHERE id_test = p_id_test;
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
        IF p_is_required NOT IN (0, 1) THEN
            RAISE_APPLICATION_ERROR(-20106, 'is_required должен быть 0 или 1');
        END IF;

        SELECT COUNT(*) INTO v_test_exists FROM test WHERE id_test = p_id_test;
        IF v_test_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20105, 'Тест не найден');
        END IF;

        SELECT is_active INTO v_question_active FROM question WHERE id_question = p_id_question;
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

    PROCEDURE generate_test_questions(p_id_test NUMBER) IS
        v_id_level test.id_level%TYPE;
        v_question_count test.question_count%TYPE;
        v_id_category test.id_category%TYPE;
        v_exists NUMBER;
        v_order NUMBER := 1;
    BEGIN
        SELECT id_level, question_count, id_category
        INTO v_id_level, v_question_count, v_id_category
        FROM test
        WHERE id_test = p_id_test;

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
        INSERT INTO question_type (type_name) VALUES (TRIM(p_type_name));
    END;

    PROCEDURE add_question(p_uid_author NUMBER, p_question_text VARCHAR2, p_id_category NUMBER, p_id_level NUMBER, p_type_id NUMBER, p_correct_text VARCHAR2, p_correct_number NUMBER, p_tolerance NUMBER, p_explanation VARCHAR2) IS
        v_user_cnt NUMBER;
    BEGIN
        IF p_question_text IS NULL OR LENGTH(TRIM(p_question_text)) = 0 THEN
            RAISE_APPLICATION_ERROR(-20021, 'Текст вопроса не может быть пустым');
        END IF;
        SELECT COUNT(*) INTO v_user_cnt FROM users WHERE uid = p_uid_author AND is_active = 1;
        IF v_user_cnt = 0 THEN
            RAISE_APPLICATION_ERROR(-20022, 'Автор не найден или неактивен');
        END IF;

        INSERT INTO question (uid_author, id_category, id_level, type_id, question_text, explanation, correct_text, correct_number, tolerance, created_at, is_active)
        VALUES (p_uid_author, p_id_category, p_id_level, p_type_id, TRIM(p_question_text), p_explanation, p_correct_text, p_correct_number, p_tolerance, SYSDATE, 1);
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

    PROCEDURE grant_test_access(p_id_test NUMBER, p_uid NUMBER) IS BEGIN NULL; END;
    FUNCTION check_access(p_id_test NUMBER, p_uid NUMBER) RETURN NUMBER IS BEGIN RETURN 0; END;
    PROCEDURE start_attempt(p_id_test NUMBER, p_uid NUMBER) IS BEGIN NULL; END;
    PROCEDURE save_answer(p_id_attempt NUMBER, p_id_qt NUMBER, p_answer_text VARCHAR2, p_answer_number NUMBER, p_answer_time NUMBER) IS BEGIN NULL; END;
    PROCEDURE save_selected_option(p_id_answer NUMBER, p_id_option NUMBER) IS BEGIN NULL; END;
    FUNCTION check_answer(p_id_answer NUMBER) RETURN NUMBER IS BEGIN RETURN 0; END;
    FUNCTION calc_answer_score(p_id_answer NUMBER) RETURN NUMBER IS BEGIN RETURN 0; END;
    PROCEDURE finish_attempt(p_id_attempt NUMBER) IS BEGIN NULL; END;
    PROCEDURE calc_result(p_id_attempt NUMBER) IS BEGIN NULL; END;
    PROCEDURE show_result(p_id_attempt NUMBER) IS BEGIN NULL; END;
    PROCEDURE show_user_attempts(p_uid NUMBER) IS BEGIN NULL; END;
    PROCEDURE show_test_statistics(p_id_test NUMBER) IS BEGIN NULL; END;
END quiz_platform;
/
