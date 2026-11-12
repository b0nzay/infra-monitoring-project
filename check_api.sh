#!/usr/bin/env bash
# check_api.sh — проверка доступности API.
# Использование: ./check_api.sh <URL>
# Код возврата: 0 — API доступен (HTTP 200), 1 — ошибка.

set -u

if [ "$#" -ne 1 ]; then
    echo "Использование: $0 <URL>" >&2
    exit 1
fi

url="$1"

# Грубая проверка формата URL (регулярное выражение)
if ! [[ "$url" =~ ^https?://[^[:space:]]+$ ]]; then
    echo "API недоступен, код ответа: 000 (некорректный URL: $url)"
    exit 1
fi

# -s тихий режим, -o /dev/null отбросить тело, -w вывести только код ответа
code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url")
curl_rc=$?

if [ "$curl_rc" -ne 0 ]; then
    code="000"
fi

if [ "$code" = "200" ]; then
    echo "API доступен"
    exit 0
else
    echo "API недоступен, код ответа: $code"
    exit 1
fi
