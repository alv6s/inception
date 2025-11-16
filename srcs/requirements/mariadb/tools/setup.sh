#!/bin/sh
set -e

service mariadb start || true

# Read env vars (expected to be provided by docker-compose env_file)
: ${DB_NAME:=thedatabase}
: ${DB_USER:=theuser}
: ${DB_PASSWORD:=abc}
: ${DB_PASS_ROOT:=123}

echo "Creating database and users if not exists..."
mariadb -u root <<-SQL || true
CREATE DATABASE IF NOT EXISTS \\`$DB_NAME\\`;
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON \\`$DB_NAME\\`.* TO '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$DB_PASS_ROOT';
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$DB_PASS_ROOT');
FLUSH PRIVILEGES;
SQL

sleep 5
service mariadb stop || true

exec "$@"
