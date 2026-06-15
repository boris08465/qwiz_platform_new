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
