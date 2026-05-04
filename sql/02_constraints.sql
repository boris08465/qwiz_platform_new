CREATE INDEX idx_users_uid ON users(uid);
CREATE INDEX idx_test_access_uid_test ON test_access(uid, id_test);
CREATE INDEX idx_attempt_uid_test ON attempt(uid, id_test);
CREATE INDEX idx_answer_attempt ON answer(id_attempt);
CREATE INDEX idx_question_category_level ON question(id_category, id_level);
CREATE INDEX idx_question_in_test_test ON question_in_test(id_test);

