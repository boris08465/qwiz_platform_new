CREATE OR REPLACE PACKAGE quiz_platform AS
    PROCEDURE info;
    PROCEDURE register_user(p_user_name VARCHAR2, p_password VARCHAR2);
    FUNCTION login_user(p_uid NUMBER, p_password VARCHAR2) RETURN NUMBER;
    PROCEDURE create_test(p_uid_author NUMBER, p_test_name VARCHAR2, p_test_description VARCHAR2, p_id_category NUMBER, p_id_level NUMBER, p_time_limit NUMBER, p_attempt_limit NUMBER, p_show_feedback NUMBER, p_question_count NUMBER);
    PROCEDURE publish_test(p_id_test NUMBER, p_direct_call NUMBER DEFAULT 1);
    PROCEDURE generate_test_questions(p_id_test NUMBER);
    PROCEDURE add_question(p_uid_author NUMBER, p_question_text VARCHAR2, p_id_category NUMBER, p_id_level NUMBER, p_type_id NUMBER, p_correct_text VARCHAR2, p_correct_number NUMBER, p_tolerance NUMBER, p_explanation VARCHAR2);
    PROCEDURE add_answer_option(p_id_question NUMBER, p_option_text VARCHAR2, p_is_correct NUMBER);
    PROCEDURE add_question_type(p_type_name VARCHAR2);
    PROCEDURE include_question_in_test(p_id_test NUMBER, p_id_question NUMBER, p_weight NUMBER, p_order_num NUMBER, p_is_required NUMBER, p_time_limit NUMBER);
    PROCEDURE grant_test_access(p_id_test NUMBER, p_uid NUMBER);
    FUNCTION check_access(p_id_test NUMBER, p_uid NUMBER) RETURN NUMBER;
    PROCEDURE start_attempt(p_id_test NUMBER, p_uid NUMBER);
    PROCEDURE save_answer(p_id_attempt NUMBER, p_id_qt NUMBER, p_answer_text VARCHAR2, p_answer_number NUMBER, p_answer_time NUMBER);
    PROCEDURE save_selected_option(p_id_answer NUMBER, p_id_option NUMBER);
    FUNCTION check_answer(p_id_answer NUMBER) RETURN NUMBER;
    FUNCTION calc_answer_score(p_id_answer NUMBER) RETURN NUMBER;
    PROCEDURE finish_attempt(p_id_attempt NUMBER);
    PROCEDURE calc_result(p_id_attempt NUMBER);
    PROCEDURE show_result(p_id_attempt NUMBER);
    PROCEDURE show_user_attempts(p_uid NUMBER);
    PROCEDURE show_test_statistics(p_id_test NUMBER);
END quiz_platform;
/

