#!/bin/sh
set -e

DB_PASSWORD="$(cat /run/secrets/db_password)"
DB_PASS_ROOT="$(cat /run/secrets/db_pass_root)"

echo "Debug - DB_PASSWORD length: $(echo -n "$DB_PASSWORD" | wc -c)"
echo "Debug - DB_PASSWORD (first 4 chars): $(echo "$DB_PASSWORD" | head -c 4)..."

service mariadb start 

mariadb -v -u root << EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
DROP USER IF EXISTS '$DB_USER'@'%';
DROP USER IF EXISTS '$DB_USER'@'wordpress.inception_all';
CREATE USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
CREATE USER '$DB_USER'@'wordpress.inception_all' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'wordpress.inception_all';
DROP USER IF EXISTS 'root'@'%';
CREATE USER 'root'@'%' IDENTIFIED BY '$DB_PASS_ROOT';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$DB_PASS_ROOT');
FLUSH PRIVILEGES;
SELECT user, host FROM mysql.user WHERE user = '$DB_USER';
EOF


sleep 5
service mariadb stop


exec $@ 