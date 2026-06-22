#!/bin/bash
# Usage: sudo bash deploy-app.sh <app-name> <port> <domain> [git-repo-url]
# Example: sudo bash deploy-app.sh meowmin 3001 meowmin.com https://github.com/you/meowmin-backend.git

set -e

APP_NAME=$1
PORT=$2
DOMAIN=$3
REPO_URL=$4

if [ -z "$APP_NAME" ] || [ -z "$PORT" ] || [ -z "$DOMAIN" ]; then
  echo "Usage: sudo bash deploy-app.sh <app-name> <port> <domain> [git-repo-url]"
  echo "  If no git repo URL, place your code in /var/www/<app-name>/server/"
  exit 1
fi

echo "=== Deploying $APP_NAME on port $PORT for domain $DOMAIN ==="

# 1. Create app user
id -u $APP_NAME &>/dev/null || useradd -m -s /bin/bash $APP_NAME

# 2. Create directory structure
mkdir -p /var/www/$APP_NAME/server
chown -R $APP_NAME:$APP_NAME /var/www/$APP_NAME

# 3. Clone or copy code
if [ -n "$REPO_URL" ]; then
  sudo -u $APP_NAME git clone "$REPO_URL" /var/www/$APP_NAME/server
fi

# 4. Install npm dependencies
cd /var/www/$APP_NAME/server
sudo -u $APP_NAME npm init -y 2>/dev/null
if [ -f package.json ]; then
  sudo -u $APP_NAME npm install --production
fi

# 5. Create pm2 ecosystem config
sudo -u $APP_NAME bash -c "pm2 delete $APP_NAME 2>/dev/null; pm2 start server.js --name $APP_NAME -- --port $PORT"
sudo -u $APP_NAME pm2 save

# 6. Create nginx config
cat > /etc/nginx/sites-available/$APP_NAME.conf << NGINX
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX

ln -sf /etc/nginx/sites-available/$APP_NAME.conf /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

echo "=== Done: $APP_NAME deployed on port $PORT ==="
echo "  pm2 status: pm2 list"
echo "  logs:       pm2 logs $APP_NAME"
echo "  nginx test: curl http://127.0.0.1:$PORT/"
