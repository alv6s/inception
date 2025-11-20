#!/bin/sh
set -e

DB_PASSWORD="$(cat /run/secrets/db_password)"

chown -R www-data:www-data /var/www/inception/

if [ ! -f /var/www/inception/wp-config.php ]; then
    mv /tmp/wp-config.php /var/www/inception/
fi

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
        --admin_password="$(cat /run/secrets/wp_admin_password)" \
        --admin_email="$WP_ADMIN_EMAIL"
fi

if ! wp --allow-root --path="/var/www/inception/" user get "$WP_USER" 2>/dev/null; then
    wp --allow-root --path="/var/www/inception/" user create \
        "$WP_USER" "$WP_EMAIL" --user_pass="$(cat /run/secrets/wp_user_password)" --role="$WP_ROLE"
fi

wp --allow-root --path="/var/www/inception/" theme install twentytwentythree --activate || true

exec "$@"