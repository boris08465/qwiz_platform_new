"""Database diagnostics and initial administrator setup."""
import argparse
import sys
import oracledb
from db import get_connection


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('check-db', help='Read-only connection and schema check')
    promote = commands.add_parser('make-admin', help='Make a registered user an administrator')
    promote.add_argument('user_id', type=int)
    args = parser.parse_args()
    try:
        with get_connection() as conn:
            with conn.cursor() as cur:
                if args.command == 'check-db':
                    cur.execute("SELECT object_type, status FROM user_objects WHERE object_name = 'QUIZ_PLATFORM'")
                    states = dict(cur.fetchall())
                    cur.execute("SELECT line, text FROM user_errors WHERE name = 'QUIZ_PLATFORM' ORDER BY sequence")
                    errors = cur.fetchall()
                    cur.execute("SELECT COUNT(*) FROM user_tables WHERE table_name = 'ATTEMPT_QUESTION_VISIT'")
                    has_visits = cur.fetchone()[0] == 1
                    cur.execute("SELECT COUNT(*) FROM question_type WHERE type_code IN ('TEXT', 'NUMBER', 'SINGLE_CHOICE', 'MULTIPLE_CHOICE', 'TRUE_FALSE', 'SHORT_TEXT')")
                    has_types = cur.fetchone()[0] == 6
                    cur.execute("SELECT COUNT(*) FROM role WHERE role_name IN ('USER', 'AUTHOR', 'ADMIN')")
                    has_roles = cur.fetchone()[0] == 3
                    cur.execute("SELECT COUNT(*) FROM user_procedures WHERE object_name = 'QUIZ_PLATFORM' AND procedure_name IN ('LIST_ADMIN_ATTEMPTS', 'TOUCH_QUESTION', 'SET_USER_ROLE')")
                    has_current_api = cur.fetchone()[0] == 3
                    if states.get('PACKAGE') != 'VALID' or states.get('PACKAGE BODY') != 'VALID' or errors or not has_visits or not has_types or not has_roles or not has_current_api:
                        for line, message in errors:
                            print(f'PL/SQL line {line}: {message}')
                        print('Схема требует обновления: выполните sql/10_upgrade_workflow.sql в схеме DB_USER.')
                        return 1
                    print('Подключение работает. Пакет QUIZ_PLATFORM и таблица таймеров готовы.')
                else:
                    cur.execute("UPDATE users SET id_role = (SELECT id_role FROM role WHERE role_name = 'ADMIN') WHERE user_id = :uid AND is_active = 1", uid=args.user_id)
                    if cur.rowcount != 1:
                        print('Активный пользователь с таким UID не найден.')
                        return 1
                    conn.commit()
                    print(f'Пользователь {args.user_id} теперь администратор.')
    except oracledb.Error:
        print('Не удалось подключиться к Oracle или выполнить запрос. Проверьте DB_USER, DB_PASSWORD, DB_DSN и доступ к сети.', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
