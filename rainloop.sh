#!/bin/bash

# Update the package list and upgrade existing packages
sudo apt update
sudo apt upgrade -y

# Install required packages (web server, PHP, Certbot, and others)
sudo apt install -y nginx php-fpm php-mbstring php-dom php-curl unzip certbot python3-certbot-nginx

# Get the server's FQDN
server_fqdn=$(hostname -f)

# Determine the installed PHP version and PHP-FPM socket path
php_version=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
php_fpm_socket="/run/php/php${php_version}-fpm.sock"

# Download RainLoop version 1.17.0 from the specified link
sudo rm -rf /var/www/html/rainloop
sudo mkdir -p /var/www/html/rainloop
sudo curl -L -o rainloop.zip https://github.com/RainLoop/rainloop-webmail/releases/download/v1.17.0/rainloop-legacy-1.17.0.zip
sudo unzip -q rainloop.zip -d /var/www/html/rainloop
sudo rm rainloop.zip

# Set appropriate permissions
sudo chown -R www-data:www-data /var/www/html/rainloop
sudo chmod -R 755 /var/www/html/rainloop

# Configure Nginx server block for RainLoop with HTTPS
sudo tee /etc/nginx/sites-available/rainloop << EOF
server {
    listen 80;
    server_name $server_fqdn;

    # Redirect HTTP to HTTPS
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $server_fqdn;

    ssl_certificate /etc/letsencrypt/live/$server_fqdn/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$server_fqdn/privkey.pem;

    root /var/www/html/rainloop;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$php_fpm_socket;
    }

    location ~* /\.ht {
        deny all;
    }
}
EOF

# Enable the RainLoop site
sudo ln -s /etc/nginx/sites-available/rainloop /etc/nginx/sites-enabled/

# Test Nginx configuration and reload
sudo nginx -t
sudo systemctl reload nginx

# Restart PHP-FPM using the determined version
sudo systemctl restart "php${php_version}-fpm"

# Obtain Let's Encrypt SSL certificate
sudo certbot --nginx -d $server_fqdn

echo "RainLoop has been installed successfully. You can access the admin panel at https://$server_fqdn/?admin"
echo "Default username for the admin panel is 'admin', and the default password is '12345'. Please change the password after login for security purposes."
