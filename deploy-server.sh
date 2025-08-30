#!/bin/bash

# Скрипт автоматического деплоя проекта landing_law на сервер 185.23.34.142
# Автор: AI Assistant
# Дата: $(date +%Y-%m-%d)

set -e  # Остановить выполнение при ошибке

# Конфигурация
SERVER_IP="185.23.34.142"
SERVER_USER="root"  # Измените на вашего пользователя
APP_NAME="landing_law"
APP_DIR="/var/www/$APP_NAME"
LOCAL_PROJECT_DIR="$(pwd)"
ARCHIVE_NAME="$APP_NAME-$(date +%Y%m%d_%H%M%S).tar.gz"
DOMAIN="your-domain.com"  # Замените на ваш домен

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция логирования
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Проверка подключения к серверу
check_server_connection() {
    log "Проверка подключения к серверу $SERVER_IP..."
    if ! ping -c 1 $SERVER_IP > /dev/null 2>&1; then
        error "Сервер $SERVER_IP недоступен"
    fi
    
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes $SERVER_USER@$SERVER_IP exit 2>/dev/null; then
        error "Не удается подключиться к серверу по SSH. Проверьте SSH ключи."
    fi
    
    log "Подключение к серверу успешно"
}

# Создание архива проекта
create_archive() {
    log "Создание архива проекта..."
    
    # Исключаем ненужные файлы и папки
    tar --exclude='node_modules' \
        --exclude='.git' \
        --exclude='dist' \
        --exclude='*.log' \
        --exclude='.env.local' \
        --exclude='.DS_Store' \
        -czf "/tmp/$ARCHIVE_NAME" -C "$LOCAL_PROJECT_DIR" .
    
    if [ ! -f "/tmp/$ARCHIVE_NAME" ]; then
        error "Не удалось создать архив"
    fi
    
    log "Архив создан: /tmp/$ARCHIVE_NAME"
}

# Загрузка архива на сервер
upload_archive() {
    log "Загрузка архива на сервер..."
    
    scp "/tmp/$ARCHIVE_NAME" "$SERVER_USER@$SERVER_IP:/tmp/" || error "Не удалось загрузить архив"
    
    log "Архив успешно загружен на сервер"
}

# Выполнение команд на сервере
execute_on_server() {
    log "Выполнение команд на сервере..."
    
    ssh "$SERVER_USER@$SERVER_IP" << EOF
set -e

# Функция логирования на сервере
log() {
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1"
}

log "Начало настройки сервера..."

# Обновление системы
log "Обновление системы..."
apt update && apt upgrade -y

# Установка необходимых пакетов
log "Установка необходимых пакетов..."
apt install -y curl wget git nginx ufw fail2ban

# Установка Node.js 18.x
log "Установка Node.js..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
fi

# Проверка версий
log "Версия Node.js: \$(node --version)"
log "Версия npm: \$(npm --version)"

# Создание пользователя для приложения
log "Создание пользователя приложения..."
if ! id "appuser" &>/dev/null; then
    useradd -m -s /bin/bash appuser
    usermod -aG sudo appuser
fi

# Создание директории приложения
log "Создание директории приложения..."
mkdir -p $APP_DIR
chown appuser:appuser $APP_DIR

# Распаковка приложения
log "Распаковка приложения..."
cd $APP_DIR
rm -rf *
tar -xzf /tmp/$ARCHIVE_NAME -C $APP_DIR
chown -R appuser:appuser $APP_DIR

# Установка зависимостей и сборка
log "Установка зависимостей..."
su - appuser -c "cd $APP_DIR && npm install"

log "Сборка проекта..."
su - appuser -c "cd $APP_DIR && npm run build"

# Проверка сборки
if [ ! -d "$APP_DIR/dist" ]; then
    echo "ОШИБКА: Сборка не удалась!"
    exit 1
fi

# Настройка Nginx
log "Настройка Nginx..."
cat > /etc/nginx/sites-available/$APP_NAME << 'NGINX_EOF'
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    root $APP_DIR/dist;
    index index.html;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Handle React Router
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Cache static assets
    location ~* \\.(js|css|png|jpg|jpeg|gif|ico|svg)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Security
    location ~ /\\. {
        deny all;
    }
}
NGINX_EOF

# Активация сайта
ln -sf /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Проверка конфигурации Nginx
nginx -t

# Настройка файрвола
log "Настройка файрвола..."
ufw --force enable
ufw allow ssh
ufw allow 'Nginx Full'

# Настройка Fail2Ban
log "Настройка Fail2Ban..."
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Перезапуск сервисов
log "Перезапуск сервисов..."
systemctl restart nginx
systemctl restart fail2ban
systemctl enable nginx
systemctl enable fail2ban

# Очистка
rm -f /tmp/$ARCHIVE_NAME

log "Деплой завершен успешно!"
log "Приложение доступно по адресу: http://$DOMAIN"
log "Для настройки SSL выполните: certbot --nginx -d $DOMAIN -d www.$DOMAIN"

EOF
}

# Очистка локальных файлов
cleanup() {
    log "Очистка временных файлов..."
    rm -f "/tmp/$ARCHIVE_NAME"
}

# Основная функция
main() {
    log "Начало автоматического деплоя проекта $APP_NAME"
    log "Сервер: $SERVER_IP"
    log "Пользователь: $SERVER_USER"
    
    check_server_connection
    create_archive
    upload_archive
    execute_on_server
    cleanup
    
    log "Деплой успешно завершен!"
    log "Приложение доступно по адресу: http://$DOMAIN"
    warning "Не забудьте:"
    warning "1. Настроить DNS записи для домена $DOMAIN"
    warning "2. Установить SSL сертификат: ssh $SERVER_USER@$SERVER_IP 'certbot --nginx -d $DOMAIN -d www.$DOMAIN'"
    warning "3. Проверить работу приложения"
}

# Обработка сигналов
trap cleanup EXIT

# Запуск основной функции
main "$@"