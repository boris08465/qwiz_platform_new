SET DEFINE OFF

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

@@01_create_tables.sql
@@03_sequences.sql
@@02_constraints.sql
@@06_triggers.sql
@@07_seed_reference_data.sql
@@04_package_spec.sql
@@05_package_body.sql
