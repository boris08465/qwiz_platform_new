# Qwiz Platform

## Быстрый запуск

1. Создать окружение и установить зависимости:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

2. Поднять Oracle и выполнить инициализацию БД:

```powershell
sqlplus system/oracle@localhost:1521/XEPDB1
```

```sql
@sql\00_install_all.sql
```

3. Задать переменные окружения (если отличаются от значений по умолчанию):

```powershell
$env:DB_USER="system"
$env:DB_PASSWORD="oracle"
$env:DB_DSN="localhost:1521/XEPDB1"
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
