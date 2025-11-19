# Inception

Este projecto é uma introdução ao mundo DevOps. O seu propósito é apresentar o uso do Docker e do Docker Compose para desplegar um pequeno servidor web que usa o servidor NGINX com um site WordPress e uma base de dados MariaDB. É um projecto simples, mas é muito importante para entender os conceitos básicos de DevOps.

## Nota: Pontuação: 100/100

# Guia Inception

Este projecto vai cobrir conceitos que não vimos anteriormente, por isso recomendo que o testes primeiro no teu PC (do mais simples ao mais complexo) e depois na VM. Nesta página deixo um guia que seguirá essa ordem. No fim, terás uma VM com Docker e Docker Compose instalados, e serás capaz de desplegar um site WordPress com uma base de dados MariaDB hospedada com o servidor NGINX.

## Índice
- [1. Os Contêineres](#1-os-contentores)
	- [1.1. MariaDB](#11-mariadb)
		- [1.1.1. Dockerfile](#111-dockerfile)
		- [1.1.2. 50-server.cnf](#112-50-servercnf)
		- [1.1.3. setup.sh](#113-setupsh)
		- [1.1.4. Testar o contêiner mariadb](#114-testar-o-container-mariadb)
	- [1.2. WordPress](#12-wordpress)
		- [1.2.1. Dockerfile](#121-dockerfile)
		- [1.2.2. www.conf](#122-wwwconf)
		- [1.2.3. wp-config.php](#123-wp-configphp)
		- [1.2.4. setup.sh](#124-setupsh)
		- [1.2.5. Testar o contêiner wordpress](#125-testar-o-container-wordpress)
	- [1.3. NGINX](#13-nginx)
		- [1.3.1. O Dockerfile](#131-o-dockerfile)
		- [1.3.2. server.conf](#132-serverconf)
		- [1.3.3. nginx.conf](#133-nginxconf)
		- [1.3.4. Testar a imagem nginx](#134-testar-a-imagem-nginx)
- [2. Docker Compose](#2-docker-compose)
	- [2.1. docker-compose.yml](#21-docker-composeyml)
	- [2.2. .env](#22-env)
	- [2.3. teste do docker-compose](#23-docker-compose-teste)
- [3. O Makefile](#3-o-makefile)
- [4. A VM](#4-a-vm)
	- [4.1. Criação da VM](#41-vm-criacao)
	- [4.2. Instalação do Debian](#42-instalacao-debian)
	- [4.3. Configuração da VM](#43-vm-setup)
		- [4.3.1. Adicionar user ao sudo](#431-adicionar-user-ao-sudo)
		- [4.3.2. Habilitar Pastas Partilhadas](#432-habilitar-pastas-partilhadas)
		- [4.3.3. Instalar Docker e docker-compose](#433-instalar-docker-e-docker-compose)
		- [4.3.4. Instalar make e hostsed](#434-instalar-make-e-hostsed)
- [5. O Website](#5-o-website)
	- [5.1. Copiar os ficheiros para a VM](#51-copiar-os-ficheiros-para-a-vm)
	- [5.2. Iniciar os contêineres](#52-iniciar-os-containeres)
	- [5.3. Verificação de credenciais](#53-verificacao-de-credenciais)
	- [5.4. Verificação do MariaDB](#54-mariadb-check)


## 1. Os Contêineres

Em primeiro lugar, precisas de compreender o básico do `docker`. Deixo um guia que me ajudou com o Docker e a iniciar o meu primeiro contêiner.

Segue o link: https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-20-04

**PS:** Recomendo fortemente que sigas a parte do guia que explica como criar um utilizador não-root para usar o Docker. Isso será muito útil no futuro.

Agora, vamos criar os nossos próprios contêineres, um por serviço. Criaremos uma pasta com o nome do serviço; dentro dela criaremos o `Dockerfile` e as pastas `conf` e `tools` quando necessário.

Vou abordar os pontos importantes de cada serviço, mas dentro do repositório encontras os ficheiros com comentários para veres como funciona. Sempre que algo novo aparecer, tentarei explicar o que é; nas próximas vezes apenas mostrarei o comando. Portanto, os primeiros serviços terão mais explicações que os últimos.

**Aviso:** A disciplina pede que usemos a penúltima versão estável do Debian ou Alpine. Em setembro de 2023 a versão estável mais recente do Debian é a 12 (bookworm). Porque disso, utilizei o Debian 11 (bullseye) para todas as imagens.

### 1.1. MariaDB
Ficheiros: `Dockerfile`, `conf/50-server.cnf`, `tools/setup.sh`

#### 1.1.1. Dockerfile
1. Usar a imagem `debian:bullseye`:
```Dockerfile
FROM debian:bullseye
```
2. Indicar que o contêiner irá escutar na porta 3306:
```Dockerfile
EXPOSE 3306
```
3. Atualizar o sistema e instalar apenas `mariadb-server`. As flags `--no-install-recommends` e `--no-install-suggests` evitam instalar pacotes desnecessários. Uso `&&` para reduzir camadas. O `rm -rf /var/lib/apt/lists/*` limpa o cache do apt para não aumentar a imagem.
```Dockerfile
RUN apt update && \
    apt install -y --no-install-recommends --no-install-suggests \
    mariadb-server && \
    rm -rf /var/lib/apt/lists/*
```
4. Copiar o ficheiro de configuração para o contêiner:
```Dockerfile
COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/
```
5. Copiar o script de setup para o contêiner e alterar permissões:
```Dockerfile
COPY tools/setup.sh /bin/
RUN chmod +x /bin/setup.sh
```
6. Executar o script de setup e depois arrancar o servidor de BD (`mysqld_safe`):
```Dockerfile
CMD ["setup.sh", "mysqld_safe"]
```

#### 1.1.2. 50-server.cnf
É um ficheiro padrão sem linhas comentadas. A parte importante é alterar `port=3306` se necessário.

#### 1.1.3. setup.sh
1. Iniciar o servidor MariaDB:
```bash
service mariadb start
```
2. Para testar localmente declaramos variáveis neste script, mas na versão final usaremos o ficheiro `.env`. Remove essas declarações depois.
```bash
DB_NAME=thedatabase
DB_USER=theuser
DB_PASSWORD=abc
DB_PASS_ROOT=123
```
3. Criar a base de dados e os utilizadores com as permissões:
```bash
mariadb -v -u root << EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO 'root'@'%' IDENTIFIED BY '$DB_PASS_ROOT';
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$DB_PASS_ROOT');
EOF
```
4. Preparar o reinício do servidor para aplicar alterações. `sleep` evita erros antes de parar o serviço:
```bash
sleep 5
service mariadb stop
```
5. Reiniciar o servidor com o comando passado como argumento no `Dockerfile`:
```bash
exec $@
```

#### 1.1.4. Testar o contêiner mariadb
No directório `mariadb`, constrói a imagem e corre-a:
```bash
docker build -t mariadb .
docker run -d mariadb
```
Verifica se está a correr:
```bash
docker ps -a
```
Entrar no contêiner:
```bash
docker exec -it <ID> /bin/bash
```
Dentro do contêiner testa a BD:
```bash
mysql -u theuser -p thedatabase
```
Se vires o prompt `MariaDB [thedatabase]>` está ok. Para sair `exit`.

Limpar contêineres/images de teste:
```bash
docker rm -f $(docker ps -aq) && docker rmi -f $(docker images -aq)
```

### 1.2. WordPress
Ficheiros: `Dockerfile`, `conf/wp-config.php`, `conf/www.conf`, `tools/setup.sh`

#### 1.2.1. Dockerfile
1. Usar `debian:bullseye`.
2. Indica que o contêiner escutará em 9000.
3. Definir `ARG` para usar no build:
```Dockerfile
ARG PHPPATH=/etc/php/7.4/fpm
```
4. Atualizar e instalar `ca-certificates`, `php7.4-fpm`, `php7.4-mysql`, `wget` e `tar`.
5. Depois da instalação do PHP, o serviço pode estar a correr, por isso pará-lo para alterar configurações:
```Dockerfile
RUN service php7.4-fpm stop
```
6. Copiar a configuração do pool e aplicar alterações:
```Dockerfile
COPY conf/www.conf ${PHPPATH}/pool.d/
RUN sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' ${PHPPATH}/php.ini && \
    sed -i "s/listen = \/run\/php\/php$PHP_VERSION_ENV-fpm.sock/listen = 9000/g" ${PHPPATH}/pool.d/www.conf && \
    sed -i 's/;listen.mode = 0660/listen.mode = 0660/g' ${PHPPATH}/pool.d/www.conf && \
    sed -i 's/;daemonize = yes/daemonize = no/g' ${PHPPATH}/pool.d/www.conf
```
7. Descarregar o WP-CLI e torná-lo executável:
```Dockerfile
RUN wget --no-check-certificate https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp
```
8. Criar pastas necessárias e ajustar proprietário:
```Dockerfile
RUN mkdir -p /run/php/ /var/run/php/ /var/www/inception/
RUN chown -R www-data:www-data /var/www/inception/
```
9. Copiar `wp-config.php` e o script de setup e dar permissões:
10. Executar o script de setup e iniciar o PHP em foreground:
```Dockerfile
CMD ["setup.sh", "php-fpm7.4", "--nodaemonize"]
```

#### 1.2.2. www.conf
Ficheiro padrão - alterações importantes: utilizador, grupo e porta:
```conf
user = www-data
group = www-data
listen = 9000
```

#### 1.2.3. wp-config.php
Ficheiro padrão. O importante é usar as variáveis de ambiente para a BD e a URL:
```php
define( 'DB_NAME', getenv('DB_NAME') );
define( 'DB_USER', getenv('DB_USER') );
// etc...
```

#### 1.2.4. setup.sh
1. Corrigir proprietário dos ficheiros para `www-data`:
```bash
chown -R www-data:www-data /var/www/inception/
```
2. Mover `wp-config.php` se necessário.
3. Definir variáveis temporárias (depois usar `.env`).
4. Descarregar ficheiros do WordPress:
```bash
sleep 10
wp --allow-root --path="/var/www/inception/" core download || true
```
5. Se não estiver instalado, executar a instalação com `wp core install`.
6. Criar o utilizador não-admin.
7. Instalar e activar um tema (opcional).
8. Iniciar o PHP em foreground com `exec $@`.

#### 1.2.5. Testar o contêiner WordPress
No directório `wordpress` construir e correr a imagem:
```bash
docker build -t wordpress .
docker run -d wordpress
docker ps -a
docker exec -it <ID> /bin/bash
```
Verificar ficheiros:
```bash
sleep 30 && ls /var/www/inception/
```
Se os ficheiros estiverem lá, está ok. Limpar testes:
```bash
docker rm -f $(docker ps -aq) && docker rmi -f $(docker images -aq)
```

### 1.3. NGINX
Ficheiros: `Dockerfile`, `conf/server.conf`, `conf/nginx.conf`

#### 1.3.1. O Dockerfile
1. Usar `debian:bullseye`.
2. Indicar que o contêiner escutará na porta 443.
3. Atualizar e instalar `nginx` e `openssl`.
4. Definir `ARG` para os certificados (no final usar `.env`).
5. Criar pasta e gerar certificado auto-assinado:
```Dockerfile
RUN mkdir -p ${CERT_FOLDER} && \
    openssl req -newkey rsa:4096 -x509 -sha256 -days 365 -nodes \
    -out ${CERTIFICATE} \
    -keyout ${KEY} \
    -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCALITY}/O=${ORGANIZATION}/OU=${UNIT}/CN=${COMMON_NAME}"
```
6. Copiar ficheiros de configuração e completar `server.conf` com as variáveis:
7. Criar `/var/www/` e ajustar proprietário para `www-data`.
8. Iniciar o Nginx em foreground.

#### 1.3.2. server.conf
Configurar para `listen 443 ssl;`, `ssl_protocols TLSv1.2;` e `root /var/www/inception/;`.
No final do ficheiro adicionam-se as linhas geradas no Dockerfile para os certificados.

#### 1.3.3. nginx.conf
Definir `user www-data;` e upstream para comunicar com o php-fpm na porta 9000:
```conf
user www-data;
upstream php7.4-fpm {
    server wordpress:9000;
}
```

#### 1.3.4. Testar a imagem nginx
No directório `nginx`:
```bash
docker build -t nginx .
docker images
docker rmi -f nginx
```

## 2. Docker Compose

Depois de teres as Dockerfiles a funcionar, criamos o `docker-compose.yml` para correr tudo junto.
Verifica se tens o plugin do `docker compose` instalado:
```bash
docker compose version
```
Se não estiver, instala:
```bash
sudo apt-get install docker-compose-plugin
```

Ficheiros importantes: a pasta `requirements`, `docker-compose.yml` e o ficheiro `.env`.

### 2.1. docker-compose.yml
Começa com `services:` e define cada serviço (mariadb, wordpress, nginx) com `build`, `volumes`, `networks`, `init`, `restart` e `env_file`.

As secções de `volumes` montam pastas do host para persistência (ex.: `~/data/database` e `~/data/wordpress_files`).

A secção `networks` define uma rede bridge chamada `all`.

### 2.2. .env
Este ficheiro contém variáveis utilizadas pelo `docker-compose`. Nunca publiques ficheiros com informação confidencial. Exemplos de variáveis:
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

### 2.3. teste do docker-compose
No directório com o `docker-compose.yml` executa:
```bash
docker compose up
```
Se tudo estiver correto verás os contêineres a correr e o terminal ficará anexado aos logs. Para testar, abre no browser:
```bash
https://localhost
```
Se aparecer a página WordPress está tudo ok. Para limpar os testes, pára com `Ctrl+C` e executa os comandos de limpeza fornecidos.

## 3. O Makefile

Cria uma pasta `srcs` e coloca lá todos os ficheiros.
Instala `hostsed` para facilitar a adição do URL ao `/etc/hosts`:
```bash
sudo apt-get install hostsed
```

Um `Makefile` simples deve ter pelo menos dois alvos: `up` e `down`. Exemplo:
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

Usa `make up` para subir e `make down` para parar.

## 4. A VM

Esta fase tem vários passos para deixares a VM pronta.

### 4.1. Criação da VM
1. Descarrega a imagem do Debian (ex.: Debian 11).
2. No VirtualBox cria uma nova VM Linux Debian 64 bits.
3. RAM: 4096 MB.
4. Disco: VDI dinâmico, pelo menos 30 GB.
5. Ordem de arranque: Optical, Hard Disk, Network.
6. CPU: 4 processadores.
7. Vídeo: 128 MB.
8. Áudio: desactivado.
9. Rede: NAT.
10. Seleciona a ISO e arranca a VM.

### 4.2. Instalação do Debian
1. Selecciona "install" e segue os passos habituais.
2. Em particionamento escolhe "guided - use entire disk - LVM".
3. Nas opções de software escolhe XFCE, Webserver, SSH server e utilitários padrão.
4. Instala o GRUB no disco.

### 4.3. Configuração da VM

#### 4.3.1. Adicionar user ao sudo
```bash
su -
usermod -aG sudo user
sudo visudo
# adicionar no fim:
user ALL=(ALL) ALL
```
Reinicia a VM.

#### 4.3.2. Habilitar a pasta partilhada
1. No PC cria uma pasta `shared` no teu home.
2. Em VirtualBox > Shared Folders adiciona essa pasta com auto-mount e make permanent.
3. No VM insere o Guest Additions e instala:
```bash
sudo sh VBoxLinuxAdditions.run
sudo reboot
```
4. Adiciona o utilizador ao grupo `vboxsf` e altera dono da pasta montada:
```bash
sudo usermod -a -G vboxsf your_user
sudo chown -R your_user:users /media/
```
5. Faz logout/login.

#### 4.3.3. Instalar Docker e docker-compose
Preparar repositório do Docker e instalar:
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
Adicionar o utilizador ao grupo `docker`:
```bash
sudo usermod -aG docker your_user
su - your_user
sudo reboot
```
Testar:
```bash
docker run hello-world
```

#### 4.3.4. Instalar make e hostsed
```bash
sudo apt-get install -y make hostsed
```

## 5. O Website

### 5.1. Copiar os ficheiros para a VM
1. Clona ou copia o repositório para a pasta `shared`.
2. Copia o ficheiro `.env` (com as tuas credenciais) para `srcs` dentro da VM.

### 5.2. Iniciar os contêineres
1. No root do projecto executa `make up`.
2. No browser abre:
```bash
https://login.42.fr
```
Aceita o certificado se for auto-assinado.

### 5.3. Verificação de credenciais
1. Se tentares `http://login.42.fr` poderás ter problemas (porta errada). Usa HTTPS.
2. Clica no cadeado na barra de endereço para ver o certificado.
3. Acede ao admin em `https://login.42.fr/wp-admin` e tenta fazer login com as credenciais configuradas.

### 5.4. Verificação do MariaDB
Noutro terminal, entra no contêiner mariadb:
```bash
docker exec -it mariadb /bin/bash
mysql -u your_user -p db_name
SHOW TABLES;
```
Se vires tabelas, está a funcionar. Para sair `exit`.

Parabéns — se seguiste tudo, o projecto está a correr!
