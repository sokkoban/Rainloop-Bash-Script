#!/bin/bash

#############################################################
Install script for RainLoop v.1.17 ONLY              ########
The link may be different later!                     ########   
By sokoban - v.1.0                                   ########
#############################################################

# Update the package list and upgrade existing packages
sudo apt update
sudo apt upgrade -y

# Install required packages (web server, PHP, and others)
sudo apt install -y nginx php-fpm php-mbstring php-dom php-curl unzip

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

# Configure Nginx server block for RainLoop
sudo tee /etc/nginx/sites-available/rainloop << EOF
server {
    listen 80;
    server_name $server_fqdn; # Use the FQDN as the server name

    root /var/www/html/rainloop;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$php_fpm_socket; # Use the determined PHP version
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

echo "RainLoop has been installed successfully. You can access it at http://$server_fqdn"
