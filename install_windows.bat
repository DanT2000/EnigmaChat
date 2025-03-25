@echo off
echo === Установка EnigmaChat ===

REM Проверка Python
where python >nul 2>nul
if errorlevel 1 (
    echo ❌ Python не найден. Установите его с https://www.python.org/downloads/
    pause
    exit /b
)

REM Создание виртуального окружения
echo Создание виртуального окружения...
python -m venv venv

REM Активация и установка зависимостей
call venv\Scripts\activate.bat
echo Установка зависимостей...
pip install -r requirements.txt

echo ✅ Установка завершена!
echo ▶️ Запуск EnigmaChat...
uvicorn server:app --host 0.0.0.0 --port 9125
pause
