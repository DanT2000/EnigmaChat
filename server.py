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
