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

