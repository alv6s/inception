# Inception

This project is an introduction to the DevOps world. Its purpose is to introduce the use of Docker and Docker Compose to deploy a small web server that uses NGINX with a WordPress site and a MariaDB database. It's a simple project, but very important for understanding the basic concepts of DevOps.

## Note: Score: 100/100

# Inception Guide

This project will cover concepts we haven't seen before, so I recommend testing it first on your PC (from simplest to most complex) and then on a VM. This guide follows that order. At the end, you'll have a VM with Docker and Docker Compose installed, and you'll be able to deploy a WordPress site with a MariaDB database hosted with NGINX server.

## Table of Contents
- [1. The Containers](#1-the-containers)
	- [1.1. MariaDB](#11-mariadb)
		- [1.1.1. Dockerfile](#111-dockerfile)
		- [1.1.2. 50-server.cnf](#112-50-servercnf)
		- [1.1.3. setup.sh](#113-setupsh)
		- [1.1.4. Testing the mariadb container](#114-testing-the-mariadb-container)
	- [1.2. WordPress](#12-wordpress)
		- [1.2.1. Dockerfile](#121-dockerfile)
		- [1.2.2. www.conf](#122-wwwconf)
		- [1.2.3. wp-config.php](#123-wp-configphp)
		- [1.2.4. setup.sh](#124-setupsh)
		- [1.2.5. Testing the wordpress container](#125-testing-the-wordpress-container)
	- [1.3. NGINX](#13-nginx)
		- [1.3.1. The Dockerfile](#131-the-dockerfile)
		- [1.3.2. server.conf](#132-serverconf)
		- [1.3.3. nginx.conf](#133-nginxconf)
		- [1.3.4. Testing the nginx image](#134-testing-the-nginx-image)
- [2. Docker Compose](#2-docker-compose)
	- [2.1. docker-compose.yml](#21-docker-composeyml)
	- [2.2. .env](#22-env)
	- [2.3. docker-compose test](#23-docker-compose-test)
- [3. The Makefile](#3-the-makefile)
- [4. The VM](#4-the-vm)
	- [4.1. VM Creation](#41-vm-creation)
	- [4.2. Debian Installation](#42-debian-installation)
	- [4.3. VM Configuration](#43-vm-configuration)
		- [4.3.1. Add user to sudo](#431-add-user-to-sudo)
		- [4.3.2. Enable Shared Folders](#432-enable-shared-folders)
		- [4.3.3. Install Docker and docker-compose](#433-install-docker-and-docker-compose)
		- [4.3.4. Install make and hostsed](#434-install-make-and-hostsed)
- [5. The Website](#5-the-website)
	- [5.1. Copy files to the VM](#51-copy-files-to-the-vm)
	- [5.2. Start the containers](#52-start-the-containers)
	- [5.3. Credential verification](#53-credential-verification)
	- [5.4. MariaDB verification](#54-mariadb-verification)


## 1. The Containers

First, you need to understand the basics of `docker`. Here's a guide that helped me with Docker and starting my first container.

Follow the link: https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-20-04

**PS:** I strongly recommend following the part of the guide that explains how to create a non-root user to use Docker. This will be very useful in the future.

Now, let's create our own containers, one per service. We'll create a folder with the service name; inside it we'll create the `Dockerfile` and the `conf` and `tools` folders when necessary.

I'll cover the important points of each service, but inside the repository you'll find the files with comments to see how it works. Whenever something new appears, I'll try to explain what it is; the next times I'll just show the command. Therefore, the first services will have more explanations than the last ones.

**Warning:** The subject requires using the penultimate stable version of Debian or Alpine. As of September 2023, the latest stable version of Debian is 12 (bookworm). Because of this, I used Debian 11 (bullseye) for all images.

### 1.1. MariaDB
Files: `Dockerfile`, `conf/50-server.cnf`, `tools/setup.sh`

#### 1.1.1. Dockerfile
1. Use the `debian:bullseye` image:
```Dockerfile
FROM debian:bullseye
```
2. Indicate that the container will listen on port 3306:
```Dockerfile
EXPOSE 3306
```
3. Update the system and install only `mariadb-server`. The `--no-install-recommends` and `--no-install-suggests` flags avoid installing unnecessary packages. I use `&&` to reduce layers. The `rm -rf /var/lib/apt/lists/*` cleans the apt cache to not increase the image size.
```Dockerfile
RUN apt update && \
    apt install -y --no-install-recommends --no-install-suggests \
    mariadb-server && \
    rm -rf /var/lib/apt/lists/*
```
4. Copy the configuration file to the container:
```Dockerfile
COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/
```
5. Copy the setup script to the container and change permissions:
```Dockerfile
COPY tools/setup.sh /bin/
RUN chmod +x /bin/setup.sh
```
6. Run the setup script and then start the DB server (`mysqld_safe`):
```Dockerfile
CMD ["setup.sh", "mysqld_safe"]
```

#### 1.1.2. 50-server.cnf
It's a standard file without commented lines. The important part is to change `port=3306` if necessary.

#### 1.1.3. setup.sh
1. Start the MariaDB server:
```bash
service mariadb start
```
2. To test locally, we declare variables in this script, but in the final version we'll use the `.env` file. Remove these declarations later.
```bash
DB_NAME=thedatabase
DB_USER=theuser
DB_PASSWORD=abc
DB_PASS_ROOT=123
```
3. Create the database and users with permissions:
```bash
mariadb -v -u root << EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO 'root'@'%' IDENTIFIED BY '$DB_PASS_ROOT';
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$DB_PASS_ROOT');
EOF
```
4. Prepare to restart the server to apply changes. `sleep` avoids errors before stopping the service:
```bash
sleep 5
service mariadb stop
```
5. Restart the server with the command passed as argument in the `Dockerfile`:
```bash
exec $@
```

#### 1.1.4. Testing the mariadb container
In the `mariadb` directory, build the image and run it:
```bash
docker build -t mariadb .
docker run -d mariadb
```
Check if it's running:
```bash
docker ps -a
```
Enter the container:
```bash
docker exec -it <ID> /bin/bash
```
Inside the container, test the DB:
```bash
mysql -u theuser -p thedatabase
```
If you see the `MariaDB [thedatabase]>` prompt, it's ok. To exit: `exit`.

Clean test containers/images:
```bash
docker rm -f $(docker ps -aq) && docker rmi -f $(docker images -aq)
```

### 1.2. WordPress
Files: `Dockerfile`, `conf/wp-config.php`, `conf/www.conf`, `tools/setup.sh`

#### 1.2.1. Dockerfile
1. Use `debian:bullseye`.
2. Indicate that the container will listen on port 9000.
3. Define `ARG` to use in build:
```Dockerfile
ARG PHPPATH=/etc/php/7.4/fpm
```
4. Update and install `ca-certificates`, `php7.4-fpm`, `php7.4-mysql`, `wget` and `tar`.
5. After PHP installation, the service might be running, so stop it to change configurations:
```Dockerfile
RUN service php7.4-fpm stop
```
6. Copy the pool configuration and apply changes:
```Dockerfile
COPY conf/www.conf ${PHPPATH}/pool.d/
RUN sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' ${PHPPATH}/php.ini && \
    sed -i "s/listen = \/run\/php\/php$PHP_VERSION_ENV-fpm.sock/listen = 9000/g" ${PHPPATH}/pool.d/www.conf && \
    sed -i 's/;listen.mode = 0660/listen.mode = 0660/g' ${PHPPATH}/pool.d/www.conf && \
    sed -i 's/;daemonize = yes/daemonize = no/g' ${PHPPATH}/pool.d/www.conf
```
7. Download WP-CLI and make it executable:
```Dockerfile
RUN wget --no-check-certificate https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp
```
8. Create necessary folders and adjust owner:
```Dockerfile
RUN mkdir -p /run/php/ /var/run/php/ /var/www/inception/
RUN chown -R www-data:www-data /var/www/inception/
```
9. Copy `wp-config.php` and the setup script and give permissions:
10. Run the setup script and start PHP in foreground:
```Dockerfile
CMD ["setup.sh", "php-fpm7.4", "--nodaemonize"]
```

#### 1.2.2. www.conf
Standard file - important changes: user, group and port:
```conf
user = www-data
group = www-data
listen = 9000
```

#### 1.2.3. wp-config.php
Standard file. The important thing is to use environment variables for the DB and URL:
```php
define( 'DB_NAME', getenv('DB_NAME') );
define( 'DB_USER', getenv('DB_USER') );
// etc...
```

#### 1.2.4. setup.sh
1. Fix file owner to `www-data`:
```bash
chown -R www-data:www-data /var/www/inception/
```
2. Move `wp-config.php` if necessary.
3. Define temporary variables (later use `.env`).
4. Download WordPress files:
```bash
sleep 10
wp --allow-root --path="/var/www/inception/" core download || true
```
5. If not installed, run installation with `wp core install`.
6. Create non-admin user.
7. Install and activate a theme (optional).
8. Start PHP in foreground with `exec $@`.

#### 1.2.5. Testing the wordpress container
In the `wordpress` directory, build and run the image:
```bash
docker build -t wordpress .
docker run -d wordpress
docker ps -a
docker exec -it <ID> /bin/bash
```
Check files:
```bash
sleep 30 && ls /var/www/inception/
```
If the files are there, it's ok. Clean tests:
```bash
docker rm -f $(docker ps -aq) && docker rmi -f $(docker images -aq)
```

### 1.3. NGINX
Files: `Dockerfile`, `conf/server.conf`, `conf/nginx.conf`

#### 1.3.1. The Dockerfile
1. Use `debian:bullseye`.
2. Indicate that the container will listen on port 443.
3. Update and install `nginx` and `openssl`.
4. Define `ARG` for certificates (in the end use `.env`).
5. Create folder and generate self-signed certificate:
```Dockerfile
RUN mkdir -p ${CERT_FOLDER} && \
    openssl req -newkey rsa:4096 -x509 -sha256 -days 365 -nodes \
    -out ${CERTIFICATE} \
    -keyout ${KEY} \
    -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCALITY}/O=${ORGANIZATION}/OU=${UNIT}/CN=${COMMON_NAME}"
```
6. Copy configuration files and complete `server.conf` with variables:
7. Create `/var/www/` and adjust owner to `www-data`.
8. Start Nginx in foreground.

#### 1.3.2. server.conf
Configure for `listen 443 ssl;`, `ssl_protocols TLSv1.2;` and `root /var/www/inception/;`.
At the end of the file, add the lines generated in the Dockerfile for the certificates.

#### 1.3.3. nginx.conf
Define `user www-data;` and upstream to communicate with php-fpm on port 9000:
```conf
user www-data;
upstream php7.4-fpm {
    server wordpress:9000;
}
```

#### 1.3.4. Testing the nginx image
In the `nginx` directory:
```bash
docker build -t nginx .
docker images
docker rmi -f nginx
```

## 2. Docker Compose

After you have the Dockerfiles working, we create the `docker-compose.yml` to run everything together.
Check if you have the `docker compose` plugin installed:
```bash
docker compose version
```
If not, install it:
```bash
sudo apt-get install docker-compose-plugin
```

Important files: the `requirements` folder, `docker-compose.yml` and the `.env` file.

### 2.1. docker-compose.yml
Starts with `services:` and defines each service (mariadb, wordpress, nginx) with `build`, `volumes`, `networks`, `init`, `restart` and `env_file`.

The `volumes` sections mount host folders for persistence (e.g.: `~/data/database` and `~/data/wordpress_files`).

The `networks` section defines a bridge network called `all`.

### 2.2. .env
This file contains variables used by `docker-compose`. Never publish files with confidential information. Variable examples:
```bash
# Database settings
DB_NAME=thedatabase
DB_USER=theuser
DB_PASSWORD=abc
DB_PASS_ROOT=123
DB_HOST=mariadb

# Wordpress settings
WP_URL=login.42.fr
WP_TITLE=Inception
WP_ADMIN_USER=theroot
WP_ADMIN_PASSWORD=123
WP_ADMIN_EMAIL=theroot@123.com
WP_USER=theuser
WP_PASSWORD=abc
WP_EMAIL=theuser@123.com
WP_ROLE=editor
WP_FULL_URL=https://login.42.fr

# SSL settings
CERT_FOLDER=/etc/nginx/certs/
CERTIFICATE=/etc/nginx/certs/certificate.crt
KEY=/etc/nginx/certs/certificate.key
COUNTRY=BR
STATE=BA
LOCALITY=Salvador
ORGANIZATION=42
UNIT=42
COMMON_NAME=login.42.fr
```

### 2.3. docker-compose test
In the directory with `docker-compose.yml`, run:
```bash
docker compose up
```
If everything is correct, you'll see the containers running and the terminal will be attached to the logs. To test, open in browser:
```bash
https://localhost
```
If the WordPress page appears, everything is ok. To clean the tests, stop with `Ctrl+C` and run the provided cleanup commands.

## 3. The Makefile

Create a `srcs` folder and put all files there.
Install `hostsed` to facilitate adding the URL to `/etc/hosts`:
```bash
sudo apt-get install hostsed
```

A simple `Makefile` should have at least two targets: `up` and `down`. Example:
```Makefile
NAME = inception
SRCS = ./srcs
COMPOSE = $(SRCS)/docker-compose.yml
HOST_URL = login.42.fr

up:
	mkdir -p ~/data/database
	mkdir -p ~/data/wordpress_files
	sudo hostsed add 127.0.0.1 $(HOST_URL)
	docker compose -p $(NAME) -f $(COMPOSE) up --build || (echo " $(FAIL)" && exit 1)

down:
	sudo hostsed rm 127.0.0.1 $(HOST_URL)
	docker compose -p $(NAME) down
```

Use `make up` to bring up and `make down` to stop.

## 4. The VM

This phase has several steps to get your VM ready.

### 4.1. VM Creation
1. Download the Debian image (e.g.: Debian 11).
2. In VirtualBox, create a new Linux Debian 64-bit VM.
3. RAM: 4096 MB.
4. Disk: Dynamic VDI, at least 30 GB.
5. Boot order: Optical, Hard Disk, Network.
6. CPU: 4 processors.
7. Video: 128 MB.
8. Audio: disabled.
9. Network: NAT.
10. Select the ISO and boot the VM.

### 4.2. Debian Installation
1. Select "install" and follow the usual steps.
2. In partitioning, choose "guided - use entire disk - LVM".
3. In software options, choose XFCE, Webserver, SSH server and standard utilities.
4. Install GRUB on the disk.

### 4.3. VM Configuration

#### 4.3.1. Add user to sudo
```bash
su -
usermod -aG sudo user
sudo visudo
# add at the end:
user ALL=(ALL) ALL
```
Restart the VM.

#### 4.3.2. Enable shared folder
1. On PC, create a `shared` folder in your home.
2. In VirtualBox > Shared Folders, add this folder with auto-mount and make permanent.
3. In VM, insert Guest Additions and install:
```bash
sudo sh VBoxLinuxAdditions.run
sudo reboot
```
4. Add user to `vboxsf` group and change owner of mounted folder:
```bash
sudo usermod -a -G vboxsf your_user
sudo chown -R your_user:users /media/
```
5. Logout/login.

#### 4.3.3. Install Docker and docker-compose
Prepare Docker repository and install:
```bash
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
Add user to `docker` group:
```bash
sudo usermod -aG docker your_user
su - your_user
sudo reboot
```
Test:
```bash
docker run hello-world
```

#### 4.3.4. Install make and hostsed
```bash
sudo apt-get install -y make hostsed
```

## 5. The Website

### 5.1. Copy files to the VM
1. Clone or copy the repository to the `shared` folder.
2. Copy the `.env` file (with your credentials) to `srcs` inside the VM.

### 5.2. Start the containers
1. In the project root, run `make up`.
2. In browser, open:
```bash
https://login.42.fr
```
Accept the certificate if self-signed.

### 5.3. Credential verification
1. If you try `http://login.42.fr` you may have problems (wrong port). Use HTTPS.
2. Click the lock in the address bar to see the certificate.
3. Access admin at `https://login.42.fr/wp-admin` and try to login with configured credentials.

### 5.4. MariaDB verification
In another terminal, enter the mariadb container:
```bash
docker exec -it mariadb /bin/bash
mysql -u your_user -p db_name
SHOW TABLES;
```
If you see tables, it's working. To exit: `exit`.

Congratulations — if you followed everything, the project is running!
