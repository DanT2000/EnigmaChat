#!/bin/bash

APP_DIR="/opt/EnigmaChat"
REPO_DIR="$(pwd)"
VENV_DIR="$APP_DIR/venv"
SERVICE_FILE="/etc/systemd/system/enigmachat.service"
DEFAULT_PORT=9125

function install() {
    echo "🔧 Начинается установка EnigmaChat..."

    sudo apt update
    sudo apt install -y python3 python3-venv python3-pip curl iptables-persistent

    sudo mkdir -p "$APP_DIR"
    sudo cp "$REPO_DIR/server.py" "$APP_DIR/server.py"
    sudo cp "$REPO_DIR/index.html" "$APP_DIR/index.html"
    sudo cp -r "$REPO_DIR/assets" "$APP_DIR/assets" 2>/dev/null
    sudo chown -R $USER:$USER "$APP_DIR"

    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    pip install -r "$REPO_DIR/requirements.txt"
    deactivate

    echo "⚙️ Создание systemd сервиса..."
    sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=EnigmaChat Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$APP_DIR
ExecStart=$VENV_DIR/bin/uvicorn server:app --host 0.0.0.0 --port $DEFAULT_PORT
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable enigmachat.service
    sudo systemctl restart enigmachat.service

    echo "🛡 Открытие порта $DEFAULT_PORT..."
    sudo iptables -I INPUT -p tcp --dport $DEFAULT_PORT -j ACCEPT
    sudo netfilter-persistent save

    echo "✅ Установка завершена. EnigmaChat доступен по адресу http://localhost:$DEFAULT_PORT"
}

function remove() {
    echo "❌ Удаление EnigmaChat..."

    sudo systemctl stop enigmachat.service
    sudo systemctl disable enigmachat.service
    sudo rm -f "$SERVICE_FILE"
    sudo systemctl daemon-reload

    sudo rm -rf "$APP_DIR"

    echo "🛡 Закрытие порта..."
    sudo iptables -D INPUT -p tcp --dport $DEFAULT_PORT -j ACCEPT 2>/dev/null
    sudo netfilter-persistent save

    echo "🧹 Удаление завершено."
}

clear
echo "==============================="
echo "     УСТАНОВКА EnigmaChat      "
echo "==============================="
echo "1. Установить"
echo "2. Удалить"
echo "0. Выйти"
read -p "Выберите опцию: " choice

case $choice in
    1) install ;;
    2) remove ;;
    0) exit 0 ;;
    *) echo "Неверный выбор. Пожалуйста, выберите 1, 2 или 0." ;;
esac
