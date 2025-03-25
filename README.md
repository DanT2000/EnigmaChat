<p align="center">
  <img src="assets/logo.png" alt="EnigmaChat Logo" width="150"/>
</p>

## 🔀 Навигация
- [🇷🇺 Русская версия](#russian-version)
- [🇬🇧 English Version](#english-version)

## 🕵️ EnigmaChat — Anonymous Encrypted Chat

**EnigmaChat** is a local, secure chat without registration or cloud storage.  
Chats are created and disappear automatically. The first message sets the password — all others are encrypted.  
Supports **custom encryption keys**, **chat deletion**, **offline usage**, and **automatic cleanup of inactive sessions**.

---

**EnigmaChat** — это локальный, защищённый чат без регистрации и хранения данных в облаке.  
Чаты создаются и исчезают автоматически. Первое сообщение задаёт пароль, остальные шифруются.  
Поддерживает **ввод ключа шифрования**, **удаление чата**, **работу без интернета** и **автозавершение неактивных сессий**.

---
<a name="russian-version"></a>
## 🇷🇺 Русская версия

## 🛠️ Установка EnigmaChat на Ubuntu

1. Откройте терминал и клонируйте репозиторий:

   ```bash
   git clone https://github.com/DanT2000/EnigmaChat.git
   ```

2. Перейдите в папку проекта:

   ```bash
   cd EnigmaChat
   ```

3. Запустите установочный скрипт:

   ```bash
   chmod +x install_ubuntu.sh
   ```
    ```bash
   ./install_ubuntu.sh
   ```

Начнётся автоматическая установка зависимостей и запуск сервера.

✅ Готово!
Чат доступен по адресу http://localhost:9125

Если вы хотите изменить порт, сделайте это в файле server.py и убедитесь, что порт открыт в системе и в файле сервиса.
---

## 🧹 Удаление

Если вы захотите удалить EnigmaChat, просто снова выполните скрипт:

```bash
./install_ubuntu.sh
```

И выберите пункт **Удалить чат** — скрипт сам всё почистит.


---

## 🛠️ Установка EnigmaChat на Windows

У вас есть **два варианта** запуска EnigmaChat:

---

### ✅ Вариант 1: Просто запустить `.exe` (рекомендуется)

1. Скачайте готовый файл `EnigmaChat.exe`.
2. Дважды кликните по нему.
3. Чат сам откроется в браузере.

**Преимущества:**
- Не требует установки Python.
- Все библиотеки уже встроены.
- Запускается одним кликом.
- Работает даже без интернета.

---

### ⚙️ Вариант 2: Использовать `EnigmaChat.bat`

Если вы хотите запустить через исходный код:

1. Убедитесь, что у вас установлен Python 3.10+.
2. Скачайте проект с GitHub:

   ```bash
   git clone https://github.com/DanT2000/EnigmaChat.git
   ```

3. Перейдите в папку проекта и запустите файл `EnigmaChat.bat`.  
   Он сам установит необходимые зависимости и предложит выбрать порт.

**Преимущества:**
- Позволяет легко вносить изменения в код.
- Подходит для разработчиков и энтузиастов.

---


## 🔐 Логика работы EnigmaChat

После запуска сайта вы увидите **простое окно с полем ввода** — сюда нужно ввести **название чата**.

- 📥 **Если чат с таким названием уже существует** — система попросит ввести **пароль для доступа**.
- 🆕 **Если чата не существует** — он будет создан автоматически. В этом случае **первое сообщение**, которое вы отправите, станет **паролем доступа к чату** (в будущем он понадобится, чтобы зайти в него снова).

---

### 💬 Интерфейс чата

После входа вы попадёте в сам чат, где в правом верхнем углу расположены **три кнопки**:

1. 🔐 **Кнопка с замочком** — отвечает за **ключ шифрования**.  
   Введите секретную фразу, которая будет использоваться для **шифрования и расшифровки** всех сообщений.  
   > Обратите внимание: **ключ не обязателен для работы**, но если вы хотите приватности — договоритесь о нём заранее с собеседником.

2. 🧑‍💻 **Кнопка с человеком за ноутбуком** — позволяет **изменить ваше имя**.  
   По умолчанию вы отображаетесь как **Аноним**, но можно установить любое имя, и оно будет прикреплено к каждому вашему сообщению.

3. 🗑 **Кнопка с корзиной** — **удаляет чат** вручную.  
   Если вы не удалите его сами, чат будет автоматически удалён спустя определённое время **неактивности**.

---

🧠 Всё просто и минималистично: вы создаёте или заходите в чат, общаетесь, при желании шифруете сообщения, и всё это — без регистрации и лишних сложностей.
<a name="english-version"></a>
## 🇬🇧 English Version

## 🛠️ Installing EnigmaChat on Ubuntu

1. Open a terminal and clone the repository:

   ```bash
   git clone https://github.com/DanT2000/EnigmaChat.git
   ```

2. Navigate to the project folder:

   ```bash
   cd EnigmaChat
   ```

3. Run the installation script:

   ```bash
   chmod +x install_ubuntu.sh
   ```
   ```bash
   ./install_ubuntu.sh
   ```

The script will automatically install all dependencies and launch the server.

✅ Done!
The chat is available at http://localhost:9125

If you want to change the port, edit it in server.py and make sure it's open in your system and service file.

---

## 🧹 Uninstallation

If you want to uninstall EnigmaChat, simply run the script again:

```bash
./install_ubuntu.sh
```

And choose the **Delete Chat** option — the script will handle the cleanup for you.

---

## 🛠️ Installing EnigmaChat on Windows

There are **two ways** to run EnigmaChat on Windows:

---

### ✅ Option 1: Just launch the `.exe` (recommended)

1. Download the prebuilt `EnigmaChat.exe`.
2. Double-click to run it.
3. The chat will open in your browser automatically.

**Advantages:**
- No need to install Python.
- All libraries are bundled.
- Starts with a single click.
- Works offline.

---

### ⚙️ Option 2: Use `EnigmaChat.bat`

If you'd prefer to run from source:

1. Make sure Python 3.10+ is installed.
2. Clone the project from GitHub:

   ```bash
   git clone https://github.com/DanT2000/EnigmaChat.git
   ```

3. Go to the project folder and run `EnigmaChat.bat`.  
   It will install all dependencies and let you choose a port.

**Advantages:**
- Easy to modify and customize.
- Ideal for developers and tinkerers.

---

## 🔐 EnigmaChat Logic

Once the site loads, you'll see a **simple input field** — enter the **chat name** there.

- 📥 **If a chat with that name already exists**, you'll be asked to enter the **access password**.
- 🆕 **If the chat doesn't exist**, it will be created automatically. The **first message** you send will become the **password for that chat** (you’ll need it next time to access it).

---

### 💬 Chat Interface

After entering, you'll see the chat window with **three buttons in the top right corner**:

1. 🔐 **Lock icon** — manages the **encryption key**.  
   Enter a shared passphrase to **encrypt and decrypt** all messages.  
   > Note: **Encryption is optional**, but if you want privacy, agree on a shared key with your partner.

2. 🧑‍💻 **User icon** — lets you **set your name**.  
   By default, you appear as **Anonymous**, but you can set any name which will be shown with your messages.

3. 🗑 **Trash icon** — **deletes the chat manually**.  
   If you don’t delete it, the chat will be **automatically removed** after a period of inactivity.

---

🧠 Simple and minimal: create or join a chat, communicate, optionally encrypt, and do it all without accounts or hassle.
