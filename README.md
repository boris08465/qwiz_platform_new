# Qwiz Platform

## Быстрый запуск

1. Создать окружение и установить зависимости:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

2. Поднять Oracle и выполнить инициализацию БД.

В DBeaver откройте `sql/00_install_all.sql` и запустите как SQL Script (`Alt+X`).

```powershell
sqlplus system/oracle@10.22.10.49:1521/ORCL
```

```sql
@sql\00_install_all.sql
```

Для простых тестовых данных после установки можно отдельно выполнить `sql/08_seed_test_data.sql` как SQL Script.

3. Задать переменные окружения (если отличаются от значений по умолчанию):

```powershell
$env:DB_USER="KE2303_07"
$env:DB_PASSWORD="KE2303_07"
$env:DB_DSN="10.22.10.49:1521/ORCL"
$env:SECRET_KEY="your-secret"
```

4. Запустить приложение:

```powershell
python app.py
```

Открыть в браузере: `http://127.0.0.1:5000`

## Главное

- Приложение не работает без Oracle Database.
- Перед первым запуском обязательно выполнить `sql/00_install_all.sql`.
- Вход: `UID + пароль` (UID показывается после регистрации).
