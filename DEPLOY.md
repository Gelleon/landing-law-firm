# Инструкции по развертыванию React приложения на Linux сервере

Это руководство поможет вам развернуть React приложение `landing_law` на Linux сервере.

## Системные требования

- Ubuntu 20.04+ / CentOS 8+ / Debian 11+
- Node.js 18.x или выше
- npm 8.x или выше
- Nginx или Apache
- SSL сертификат (рекомендуется)
- Минимум 1GB RAM
- Минимум 10GB свободного места

## Подготовка сервера

### 1. Обновление системы

```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade -y

# CentOS/RHEL
sudo yum update -y
# или для новых версий
sudo dnf update -y
```

### 2. Установка Node.js

#### Через NodeSource (рекомендуется)

```bash
# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# CentOS/RHEL
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo yum install -y nodejs
```

#### Через NVM (альтернативный способ)

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install 18
nvm use 18
nvm alias default 18
```

### 3. Установка npm и обновление

```bash
npm install -g npm@latest
```

### 4. Установка Git

```bash
# Ubuntu/Debian
sudo apt install git -y

# CentOS/RHEL
sudo yum install git -y
```

### 5. Установка веб-сервера

#### Nginx (рекомендуется)

```bash
# Ubuntu/Debian
sudo apt install nginx -y

# CentOS/RHEL
sudo yum install nginx -y

# Запуск и автозапуск
sudo systemctl start nginx
sudo systemctl enable nginx
```

#### Apache (альтернатива)

```bash
# Ubuntu/Debian
sudo apt install apache2 -y

# CentOS/RHEL
sudo yum install httpd -y

# Запуск и автозапуск
sudo systemctl start apache2  # Ubuntu/Debian
sudo systemctl start httpd    # CentOS/RHEL
sudo systemctl enable apache2 # Ubuntu/Debian
sudo systemctl enable httpd   # CentOS/RHEL
```

## Развертывание приложения

### 1. Создание пользователя для приложения

```bash
sudo useradd -m -s /bin/bash appuser
sudo usermod -aG sudo appuser
```

### 2. Создание директории для приложения

```bash
sudo mkdir -p /var/www/landing_law
sudo chown appuser:appuser /var/www/landing_law
```

### 3. Клонирование репозитория

```bash
cd /var/www/landing_law
git clone https://github.com/your-username/landing_law.git .
# или загрузите файлы через FTP/SCP
```

### 4. Установка зависимостей

```bash
npm install
```

### 5. Сборка проекта

```bash
npm run build
```

После успешной сборки файлы будут находиться в папке `dist/`.

## Настройка веб-сервера

### Конфигурация Nginx

1. Создайте конфигурационный файл:

```bash
sudo nano /etc/nginx/sites-available/landing_law
```

2. Добавьте следующую конфигурацию:

```nginx
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;
    root /var/www/landing_law/dist;
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
        try_files $uri $uri/ /index.html;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Security
    location ~ /\. {
        deny all;
    }
}
```

3. Активируйте сайт:

```bash
sudo ln -s /etc/nginx/sites-available/landing_law /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Конфигурация Apache

1. Создайте конфигурационный файл:

```bash
sudo nano /etc/apache2/sites-available/landing_law.conf
```

2. Добавьте следующую конфигурацию:

```apache
<VirtualHost *:80>
    ServerName your-domain.com
    ServerAlias www.your-domain.com
    DocumentRoot /var/www/landing_law/dist
    
    <Directory /var/www/landing_law/dist>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        
        # Handle React Router
        RewriteEngine On
        RewriteBase /
        RewriteRule ^index\.html$ - [L]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule . /index.html [L]
    </Directory>
    
    # Security headers
    Header always set X-Frame-Options SAMEORIGIN
    Header always set X-Content-Type-Options nosniff
    Header always set X-XSS-Protection "1; mode=block"
    
    # Cache static files
    <LocationMatch "\.(css|js|png|jpg|jpeg|gif|ico|svg)$">
        ExpiresActive On
        ExpiresDefault "access plus 1 year"
    </LocationMatch>
    
    ErrorLog ${APACHE_LOG_DIR}/landing_law_error.log
    CustomLog ${APACHE_LOG_DIR}/landing_law_access.log combined
</VirtualHost>
```

3. Включите необходимые модули и активируйте сайт:

```bash
sudo a2enmod rewrite
sudo a2enmod headers
sudo a2enmod expires
sudo a2ensite landing_law.conf
sudo systemctl reload apache2
```

## Настройка SSL сертификата

### Использование Let's Encrypt (бесплатно)

1. Установите Certbot:

```bash
# Ubuntu/Debian
sudo apt install certbot python3-certbot-nginx -y
# или для Apache
sudo apt install certbot python3-certbot-apache -y

# CentOS/RHEL
sudo yum install certbot python3-certbot-nginx -y
# или для Apache
sudo yum install certbot python3-certbot-apache -y
```

2. Получите SSL сертификат:

```bash
# Для Nginx
sudo certbot --nginx -d your-domain.com -d www.your-domain.com

# Для Apache
sudo certbot --apache -d your-domain.com -d www.your-domain.com
```

3. Настройте автоматическое обновление:

```bash
sudo crontab -e
# Добавьте строку:
0 12 * * * /usr/bin/certbot renew --quiet
```

## Автоматизация развертывания

### Создание скрипта развертывания

Создайте файл `deploy.sh`:

```bash
#!/bin/bash

# Переменные
APP_DIR="/var/www/landing_law"
BACKUP_DIR="/var/backups/landing_law"
DATE=$(date +%Y%m%d_%H%M%S)

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Создание резервной копии
log "Создание резервной копии..."
sudo mkdir -p $BACKUP_DIR
sudo cp -r $APP_DIR/dist $BACKUP_DIR/dist_$DATE

# Обновление кода
log "Обновление кода из репозитория..."
cd $APP_DIR
git pull origin main

# Установка зависимостей
log "Установка зависимостей..."
npm ci --production=false

# Сборка проекта
log "Сборка проекта..."
npm run build

# Проверка сборки
if [ ! -d "dist" ]; then
    log "ОШИБКА: Сборка не удалась!"
    exit 1
fi

# Перезапуск веб-сервера
log "Перезапуск веб-сервера..."
sudo systemctl reload nginx
# или для Apache: sudo systemctl reload apache2

# Очистка старых резервных копий (оставляем последние 5)
log "Очистка старых резервных копий..."
sudo find $BACKUP_DIR -name "dist_*" -type d | sort -r | tail -n +6 | xargs sudo rm -rf

log "Развертывание завершено успешно!"
```

Сделайте скрипт исполняемым:

```bash
chmod +x deploy.sh
```

### Настройка CI/CD с GitHub Actions

Создайте файл `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Server

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        cache: 'npm'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Build project
      run: npm run build
    
    - name: Deploy to server
      if: github.ref == 'refs/heads/main'
      uses: appleboy/ssh-action@v0.1.5
      with:
        host: ${{ secrets.HOST }}
        username: ${{ secrets.USERNAME }}
        key: ${{ secrets.SSH_KEY }}
        script: |
          cd /var/www/landing_law
          ./deploy.sh
```

## Мониторинг и обслуживание

### Настройка логирования

1. Настройте ротацию логов:

```bash
sudo nano /etc/logrotate.d/landing_law
```

```
/var/log/nginx/landing_law*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 www-data www-data
    postrotate
        systemctl reload nginx
    endscript
}
```

### Мониторинг производительности

1. Установите инструменты мониторинга:

```bash
sudo apt install htop iotop nethogs -y
```

2. Настройте мониторинг дискового пространства:

```bash
# Добавьте в crontab
0 */6 * * * df -h | mail -s "Disk Usage Report" admin@your-domain.com
```

## Оптимизация производительности

### 1. Настройка кэширования

Добавьте в конфигурацию Nginx:

```nginx
# Кэширование на уровне Nginx
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=my_cache:10m max_size=10g 
                 inactive=60m use_temp_path=off;

location / {
    proxy_cache my_cache;
    proxy_cache_revalidate on;
    proxy_cache_min_uses 3;
    proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
    proxy_cache_background_update on;
    proxy_cache_lock on;
    
    try_files $uri $uri/ /index.html;
}
```

### 2. Сжатие ресурсов

Убедитесь, что включено сжатие в Nginx:

```nginx
gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_comp_level 6;
gzip_types
    text/plain
    text/css
    text/xml
    text/javascript
    application/javascript
    application/xml+rss
    application/json;
```

### 3. Оптимизация изображений

Используйте WebP формат для изображений:

```bash
# Установка инструментов для конвертации
sudo apt install webp -y

# Конвертация изображений
find /var/www/landing_law/dist -name "*.jpg" -o -name "*.png" | while read img; do
    cwebp "$img" -o "${img%.*}.webp"
done
```

## Безопасность

### 1. Настройка файрвола

```bash
# UFW (Ubuntu/Debian)
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
# или для Apache
sudo ufw allow 'Apache Full'

# Firewalld (CentOS/RHEL)
sudo systemctl enable firewalld
sudo systemctl start firewalld
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

### 2. Настройка Fail2Ban

```bash
sudo apt install fail2ban -y

# Создайте локальную конфигурацию
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Отредактируйте конфигурацию
sudo nano /etc/fail2ban/jail.local
```

Добавьте секцию для Nginx:

```ini
[nginx-http-auth]
enabled = true
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 3
bantime = 3600

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
logpath = /var/log/nginx/error.log
maxretry = 10
bantime = 3600
```

### 3. Обновления безопасности

Настройте автоматические обновления безопасности:

```bash
# Ubuntu/Debian
sudo apt install unattended-upgrades -y
sudo dpkg-reconfigure -plow unattended-upgrades

# CentOS/RHEL
sudo yum install yum-cron -y
sudo systemctl enable yum-cron
sudo systemctl start yum-cron
```

## Резервное копирование

### Создание скрипта резервного копирования

Создайте файл `backup.sh`:

```bash
#!/bin/bash

APP_DIR="/var/www/landing_law"
BACKUP_DIR="/var/backups/landing_law"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Создание резервной копии
mkdir -p $BACKUP_DIR
tar -czf $BACKUP_DIR/backup_$DATE.tar.gz -C $APP_DIR .

# Удаление старых резервных копий
find $BACKUP_DIR -name "backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo "Резервная копия создана: backup_$DATE.tar.gz"
```

Добавьте в crontab для ежедневного выполнения:

```bash
sudo crontab -e
# Добавьте строку:
0 2 * * * /var/www/landing_law/backup.sh
```

## Устранение неполадок

### Проверка статуса сервисов

```bash
# Проверка статуса Nginx
sudo systemctl status nginx

# Проверка логов Nginx
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log

# Проверка конфигурации Nginx
sudo nginx -t

# Проверка процессов Node.js
ps aux | grep node

# Проверка использования портов
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443
```

### Общие проблемы и решения

1. **Ошибка 502 Bad Gateway**
   - Проверьте, запущен ли процесс приложения
   - Проверьте правильность конфигурации upstream в Nginx

2. **Ошибка 404 для маршрутов React Router**
   - Убедитесь, что настроена правильная обработка fallback в веб-сервере

3. **Медленная загрузка**
   - Проверьте включение gzip сжатия
   - Оптимизируйте изображения
   - Настройте кэширование

4. **Проблемы с SSL**
   - Проверьте срок действия сертификата: `sudo certbot certificates`
   - Обновите сертификат: `sudo certbot renew`

### Полезные команды

```bash
# Проверка использования дискового пространства
df -h
du -sh /var/www/landing_law/*

# Проверка использования памяти
free -h

# Проверка загрузки процессора
top
htop

# Проверка сетевых соединений
ss -tulpn

# Проверка логов системы
sudo journalctl -u nginx -f
sudo journalctl -u apache2 -f
```

## Поддержка

Для получения дополнительной помощи обратитесь к документации используемых технологий или к системному администратору.