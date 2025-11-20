#!/bin/sh
set -e

DB_PASSWORD="$(tr -d '\r\n' < /run/secrets/db_password)"
WP_ADMIN_PASSWORD="$(tr -d '\r\n' < /run/secrets/wp_admin_password)"
WP_USER_PASSWORD="$(tr -d '\r\n' < /run/secrets/wp_password)"
DB_HOST="${DB_HOST:-mariadb}"

cp /tmp/wp-config.php /var/www/inception/wp-config.php
chown -R www-data:www-data /var/www/inception/

# Wait for MariaDB to be ready
echo "Waiting for MariaDB..."
until mysql --protocol=TCP -h "${DB_HOST}" -u "${DB_USER}" -p"${DB_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1; do
    echo "Database not available. Waiting..."
    sleep 5
done
echo "Database is available!"

# Create database if not exists
mysql --protocol=TCP -h "${DB_HOST}" -u "${DB_USER}" -p"${DB_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};" 2>/dev/null || echo "Database exists or creation failed"

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
        "$WP_USER" "$WP_EMAIL" --user_pass="$WP_USER_PASSWORD" --role="$WP_ROLE"
fi

wp --allow-root --path="/var/www/inception/" theme install twentytwentythree --activate || true

exec "$@"