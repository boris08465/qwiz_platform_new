-- DBeaver: execute this file as a script (Alt+X) on an existing database.
-- It upgrades a database created before question images and the current
-- reference-data set were added. The script is safe to run more than once.

DECLARE
    FUNCTION next_free_id(
        p_table_name IN VARCHAR2,
        p_column_name IN VARCHAR2,
        p_preferred_id IN NUMBER
    ) RETURN NUMBER IS
        v_count NUMBER;
        v_next_id NUMBER;
    BEGIN
        EXECUTE IMMEDIATE
            'SELECT COUNT(*) FROM ' || p_table_name || ' WHERE ' || p_column_name || ' = :id'
            INTO v_count
            USING p_preferred_id;

        IF v_count = 0 THEN
            RETURN p_preferred_id;
        END IF;

        EXECUTE IMMEDIATE
            'SELECT NVL(MAX(' || p_column_name || '), 0) + 1 FROM ' || p_table_name
            INTO v_next_id;

        RETURN v_next_id;
    END;

    PROCEDURE recreate_sequence(
        p_sequence_name IN VARCHAR2,
        p_table_name IN VARCHAR2,
        p_column_name IN VARCHAR2,
        p_min_start IN NUMBER
    ) IS
        v_start_with NUMBER;
    BEGIN
        EXECUTE IMMEDIATE
            'SELECT GREATEST(NVL(MAX(' || p_column_name || '), 0) + 1, :min_start) FROM ' || p_table_name
            INTO v_start_with
            USING p_min_start;

        BEGIN
            EXECUTE IMMEDIATE 'DROP SEQUENCE ' || p_sequence_name;
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLCODE != -2289 THEN
                    RAISE;
                END IF;
        END;

        EXECUTE IMMEDIATE
            'CREATE SEQUENCE ' || p_sequence_name || ' START WITH ' || v_start_with || ' INCREMENT BY 1';
    END;

    PROCEDURE ensure_role(
        p_id_role IN NUMBER,
        p_role_name IN VARCHAR2,
        p_role_description IN VARCHAR2
    ) IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM role WHERE role_name = p_role_name;

        IF v_count > 0 THEN
            UPDATE role
               SET role_description = p_role_description
             WHERE role_name = p_role_name;
        ELSE
            INSERT INTO role (id_role, role_name, role_description)
            VALUES (next_free_id('role', 'id_role', p_id_role), p_role_name, p_role_description);
        END IF;
    END;

    PROCEDURE ensure_difficulty_level(
        p_id_level IN NUMBER,
        p_level_name IN VARCHAR2
    ) IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM difficulty_level WHERE level_name = p_level_name;

        IF v_count = 0 THEN
            INSERT INTO difficulty_level (id_level, level_name)
            VALUES (next_free_id('difficulty_level', 'id_level', p_id_level), p_level_name);
        END IF;
    END;

    PROCEDURE ensure_question_type(
        p_type_id IN NUMBER,
        p_type_code IN VARCHAR2,
        p_type_name IN VARCHAR2,
        p_uses_options IN NUMBER,
        p_is_multi_select IN NUMBER,
        p_is_numeric_answer IN NUMBER,
        p_is_text_answer IN NUMBER
    ) IS
        v_count NUMBER;
        v_type_id question_type.type_id%TYPE;
        v_name_conflicts NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM question_type WHERE type_code = p_type_code;

        IF v_count > 0 THEN
            SELECT type_id INTO v_type_id FROM question_type WHERE type_code = p_type_code;
            SELECT COUNT(*)
              INTO v_name_conflicts
              FROM question_type
             WHERE type_name = p_type_name
               AND type_id <> v_type_id;

            UPDATE question_type
               SET type_name = CASE WHEN v_name_conflicts = 0 THEN p_type_name ELSE type_name END,
                   uses_options = p_uses_options,
                   is_multi_select = p_is_multi_select,
                   is_numeric_answer = p_is_numeric_answer,
                   is_text_answer = p_is_text_answer
             WHERE type_code = p_type_code;
        ELSE
            SELECT COUNT(*) INTO v_count FROM question_type WHERE type_name = p_type_name;

            IF v_count > 0 THEN
                UPDATE question_type
                   SET type_code = p_type_code,
                       uses_options = p_uses_options,
                       is_multi_select = p_is_multi_select,
                       is_numeric_answer = p_is_numeric_answer,
                       is_text_answer = p_is_text_answer
                 WHERE type_name = p_type_name;
            ELSE
                INSERT INTO question_type (
                    type_id, type_code, type_name, uses_options,
                    is_multi_select, is_numeric_answer, is_text_answer
                ) VALUES (
                    next_free_id('question_type', 'type_id', p_type_id),
                    p_type_code, p_type_name, p_uses_options,
                    p_is_multi_select, p_is_numeric_answer, p_is_text_answer
                );
            END IF;
        END IF;
    END;
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'ALTER TABLE question ADD image_path VARCHAR2(255 CHAR)';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -1430 THEN
                RAISE;
            END IF;
    END;

    ensure_role(1, 'USER', 'Обычный пользователь');
    ensure_role(2, 'AUTHOR', 'Автор тестов');
    ensure_role(3, 'ADMIN', 'Администратор');

    ensure_difficulty_level(1, 'Легкий');
    ensure_difficulty_level(2, 'Средний');
    ensure_difficulty_level(3, 'Сложный');

    ensure_question_type(1, 'SINGLE_CHOICE', 'Один правильный ответ', 1, 0, 0, 0);
    ensure_question_type(2, 'MULTIPLE_CHOICE', 'Несколько правильных ответов', 1, 1, 0, 0);
    ensure_question_type(3, 'TEXT', 'Текстовый ответ', 0, 0, 0, 1);
    ensure_question_type(4, 'NUMBER', 'Числовой ответ', 0, 0, 1, 0);
    ensure_question_type(5, 'TRUE_FALSE', 'Верно / неверно', 1, 0, 0, 0);
    ensure_question_type(6, 'SHORT_TEXT', 'Короткий ответ', 0, 0, 0, 1);

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

    recreate_sequence('seq_role', 'role', 'id_role', 4);
    recreate_sequence('seq_difficulty_level', 'difficulty_level', 'id_level', 4);
    recreate_sequence('seq_question_type', 'question_type', 'type_id', 7);

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Existing database upgraded.');
    DBMS_OUTPUT.PUT_LINE('Next step: execute sql/05_package_body.sql as a script to recompile quiz_platform.');
END;
