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
    SELECT 1 type_id, 'Один правильный ответ' type_name FROM dual UNION ALL
    SELECT 2, 'Несколько правильных ответов' FROM dual UNION ALL
    SELECT 3, 'Текстовый ответ' FROM dual UNION ALL
    SELECT 4, 'Числовой ответ' FROM dual UNION ALL
    SELECT 5, 'Верно / неверно' FROM dual UNION ALL
    SELECT 6, 'Короткий ответ' FROM dual
) src
ON (qt.type_id = src.type_id)
WHEN MATCHED THEN UPDATE SET qt.type_name = src.type_name
WHEN NOT MATCHED THEN INSERT (type_id, type_name) VALUES (src.type_id, src.type_name);

COMMIT;
