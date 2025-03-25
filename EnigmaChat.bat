@echo off
setlocal EnableDelayedExpansion

echo ================================
echo        EnigmaChat Launcher
echo ================================

REM Проверка Python
where python >nul 2>nul
if errorlevel 1 (
    echo ❌ Python не найден. Установите Python с https://www.python.org/downloads/
    pause
    exit /b
)

REM Проверка virtualenv
if not exist venv (
    echo 🛠 Создание виртуального окружения...
    python -m venv venv
)

REM Активация окружения
call venv\Scripts\activate.bat

REM Проверка зависимостей (fastapi и uvicorn)
pip show fastapi >nul 2>nul
if errorlevel 1 (
    echo 📦 Установка зависимостей...
    pip install -r requirements.txt
)

REM Спросить порт
set /p PORT=Введите порт для запуска (Enter для 9125): 
if "%PORT%"=="" set PORT=9125

REM Запуск сервера
echo 🚀 Запуск EnigmaChat на порту %PORT%...
start http://localhost:%PORT%
uvicorn server:app --port %PORT%

pause
