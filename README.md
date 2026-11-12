# infra-monitoring-project

Учебный DevOps-проект: мониторинг доступности API, анализ логов, контейнеризированный стек (echo-сервис + nginx-прокси) и CI/CD на GitHub Actions.

## Структура

| Файл | Назначение |
|------|-----------|
| `check_api.sh` | Проверка доступности API по URL (код 0 — доступен, 1 — ошибка) |
| `analyze_logs.sh` | Генерация `access.log` и анализ (всего запросов, топ-3 IP, 4xx/5xx) |
| `docker-compose.yml` | Сервисы `api` (hashicorp/http-echo) и `proxy` (nginx:alpine) |
| `nginx/default.conf` | Конфиг прокси: порт 80 → `api:8080` |
| `.github/workflows/ci.yml` | CI: проверка синтаксиса и тест скрипта на Pull Request |
| `traffic/dump.pcapng` | Дамп трафика (Wireshark), описание — в отчёте `report/` |
| `.gitattributes` | Принудительные LF-переводы строк для скриптов |

## Окружение
Работа выполнена в Windows 11 + WSL2 (Ubuntu), Docker Desktop (интеграция с WSL), Wireshark 4.6. Все команды ниже выполняются в терминале Linux/WSL.

## Запуск

### Скрипты
```bash
chmod +x check_api.sh analyze_logs.sh

./check_api.sh https://httpbin.org/status/200   # API доступен, код возврата 0
./check_api.sh https://httpbin.org/status/500   # API недоступен, код возврата 1
echo $?                                         # посмотреть код возврата

./analyze_logs.sh          # 500 строк по умолчанию
./analyze_logs.sh 1000     # своё количество (минимум 300)
```

### Docker Compose
```bash
docker-compose up -d
docker-compose ps
curl http://localhost:80      # -> Monitoring Service Active
docker-compose down
```
Контейнеры связаны внутренней сетью `monitoring-net`; nginx обращается к API по имени сервиса `api`.

## Деплой на удалённый сервер (SSH / SCP)

### 1. Генерация SSH-ключа
```bash
ssh-keygen -t ed25519 -C "deploy@infra-monitoring" -f ~/.ssh/id_ed25519_deploy
```

### 2. Копирование публичного ключа на сервер
```bash
ssh-copy-id -i ~/.ssh/id_ed25519_deploy.pub user@203.0.113.10
# проверка входа без пароля
ssh -i ~/.ssh/id_ed25519_deploy user@203.0.113.10 "echo ok"
```

### 3. Передача проекта

Вариант А — архив + scp:
```bash
tar --exclude='.git' --exclude='*.log' -czf infra-monitoring.tar.gz .
scp -i ~/.ssh/id_ed25519_deploy infra-monitoring.tar.gz user@203.0.113.10:/opt/
ssh -i ~/.ssh/id_ed25519_deploy user@203.0.113.10 \
  "mkdir -p /opt/infra-monitoring && tar -xzf /opt/infra-monitoring.tar.gz -C /opt/infra-monitoring"
```

Вариант Б — tar через ssh без промежуточного файла:
```bash
tar --exclude='.git' -czf - . | ssh -i ~/.ssh/id_ed25519_deploy user@203.0.113.10 \
  "mkdir -p /opt/infra-monitoring && tar -xzf - -C /opt/infra-monitoring"
```

### 4. Запуск на сервере
```bash
ssh -i ~/.ssh/id_ed25519_deploy user@203.0.113.10 \
  "cd /opt/infra-monitoring && docker-compose up -d && docker-compose ps"
```

### Рекомендации по безопасности
- Отключить вход по паролю: `PasswordAuthentication no` в `/etc/ssh/sshd_config`.
- Права на ключ: `chmod 600 ~/.ssh/id_ed25519_deploy`.
- Приватный ключ никогда не коммитить в репозиторий.

## CI/CD
При создании Pull Request в `main` workflow `CI` выполняет `bash -n` для обоих скриптов и запускает `check_api.sh https://httpbin.org/status/200`.
