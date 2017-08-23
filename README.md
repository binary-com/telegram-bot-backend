# Telegram Bot Backend

This repository is for communicating with the telegram api and responding to the user query.

How to start?
---
Set environment variable for bot by executing:

> $ export TELEGRAM_BOT="token"

Install `cpanm` and dependencies:

> $ sudo apt install gcc   
> $ sudo apt install cpanminus   
> $ sudo cpanm install Mojo::UserAgent   
> $ sudo cpanm install JSON   
> $ sudo cpanm install DBI   
> $ sudo cpanm install Future   
> $ sudo cpanm install DBD::SQLite   

Then:

> $ hypnotoad bin/listener.pl

To stop the server:

> $ hypnotoad bin/listener.pl --stop

Files and associated functions:
---

- *bin/app.pl* : Driver program.
- *bin/listener.pl* : Creates webhook for telegram.
- *GetUpdates.pm* : Gets messages from telegram API's `getUpdates` endpoint.
- *SendMessage.pm* : Used for responding back to user. Sends message to the chats using `sendMessage` endpoint.
- *StateManager.pm* : Stores data to a file based db.
- *TelegramCommandHandler* : Handles user messages and responds back with relevant messages.
- *WSBridge.pm* : Communicates with the Binary.com's API and handles the state for every chat. State handling needs to be moved to `StateManager.pm`.
- *WSResponseHandler.pm* : Handles response from Websocket and sends them back to user.

To Do:
---
- ~Implement StateManager.pm, ~~maybe try Redis?~~ (Using sqlite instead)~
- Better error handling. Maybe create a separate module just for error handling?
- Retries on error in SendMessage.pm & WSBridge.pm.
- ~~Use webhooks to get messages.~~
- Implement a queue for sending requests to the telegram API.
- Add tests.
- Use EditMessage endpoint for better user experience.

