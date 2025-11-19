#!/bin/sh
set -e

chown -R www-data:www-data /var/www/inception/

if [ ! -f /var/www/inception/wp-config.php ]; then
    mv /tmp/wp-config.php /var/www/inception/
fi

# Default values for WP installation (can be overridden by env)
WP_URL=${WP_URL:-pevieira.42.fr}
WP_TITLE=${WP_TITLE:-Inception}
WP_ADMIN_USER=${WP_ADMIN_USER:-theroot}
WP_ADMIN_PASSWORD=${WP_ADMIN_PASSWORD:-123}
WP_ADMIN_EMAIL=${WP_ADMIN_EMAIL:-theroot@123.com}
WP_USER=${WP_USER:-theuser}
WP_PASSWORD=${WP_PASSWORD:-abc}
WP_EMAIL=${WP_EMAIL:-theuser@123.com}
WP_ROLE=${WP_ROLE:-editor}

# Wait for MariaDB to be ready
echo "Waiting for MariaDB..."
until mysql -h mariadb -u ${DB_USER} -p${DB_PASSWORD} -e "SELECT 1;" >/dev/null 2>&1; do
    echo "Database not available. Waiting..."
    sleep 5
done
echo "Database is available!"

# Create database if not exists
mysql -h mariadb -u ${DB_USER} -p${DB_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};" 2>/dev/null || echo "Database exists or creation failed"

sleep 2
wp --allow-root --path="/var/www/inception/" core download || true

if ! wp --allow-root --path="/var/www/inception/" core is-installed; then
    wp --allow-root --path="/var/www/inception/" core install \
        --url="$WP_URL" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL"
fi

if ! wp --allow-root --path="/var/www/inception/" user get "$WP_USER" 2>/dev/null; then
    wp --allow-root --path="/var/www/inception/" user create \
        "$WP_USER" "$WP_EMAIL" --user_pass="$WP_PASSWORD" --role="$WP_ROLE"
fi

wp --allow-root --path="/var/www/inception/" theme install twentytwentythree --activate || true

exec "$@"