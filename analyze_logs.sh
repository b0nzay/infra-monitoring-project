#!/usr/bin/env bash
# analyze_logs.sh — генерирует тестовый access.log и анализирует его.
# Использование: ./analyze_logs.sh [число_строк]   (по умолчанию 500, минимум 300)

set -eu

LOG_FILE="access.log"
LINES="${1:-500}"

if [ "$LINES" -lt 300 ]; then
    echo "Нужно минимум 300 строк, получено: $LINES" >&2
    exit 1
fi

# ---------- 1. Генерация access.log ----------
ips=(192.168.1.10 192.168.1.10 192.168.1.10 10.0.0.5 10.0.0.5 172.16.0.7 203.0.113.42 198.51.100.23 10.0.0.99)
methods=(GET GET GET POST PUT DELETE)
paths=(/api/users /api/login /api/orders /api/health /api/items /index.html)
codes=(200 200 200 200 201 301 401 403 404 500 502)

: > "$LOG_FILE"
for ((i = 0; i < LINES; i++)); do
    ip=${ips[RANDOM % ${#ips[@]}]}
    method=${methods[RANDOM % ${#methods[@]}]}
    path=${paths[RANDOM % ${#paths[@]}]}
    code=${codes[RANDOM % ${#codes[@]}]}
    sec=$((i % 60))
    min=$(((i / 60) % 60))
    printf '%s - - [15/Aug/2026:10:%02d:%02d] "%s %s HTTP/1.1" %s\n' \
        "$ip" "$min" "$sec" "$method" "$path" "$code" >> "$LOG_FILE"
done
echo "Сгенерирован $LOG_FILE: $(wc -l < "$LOG_FILE") строк"
echo

# ---------- 2. Анализ ----------
echo "=== Общее количество запросов ==="
total=$(grep -cE '^[0-9]{1,3}(\.[0-9]{1,3}){3} ' "$LOG_FILE")
echo "$total"
echo

echo "=== Топ-3 IP-адреса по числу запросов ==="
# grep -oE вытаскивает IP регулярным выражением, затем sort | uniq -c | sort -rn
grep -oE '^([0-9]{1,3}\.){3}[0-9]{1,3}' "$LOG_FILE" \
    | sort | uniq -c | sort -rn | head -3 \
    | awk '{printf "%s запросов — %s\n", $1, $2}'
echo

echo "=== Запросы с кодами 4xx и 5xx ==="
# Код ответа — последнее поле строки
awk '$NF ~ /^4[0-9][0-9]$/ {c4++} $NF ~ /^5[0-9][0-9]$/ {c5++}
     END {printf "4xx: %d\n5xx: %d\nВсего ошибок: %d\n", c4, c5, c4 + c5}' "$LOG_FILE"
