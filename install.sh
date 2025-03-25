#!/bin/bash

APP_DIR="/opt/EnigmaChat"
VENV_DIR="$APP_DIR/venv"
SERVICE_FILE="/etc/systemd/system/EnigmaChat.service"
DEFAULT_PORT=9125

function prompt_for_port() {
    read -p "Введите порт для EnigmaChat (нажмите Enter для использования порта по умолчанию $DEFAULT_PORT): " PORT
    PORT=${PORT:-$DEFAULT_PORT}
}

function install() {
    echo "🔧 Начинается установка EnigmaChat..."

    prompt_for_port

    # Установка необходимых пакетов
    sudo apt update
    sudo apt install -y python3 python3-venv python3-pip curl iptables-persistent

    # Создание каталога приложения
    sudo mkdir -p "$APP_DIR"
    sudo chown $USER:$USER "$APP_DIR"

    # Создание шаблона server.py
    if [ ! -f "$APP_DIR/server.py" ]; then
        cat > "$APP_DIR/server.py" <<EOF
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.responses import HTMLResponse
import asyncio
import os
import json
import datetime

app = FastAPI()

# Хранилище диалогов в памяти.
# Формат: chats[chat_name] = {"password": str или None, "messages": list, "connections": list, "last_active": datetime}
chats = {}

# Убедимся, что папка для файлов существует
os.makedirs("data", exist_ok=True)

@app.websocket("/ws/{chat_name}")
async def websocket_chat(websocket: WebSocket, chat_name: str):
    # Принимаем подключение WebSocket
    await websocket.accept()
    chat = None
    authenticated = True  # Флаг, обозначающий пройдена ли авторизация для чата
    file_path = f"data/{chat_name}.json"
    # Загрузка существующего чата или инициализация нового
    if chat_name in chats:
        chat = chats[chat_name]
        if chat["password"] is not None:
            # Чат с паролем: требуется авторизация
            authenticated = False
        else:
            authenticated = True
            # Если у чата нет пароля и уже есть подключившийся пользователь (чат в процессе создания)
            if len(chat["connections"]) > 0:
                # Отклоняем второе подключение, пока чат не настроен
                await websocket.close()
                return
    else:
        if os.path.exists(file_path):
            # Загружаем существующий чат с диска
            try:
                with open(file_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
            except json.JSONDecodeError:
                data = {"name": chat_name, "password": None, "messages": []}
            chats[chat_name] = {
                "password": data.get("password"),
                "messages": data.get("messages", []),
                "connections": [],
                "last_active": None
            }
            # Устанавливаем last_active по отметке времени последнего сообщения или времени изменения файла
            if chats[chat_name]["messages"]:
                last_ts = chats[chat_name]["messages"][-1].get("timestamp")
                try:
                    last_dt = datetime.datetime.fromisoformat(last_ts) if last_ts else datetime.datetime.utcnow()
                except Exception:
                    last_dt = datetime.datetime.utcnow()
                chats[chat_name]["last_active"] = last_dt
            else:
                # Если сообщений нет, берём время изменения файла (время создания чата)
                try:
                    mtime = os.path.getmtime(file_path)
                    chats[chat_name]["last_active"] = datetime.datetime.fromtimestamp(mtime)
                except:
                    chats[chat_name]["last_active"] = datetime.datetime.utcnow()
            chat = chats[chat_name]
            if chat["password"] is not None:
                authenticated = False
            else:
                authenticated = True
        else:
            # Создаём новый чат (пока только в памяти, файл создадим при сохранении пароля)
            chats[chat_name] = {
                "password": None,
                "messages": [],
                "connections": [],
                "last_active": datetime.datetime.utcnow()
            }
            chat = chats[chat_name]
            authenticated = True
    # Регистрируем новое соединение в списке
    chat["connections"].append(websocket)
    # Отправляем начальные инструкции или запрос пароля
    if chat["password"] is None:
        # Новый чат создан
        await websocket.send_json({
            "type": "info",
            "message": "Чат создан. Первое отправленное сообщение станет паролем для входа."
        })
    elif not authenticated:
        # Существующий чат, запрашиваем пароль
        await websocket.send_json({"type": "auth_required"})
    # Ожидаем сообщения от клиента
    try:
        while True:
            data = await websocket.receive_text()
            # Парсим входящие данные (JSON)
            try:
                msg = json.loads(data)
            except json.JSONDecodeError:
                msg = {"text": data}
            # Обработка авторизации, если требуется
            if not authenticated:
                # Ожидаем попытку пароля
                attempted_pass = msg.get("text", "")
                if attempted_pass == chat["password"]:
                    # Пароль верный
                    authenticated = True
                    # Обновляем отметку активности (успешное подключение - тоже активность)
                    chat["last_active"] = datetime.datetime.utcnow()
                    # Отправляем историю сообщений новому участнику
                    if chat["messages"]:
                        for old_msg in chat["messages"]:
                            await websocket.send_json(old_msg)
                    else:
                        await websocket.send_json({
                            "type": "info",
                            "message": "Пароль принят. Сообщений в чате пока нет."
                        })
                    continue
                else:
                    # Пароль неверный - закрываем соединение
                    await websocket.close()
                    break
            else:
                # Авторизованный пользователь отправил сообщение
                name = msg.get("name", "")
                if not name:
                    name = "Аноним"
                text = msg.get("text", "")
                iv = msg.get("iv", None)
                if chat["password"] is None:
                    # Если у чата ещё нет пароля, то первое сообщение устанавливает пароль
                    chat["password"] = text
                    # Обновляем время активности
                    chat["last_active"] = datetime.datetime.utcnow()
                    # Сохраняем чат в файл с новым паролем
                    chat_data = {
                        "name": chat_name,
                        "password": chat["password"],
                        "messages": []
                    }
                    with open(file_path, "w", encoding="utf-8") as f:
                        json.dump(chat_data, f, ensure_ascii=False)
                    # Уведомляем создателя, что пароль установлен
                    await websocket.send_json({
                        "type": "info",
                        "message": f"Пароль для чата установлен: {chat['password']}"
                    })
                    continue
                # Обычная обработка сообщения
                timestamp = datetime.datetime.utcnow().isoformat()
                message_entry = {"name": name, "text": text, "timestamp": timestamp}
                if iv:
                    message_entry["iv"] = iv
                # Сохраняем сообщение в истории
                chat["messages"].append(message_entry)
                chat["last_active"] = datetime.datetime.utcnow()
                # Обновляем файл чата на диске
                chat_data = {
                    "name": chat_name,
                    "password": chat["password"],
                    "messages": chat["messages"]
                }
                with open(file_path, "w", encoding="utf-8") as f:
                    json.dump(chat_data, f, ensure_ascii=False)
                # Рассылаем сообщение всем подключенным клиентам чата
                for conn in chat["connections"]:
                    await conn.send_json(message_entry)
    except WebSocketDisconnect:
        # Клиент отключился
        chat["connections"].remove(websocket)
        # Ничего не делаем сразу (очистка выполняется в фоновом задании)
        return

@app.post("/delete/{chat_name}")
async def delete_chat(chat_name: str):
    # Удаление диалога вручную
    if chat_name in chats:
        # Отключаем всех клиентов в данном чате
        for conn in list(chats[chat_name]["connections"]):
            await conn.close()
        # Удаляем информацию о чате из памяти
        chats.pop(chat_name, None)
    # Удаляем файл чата с диска, если есть
    file_path = f"data/{chat_name}.json"
    if os.path.exists(file_path):
        try:
            os.remove(file_path)
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Ошибка удаления файла: {e}")
    return {"detail": "Чат удалён"}

# Фоновая задача для удаления неактивных чатов
async def cleanup_chats():
    while True:
        await asyncio.sleep(60)
        now = datetime.datetime.utcnow()
        to_delete = []
        for name, chat in list(chats.items()):
            if chat["last_active"] is None:
                continue
            elapsed = (now - chat["last_active"]).total_seconds()
            if elapsed > 30 * 60 and len(chat["connections"]) == 0:
                to_delete.append(name)
        for name in to_delete:
            # Закрываем возможные оставшиеся соединения (если вдруг осталось)
            if name in chats:
                for conn in list(chats[name]["connections"]):
                    try:
                        await conn.close()
                    except:
                        pass
                chats.pop(name, None)
            file_path = f"data/{name}.json"
            if os.path.exists(file_path):
                try:
                    os.remove(file_path)
                except:
                    pass

@app.on_event("startup")
async def on_startup():
    os.makedirs("data", exist_ok=True)
    # Запускаем фоновую задачу очистки неактивных чатов
    asyncio.create_task(cleanup_chats())

# Отдаем клиенту HTML-страницу
@app.get("/", response_class=HTMLResponse)
async def index():
    try:
        with open("index.html", "r", encoding="utf-8") as f:
            return HTMLResponse(f.read(), status_code=200)
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail="index.html not found")

EOF
        echo "📄 Файл server.py создан как шаблон."
    else
        echo "✅ Файл server.py уже существует, пропускаем создание."
    fi

    # Создание шаблона index.html
    if [ ! -f "$APP_DIR/index.html" ]; then
        cat > "$APP_DIR/index.html" <<EOF
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Простой чат</title>
    <style>
        body {
            background: #1e1e1e;
            color: #ddd;
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 0;
        }
        #join-screen {
            height: 100vh;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
        }
        #join-screen input {
            width: 200px;
            padding: 8px;
            margin: 5px;
            border: none;
            border-radius: 4px;
        }
        #join-screen button {
            padding: 8px 16px;
            margin: 5px;
            border: none;
            border-radius: 4px;
            background: #3a3a3a;
            color: #fff;
            cursor: pointer;
            font-size: 1em;
        }
        #join-screen button:hover {
            background: #4a4a4a;
        }
        #chat-screen {
            display: none;
            height: 100vh;
            max-height: 100vh;
            overflow: hidden;
            display: flex;
            flex-direction: column;
        }
        #chat-header {
            position: relative;
            padding: 10px;
            background: #2a2a2a;
        }
        #chat-header h2 {
            margin: 0;
            font-size: 1.2em;
        }
        #chat-controls {
            position: absolute;
            top: 10px;
            right: 10px;
        }
        #chat-controls button {
            background: none;
            border: none;
            color: #ddd;
            font-size: 1.2em;
            cursor: pointer;
            margin-left: 5px;
        }
        #chat-controls button:hover {
            color: #fff;
        }
        #messages {
            flex: 1;
            padding: 10px;
            overflow-y: auto;
            display: flex;
            flex-direction: column;
        }
        .message {
            max-width: 70%;
            padding: 6px 10px;
            margin: 5px 0;
            border-radius: 5px;
            word-wrap: break-word;
        }
        .message.self {
            align-self: flex-end;
            background: #4e4e4e;
        }
        .message.other {
            align-self: flex-start;
            background: #3a3a3a;
        }
        .message .name {
            font-weight: bold;
            margin-right: 5px;
        }
        .info-message {
            text-align: center;
            color: #999;
            font-style: italic;
            margin: 5px 0;
        }
        #messageForm {
            display: flex;
            padding: 10px;
            background: #2a2a2a;
        }
        #messageInput {
            flex: 1;
            padding: 8px;
            border: none;
            border-radius: 4px;
            margin-right: 5px;
        }
        #messageForm button {
            padding: 8px 16px;
            border: none;
            border-radius: 4px;
            background: #3a3a3a;
            color: #fff;
            cursor: pointer;
        }
        #messageForm button:hover {
            background: #4a4a4a;
        }
        .modal {
            display: none;
            position: fixed;
            top: 0; left: 0;
            width: 100%; height: 100%;
            background: rgba(0,0,0,0.5);
            justify-content: center;
            align-items: center;
        }
        .modal-content {
            background: #2e2e2e;
            padding: 20px;
            border-radius: 5px;
            text-align: center;
            color: #fff;
            width: 80%;
            max-width: 300px;
        }
        .modal-content input {
            width: 80%;
            padding: 8px;
            margin: 10px 0;
            border: none;
            border-radius: 4px;
        }
        .modal-content button {
            padding: 6px 12px;
            margin: 5px;
            border: none;
            border-radius: 4px;
            background: #4a4a4a;
            color: #fff;
            cursor: pointer;
        }
        .modal-content button:hover {
            background: #5a5a5a;
        }
        .error {
            color: #ff5555;
        }
    </style>
</head>
<body>
    <div id="join-screen">
        <h1>Добро пожаловать</h1>
        <input type="text" id="chatNameInput" placeholder="Название чата" />
        <div id="passwordDiv" style="display:none;">
            <input type="password" id="passwordInput" placeholder="Пароль" />
        </div>
        <button id="connectBtn">Подключиться</button>
        <p id="errorMsg" class="error"></p>
    </div>
    <div id="chat-screen">
        <div id="chat-header">
            <h2 id="chatTitle"></h2>
            <div id="chat-controls">
                <button id="encBtn" title="Ввести ключ шифрования">🔐</button>
                <button id="nameBtn" title="Установить имя пользователя">🧑‍💻</button>
                <button id="delBtn" title="Удалить чат">🗑</button>
            </div>
        </div>
        <div id="messages"></div>
        <form id="messageForm">
            <input type="text" id="messageInput" placeholder="Введите сообщение..." autocomplete="off" />
            <button type="submit">Отправить</button>
        </form>
    </div>
    <!-- Modal для ввода ключа шифрования -->
    <div id="modal-key" class="modal">
        <div class="modal-content">
            <h3>Введите ключ шифрования</h3>
            <input type="text" id="keyInput" placeholder="Ключ" />
            <br/>
            <button id="keyConfirmBtn">OK</button>
            <button id="keyCancelBtn">Отмена</button>
        </div>
    </div>
    <!-- Modal для ввода имени -->
    <div id="modal-name" class="modal">
        <div class="modal-content">
            <h3>Введите имя пользователя</h3>
            <input type="text" id="nameInputModal" placeholder="Ваше имя" />
            <br/>
            <button id="nameConfirmBtn">OK</button>
            <button id="nameCancelBtn">Отмена</button>
        </div>
    </div>
    <script>
        // Глобальные переменные
        let ws;
        let chatName = "";
        let userName = "";
        let encryptionKey = null;
        let connected = false;
        let waitingForAuth = false;
        const messages = [];

        // Элементы DOM
        const joinScreen = document.getElementById('join-screen');
        const chatScreen = document.getElementById('chat-screen');
        const chatTitle = document.getElementById('chatTitle');
        const chatNameInput = document.getElementById('chatNameInput');
        const passwordDiv = document.getElementById('passwordDiv');
        const passwordInput = document.getElementById('passwordInput');
        const connectBtn = document.getElementById('connectBtn');
        const errorMsg = document.getElementById('errorMsg');
        const messagesDiv = document.getElementById('messages');
        const messageForm = document.getElementById('messageForm');
        const messageInput = document.getElementById('messageInput');
        const encBtn = document.getElementById('encBtn');
        const nameBtn = document.getElementById('nameBtn');
        const delBtn = document.getElementById('delBtn');
        const modalKey = document.getElementById('modal-key');
        const keyInput = document.getElementById('keyInput');
        const keyConfirmBtn = document.getElementById('keyConfirmBtn');
        const keyCancelBtn = document.getElementById('keyCancelBtn');
        const modalName = document.getElementById('modal-name');
        const nameInputModal = document.getElementById('nameInputModal');
        const nameConfirmBtn = document.getElementById('nameConfirmBtn');
        const nameCancelBtn = document.getElementById('nameCancelBtn');

        // Утилиты: функции для кодирования/декодирования Base64 (ArrayBuffer <-> Base64)
        function arrayBufferToBase64(buffer) {
            let binary = '';
            const bytes = new Uint8Array(buffer);
            for (let i = 0; i < bytes.length; i++) {
                binary += String.fromCharCode(bytes[i]);
            }
            return btoa(binary);
        }
        function base64ToArrayBuffer(base64) {
            const binary = atob(base64);
            const bytes = new Uint8Array(binary.length);
            for (let i = 0; i < binary.length; i++) {
                bytes[i] = binary.charCodeAt(i);
            }
            return bytes.buffer;
        }

        // Добавление сообщения или инфо в область чата
        function addMessageToDisplay(msg) {
            if (msg.type === 'info') {
                // Системное информационное сообщение
                const infoElem = document.createElement('div');
                infoElem.className = 'info-message';
                infoElem.textContent = msg.message;
                messagesDiv.appendChild(infoElem);
            } else {
                // Обычное сообщение чата
                const nameToShow = msg.name ? msg.name : 'Аноним';
                const messageElem = document.createElement('div');
                // Определяем, является ли сообщение отправленным текущим пользователем
                let alignClass = 'other';
                if (userName && msg.name === userName) {
                    alignClass = 'self';
                } 
                // Если userName не установлен (аноним), все "Аноним" будут считаться как чужие для выравнивания
                messageElem.className = 'message ' + alignClass;
                if (alignClass === 'other') {
                    // Отображаем имя отправителя для чужих сообщений
                    const nameSpan = document.createElement('span');
                    nameSpan.className = 'name';
                    nameSpan.textContent = nameToShow + ': ';
                    messageElem.appendChild(nameSpan);
                }
                const textSpan = document.createElement('span');
                textSpan.className = 'text';
                // Проверяем, зашифровано ли сообщение
                if (msg.iv) {
                    const cipherText = msg.text;
                    textSpan.textContent = cipherText;
                    if (encryptionKey) {
                        // Пытаемся расшифровать с помощью ключа
                        const ivBuffer = base64ToArrayBuffer(msg.iv);
                        const cipherBuffer = base64ToArrayBuffer(cipherText);
                        crypto.subtle.decrypt({name: "AES-GCM", iv: ivBuffer}, encryptionKey, cipherBuffer)
                            .then(decryptedBuffer => {
                                const decoder = new TextDecoder();
                                const plainText = decoder.decode(decryptedBuffer);
                                textSpan.textContent = plainText;
                            })
                            .catch(err => {
                                // Если расшифровка не удалась (неверный ключ), оставляем шифротекст
                                console.error("Decryption error:", err);
                                textSpan.textContent = cipherText;
                            });
                    }
                } else {
                    // Обычный текст сообщения
                    textSpan.textContent = msg.text;
                }
                messageElem.appendChild(textSpan);
                messagesDiv.appendChild(messageElem);
            }
            // Прокручиваем область сообщений вниз к последнему сообщению
            messagesDiv.scrollTop = messagesDiv.scrollHeight;
        }

        // Показать окно чата, скрыть экран входа
        function enterChat() {
            joinScreen.style.display = 'none';
            chatScreen.style.display = 'flex';
            chatTitle.textContent = 'Чат: ' + chatName;
            messageInput.focus();
        }

        // Сброс интерфейса к начальному состоянию (возврат на экран входа)
        function resetUI() {
            if (ws) {
                ws.close();
            }
            connected = false;
            waitingForAuth = false;
            messages.length = 0;
            messagesDiv.innerHTML = '';
            encryptionKey = null;
            userName = '';
            // Показать экран входа, скрыть чат
            chatScreen.style.display = 'none';
            joinScreen.style.display = 'flex';
            passwordDiv.style.display = 'none';
            chatNameInput.value = '';
            passwordInput.value = '';
            connectBtn.textContent = 'Подключиться';
            errorMsg.textContent = '';
        }

        // Обработчик кнопки "Подключиться"
        connectBtn.addEventListener('click', function() {
            if (!waitingForAuth) {
                // Первая попытка подключения к чату
                chatName = chatNameInput.value.trim();
                if (!chatName) {
                    errorMsg.textContent = 'Введите название чата';
                    return;
                }
                errorMsg.textContent = '';
                // Открываем WebSocket соединение к серверу
                const loc = window.location;
                const wsProtocol = loc.protocol === 'https:' ? 'wss:' : 'ws:';
                const wsUrl = wsProtocol + '//' + loc.host + '/ws/' + encodeURIComponent(chatName);
                ws = new WebSocket(wsUrl);
                ws.onopen = function() {
                    // соединение установлено
                };
                ws.onmessage = function(event) {
                    const data = JSON.parse(event.data);
                    if (data.type === 'auth_required') {
                        // Чат защищён паролем – требуется ввод
                        waitingForAuth = true;
                        passwordDiv.style.display = 'block';
                        passwordInput.focus();
                        connectBtn.textContent = 'Войти';
                    } else if (data.type === 'info') {
                        // Информационное сообщение от сервера
                        if (!connected) {
                            // Если ещё не переключились в чат, делаем это сейчас
                            connected = true;
                            enterChat();
                        }
                        messages.push(data);
                        addMessageToDisplay(data);
                    } else {
                        // Обычное сообщение (история или новое)
                        if (!connected) {
                            connected = true;
                            enterChat();
                        }
                        messages.push(data);
                        addMessageToDisplay(data);
                    }
                };
                ws.onclose = function(event) {
                    if (waitingForAuth && !connected) {
                        // Отключение во время ожидания пароля -> неверный пароль
                        errorMsg.textContent = 'Неверный пароль';
                        connectBtn.textContent = 'Подключиться';
                        waitingForAuth = false;
                        // Оставляем экран входа для повторной попытки (поле пароля уже отображается)
                    } else if (connected) {
                        // Если соединение было установлено и затем закрыто (вероятно, чат удалён)
                        alert('Соединение закрыто. Возможно, чат был удалён.');
                        resetUI();
                    }
                };
            } else {
                // Отправка пароля для авторизации
                const pass = passwordInput.value;
                if (!pass) {
                    errorMsg.textContent = 'Введите пароль';
                    return;
                }
                errorMsg.textContent = '';
                // Отправляем введённый пароль на сервер
                if (ws && ws.readyState === WebSocket.OPEN) {
                    ws.send(JSON.stringify({ text: pass }));
                }
                // После отправки ждём onmessage или onclose (успех или ошибка авторизации)
            }
        });

        // Отправка нового сообщения
        messageForm.addEventListener('submit', function(event) {
            event.preventDefault();
            const text = messageInput.value;
            if (!text) return;
            if (!ws || ws.readyState !== WebSocket.OPEN) return;
            const messageToSend = { name: userName, text: text };
            if (encryptionKey) {
                // Шифруем сообщение с помощью AES-GCM
                const iv = window.crypto.getRandomValues(new Uint8Array(12));
                const encoder = new TextEncoder();
                const textBuffer = encoder.encode(text);
                crypto.subtle.encrypt({name: "AES-GCM", iv: iv}, encryptionKey, textBuffer)
                    .then(encryptedBuffer => {
                        const cipherText = arrayBufferToBase64(encryptedBuffer);
                        const ivBase64 = arrayBufferToBase64(iv.buffer);
                        const sendData = { name: userName, text: cipherText, iv: ivBase64 };
                        ws.send(JSON.stringify(sendData));
                    })
                    .catch(err => {
                        console.error("Encryption error:", err);
                        // Если шифрование не удалось, отправляем как есть
                        ws.send(JSON.stringify(messageToSend));
                    });
            } else {
                // Отправляем обычный текст
                ws.send(JSON.stringify(messageToSend));
            }
            messageInput.value = '';
        });

        // Открытие модального окна ввода ключа шифрования (иконка 🔐)
        encBtn.addEventListener('click', function() {
            keyInput.value = '';
            modalKey.style.display = 'flex';
            keyInput.focus();
        });
        keyCancelBtn.addEventListener('click', function() {
            modalKey.style.display = 'none';
        });
        keyConfirmBtn.addEventListener('click', function() {
            const passphrase = keyInput.value;
            modalKey.style.display = 'none';
            if (passphrase === '') {
                // Очистить ключ (отключить шифрование)
                encryptionKey = null;
                // Перерисовать сообщения, вернув отображение шифротекста для зашифрованных
                messagesDiv.innerHTML = '';
                for (const msg of messages) {
                    addMessageToDisplay(msg);
                }
                return;
            }
            // Производим вывод ключа AES-GCM из парольной фразы (PBKDF2)
            const enc = new TextEncoder();
            const salt = enc.encode(chatName); // используем имя чата как соль
            window.crypto.subtle.importKey(
                'raw', enc.encode(passphrase), { name: 'PBKDF2' }, false, ['deriveKey']
            ).then(keyMaterial => {
                return window.crypto.subtle.deriveKey(
                    { name: 'PBKDF2', salt: salt, iterations: 100000, hash: 'SHA-256' },
                    keyMaterial,
                    { name: 'AES-GCM', length: 256 },
                    false,
                    ['encrypt', 'decrypt']
                );
            }).then(derivedKey => {
                encryptionKey = derivedKey;
                // Перерисовываем все сообщения: пытаемся расшифровать те, что были зашифрованы
                messagesDiv.innerHTML = '';
                for (const msg of messages) {
                    addMessageToDisplay(msg);
                }
            }).catch(err => {
                console.error("Key derivation error:", err);
                encryptionKey = null;
            });
        });

        // Открытие модального окна ввода имени (иконка 🧑‍💻)
        nameBtn.addEventListener('click', function() {
            nameInputModal.value = '';
            modalName.style.display = 'flex';
            nameInputModal.focus();
        });
        nameCancelBtn.addEventListener('click', function() {
            modalName.style.display = 'none';
        });
        nameConfirmBtn.addEventListener('click', function() {
            const newName = nameInputModal.value.trim();
            modalName.style.display = 'none';
            if (newName === "") {
                userName = "";
            } else {
                userName = newName;
            }
            // Локально отображаем системное сообщение об изменении имени
            const infoMsg = { type: 'info', message: (userName ? 'Имя изменено: ' + userName : 'Имя сброшено (аноним)') };
            messages.push(infoMsg);
            addMessageToDisplay(infoMsg);
        });

        // Удаление чата (иконка 🗑)
        delBtn.addEventListener('click', function() {
            if (!chatName) return;
            if (confirm("Удалить чат \"" + chatName + "\"?")) {
                fetch("/delete/" + encodeURIComponent(chatName), { method: 'POST' })
                    .catch(err => console.error("Delete request error:", err));
                // Сервер самостоятельно закроет соединение и удалит чат, вызвав onclose
            }
        });
    </script>
</body>
</html>

EOF
        echo "📄 Файл index.html создан как шаблон."
    else
        echo "✅ Файл index.html уже существует, пропускаем создание."
    fi

    # Создание виртуального окружения и установка зависимостей
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    pip install fastapi uvicorn
    deactivate

    # Создание systemd сервиса
    echo "⚙️ Создание systemd сервиса EnigmaChat..."
    sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=EnigmaChat Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$APP_DIR
ExecStart=$VENV_DIR/bin/uvicorn server:app --host 0.0.0.0 --port $PORT
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    # Перезагрузка systemd и запуск сервиса
    sudo systemctl daemon-reload
    sudo systemctl enable EnigmaChat.service
    sudo systemctl restart EnigmaChat.service

    # Настройка брандмауэра для открытия выбранного порта
    echo "🛡 Открытие порта $PORT в брандмауэре..."
    sudo iptables -I INPUT -p tcp --dport $PORT -j ACCEPT
    sudo netfilter-persistent save

    echo "✅ Установка завершена. EnigmaChat работает на порту $PORT."
    echo "👉 Откройте в браузере: http://<IP-адрес>:$PORT"
    echo "✍️ Не забудьте добавить ваш код в файлы:"
    echo "    $APP_DIR/server.py"
    echo "    $APP_DIR/index.html"
}

function remove() {
    echo "❌ Начинается удаление EnigmaChat..."

    # Остановка и удаление сервиса
    sudo systemctl stop EnigmaChat.service
    sudo systemctl disable EnigmaChat.service
    sudo rm -f "$SERVICE_FILE"
    sudo systemctl daemon-reload

    # Удаление каталога приложения
    sudo rm -rf "$APP_DIR"

    # Закрытие порта в брандмауэре
    echo "🛡 Закрытие порта в брандмауэре..."
    sudo iptables -D INPUT -p tcp --dport $PORT -j ACCEPT 2>/dev/null
    sudo netfilter-persistent save

    echo "🧹 Удаление завершено."
}

# Главное меню
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
