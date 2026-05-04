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

    PROCEDURE grant_test_access(p_id_test NUMBER, p_uid NUMBER) IS
        v_user_cnt NUMBER;
        v_test_cnt NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_user_cnt FROM users WHERE uid = p_uid AND is_active = 1;
        IF v_user_cnt = 0 THEN
            RAISE_APPLICATION_ERROR(-20200, 'Пользователь не найден или неактивен');
        END IF;

        SELECT COUNT(*) INTO v_test_cnt FROM test WHERE id_test = p_id_test;
        IF v_test_cnt = 0 THEN
            RAISE_APPLICATION_ERROR(-20201, 'Тест не найден');
        END IF;

        MERGE INTO test_access ta
        USING (SELECT p_uid uid, p_id_test id_test FROM dual) src
        ON (ta.uid = src.uid AND ta.id_test = src.id_test)
        WHEN MATCHED THEN
            UPDATE SET ta.is_active = 1, ta.granted_at = SYSDATE
        WHEN NOT MATCHED THEN
            INSERT (uid, id_test, granted_at, is_active)
            VALUES (src.uid, src.id_test, SYSDATE, 1);
    END;

    FUNCTION check_access(p_id_test NUMBER, p_uid NUMBER) RETURN NUMBER IS
        v_cnt NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_cnt
        FROM test_access ta
        JOIN test t ON t.id_test = ta.id_test
        JOIN users u ON u.uid = ta.uid
        WHERE ta.id_test = p_id_test
          AND ta.uid = p_uid
          AND ta.is_active = 1
          AND t.is_active = 1
          AND u.is_active = 1;

        IF v_cnt > 0 THEN
            RETURN 1;
        END IF;
        RETURN 0;
    END;
    PROCEDURE start_attempt(p_id_test NUMBER, p_uid NUMBER) IS
        v_user_active NUMBER;
        v_test_active NUMBER;
        v_access NUMBER;
        v_attempt_limit NUMBER;
        v_attempts_used NUMBER;
        v_attempt_no NUMBER;
    BEGIN
        SELECT is_active INTO v_user_active FROM users WHERE uid = p_uid;
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
        WHERE uid = p_uid AND id_test = p_id_test;
        IF v_attempts_used >= v_attempt_limit THEN
            RAISE_APPLICATION_ERROR(-20303, 'Превышен лимит попыток');
        END IF;

        v_attempt_no := v_attempts_used + 1;
        INSERT INTO attempt (uid, id_test, attempt_number, start_date, status, finished_in_time)
        VALUES (p_uid, p_id_test, v_attempt_no, SYSDATE, 'STARTED', 1);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20304, 'Пользователь или тест не найден');
    END;

    PROCEDURE save_answer(
        p_id_attempt NUMBER,
        p_id_qt NUMBER,
        p_answer_text VARCHAR2,
        p_answer_number NUMBER,
        p_answer_time NUMBER
    ) IS
        v_status attempt.status%TYPE;
        v_uid attempt.uid%TYPE;
        v_test_id attempt.id_test%TYPE;
        v_started DATE;
        v_test_time_limit NUMBER;
    BEGIN
        SELECT a.status, a.uid, a.id_test, a.start_date, t.time_limit
        INTO v_status, v_uid, v_test_id, v_started, v_test_time_limit
        FROM attempt a
        JOIN test t ON t.id_test = a.id_test
        WHERE a.id_attempt = p_id_attempt;

        IF v_status <> 'STARTED' THEN
            RAISE_APPLICATION_ERROR(-20305, 'Попытка завершена');
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
        );
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
        v_type_id NUMBER;
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
        SELECT q.type_id, q.correct_text, q.correct_number, NVL(q.tolerance, 0), a.answer_text, a.answer_number
        INTO v_type_id, v_correct_text, v_correct_number, v_tolerance, v_answer_text, v_answer_number
        FROM answer a
        JOIN question_in_test qt ON qt.id_qt = a.id_qt
        JOIN question q ON q.id_question = qt.id_question
        WHERE a.id_answer = p_id_answer;

        IF v_type_id IN (1, 5) THEN
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
        ELSIF v_type_id = 2 THEN
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
        ELSIF v_type_id IN (3, 6) THEN
            IF LOWER(TRIM(NVL(v_answer_text, ''))) = LOWER(TRIM(NVL(v_correct_text, '#NULL#'))) THEN
                v_correct := 1;
            END IF;
        ELSIF v_type_id = 4 THEN
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
        v_type_id NUMBER;
        v_weight NUMBER;
        v_q_time_limit NUMBER;
        v_ans_time NUMBER;
        v_score NUMBER := 0;
        v_correct NUMBER;
        v_selected_wrong NUMBER := 0;
        v_selected_correct NUMBER := 0;
        v_total_correct NUMBER := 0;
    BEGIN
        SELECT q.type_id, qt.weight, qt.time_limit, NVL(a.answer_time, 0)
        INTO v_type_id, v_weight, v_q_time_limit, v_ans_time
        FROM answer a
        JOIN question_in_test qt ON qt.id_qt = a.id_qt
        JOIN question q ON q.id_question = qt.id_question
        WHERE a.id_answer = p_id_answer;

        IF v_q_time_limit IS NOT NULL AND v_ans_time > v_q_time_limit THEN
            v_score := 0;
            UPDATE answer SET earned_score = v_score WHERE id_answer = p_id_answer;
            RETURN v_score;
        END IF;

        v_correct := check_answer(p_id_answer);

        IF v_type_id = 2 THEN
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

    PROCEDURE finish_attempt(p_id_attempt NUMBER) IS
        v_status attempt.status%TYPE;
        v_started DATE;
        v_time_limit NUMBER;
        v_new_status VARCHAR2(30);
        v_finished_in_time NUMBER := 1;
    BEGIN
        SELECT a.status, a.start_date, t.time_limit
        INTO v_status, v_started, v_time_limit
        FROM attempt a
        JOIN test t ON t.id_test = a.id_test
        WHERE a.id_attempt = p_id_attempt;

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
          AND x.status IN ('FINISHED', 'TIME_EXPIRED')
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
            WHERE a.uid = p_uid
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
            SUM(CASE WHEN status IN ('FINISHED', 'TIME_EXPIRED') THEN 1 ELSE 0 END),
            ROUND(AVG(score), 2),
            ROUND(AVG(percent_result), 2),
            MIN(percent_result),
            MAX(percent_result)
        INTO
            v_total_attempts,
            v_finished_attempts,
            v_avg_score,
            v_avg_percent,
            v_min_percent,
            v_max_percent
        FROM attempt
        WHERE id_test = p_id_test;

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
