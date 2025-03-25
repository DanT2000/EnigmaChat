<p align="center">
  <img src="assets/logo.png" alt="EnigmaChat Logo" width="150"/>
</p>
> 🇷🇺 Этот файл доступен на русском и английском языках  
> 🇬🇧 This file is available in Russian and English

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

4. Укажите порт, на котором будет работать чат (по умолчанию — 9125).  
   После этого начнётся автоматическая установка всех зависимостей и запуск сервера.

5. Всё готово 🎉  
   Чат будет доступен по адресу `http://localhost:ваш_порт` (например, `http://localhost:9125`).

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

