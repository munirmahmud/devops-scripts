#!/bin/bash

NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
DEFAULT_ROOT="/var/lib/jenkins/workspace"

# 1. Ask for domain name
while true; do
    echo "Enter your domain name (required, e.g., example.com):"
    read DOMAIN

    # Check if empty
    if [ -z "$DOMAIN" ]; then
        echo "Domain name is required. Please try again."
        continue
    fi

    # Check if config already exists
    CONFIG_BARE="$NGINX_AVAILABLE/$DOMAIN"
    CONFIG_CONF="$NGINX_AVAILABLE/$DOMAIN.conf"

    if [ -f "$CONFIG_BARE" ] || [ -f "$CONFIG_CONF" ]; then
        echo "A config for '$DOMAIN' already exists as '$CONFIG_BARE' or '$CONFIG_CONF'"
        echo "Please enter a different domain name."
    else
        break
    fi
done

# 2. Ask for root directory with default fallback
echo "Enter your root directory (press Enter for default: $DEFAULT_ROOT):"
read ROOT_DIR

if [ -z "$ROOT_DIR" ]; then
    ROOT_DIR="$DEFAULT_ROOT"
    echo "Using default root: $ROOT_DIR"
fi


# 3. Email for SSL
#echo "Enter your email for SSL certificate (used by Certbot):"
#read EMAIL

# 4. Create Nginx config
cat > "$CONFIG_BARE" <<EOL
server {
    listen 80;
    server_name $DOMAIN;

    root $ROOT_DIR;
    index index.html index.htm index.php;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL

echo "Nginx config created at $CONFIG_BARE"

# 5. Symlink to sites-enabled
sudo ln -s "$CONFIG_BARE" "$NGINX_ENABLED/"
echo "Symlinked to $NGINX_ENABLED"

# 6. Test Nginx config
sudo nginx -t
if [ $? -ne 0 ]; then
    echo "Nginx configuration test failed. Aborting."
    exit 1
fi

# 7. Reload Nginx
sudo systemctl reload nginx
echo "Nginx reloaded"

# 8. Run Certbot for SSL
#certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL"
certbot --nginx -d "$DOMAIN"
echo "🔐 SSL installed for $DOMAIN"

echo "🎉 All done!"
