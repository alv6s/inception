
FROM	debian:bookworm

EXPOSE	3306

# Make APT non-interactive
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 install -y \
    --no-install-recommends --no-install-suggests --fix-missing mariadb-server && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY	conf/50-server.cnf /etc/mysql/mariadb.conf.d/

COPY	tools/setup.sh /bin/
RUN		chmod +x /bin/setup.sh

CMD		["setup.sh", "mysqld_safe"]