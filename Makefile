NAME		= inception
SRCS		= ./srcs
COMPOSE		= $(SRCS)/docker-compose.yml
HOST_URL	= pevieira.42.fr
ENV_FILE	= $(SRCS)/.env
DATA_VOLUME	= /home/${USER}/data
SECRETS		= db_password db_pass_root wp_admin_password wp_password

# Optional: set DETACH=-d when calling make to run containers in background
DETACH ?=

up:
	mkdir -p /home/${USER}/data/database
	mkdir -p /home/${USER}/data/wordpress_files
	@echo "Adding $(HOST_URL) to /etc/hosts if not present..."
	@grep -q "$(HOST_URL)" /etc/hosts || echo "127.0.0.1 $(HOST_URL)" | sudo tee -a /etc/hosts
	docker compose -p $(NAME) -f $(COMPOSE) up $(DETACH) --build || (echo "Build or up failed" && exit 1)

down:
	@echo "Stopping containers and removing volumes..."
	docker compose -p $(NAME) -f $(COMPOSE) down --volumes
	@echo "Removing $(HOST_URL) from /etc/hosts if present..."
	@sudo sed -i '/$(HOST_URL)/d' /etc/hosts || true

env:
	@if ! grep -q "127.0.0.1 $(HOST_URL)" /etc/hosts; then \
		echo "127.0.0.1 $(HOST_URL)" | sudo tee -a /etc/hosts; \
	fi
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "Creating $(ENV_FILE)"; \
		echo "" > $(ENV_FILE); \
		echo "DB_NAME=thedatabase" >> $(ENV_FILE); \
		echo "DB_USER=theuser" >> $(ENV_FILE); \
		echo "DB_HOST=mariadb" >> $(ENV_FILE); \
		echo "" >> $(ENV_FILE); \
		echo "# WordPress settings" >> $(ENV_FILE); \
		echo "WP_URL=$(HOST_URL)" >> $(ENV_FILE); \
		echo "WP_TITLE=Inception" >> $(ENV_FILE); \
		echo "WP_ADMIN_USER=theroot" >> $(ENV_FILE); \
		echo "WP_ADMIN_EMAIL=theroot@123.com" >> $(ENV_FILE); \
		echo "WP_USER=theuser" >> $(ENV_FILE); \
		echo "WP_EMAIL=theuser@123.com" >> $(ENV_FILE); \
		echo "WP_ROLE=editor" >> $(ENV_FILE); \
		echo "WP_FULL_URL=https://$(HOST_URL)" >> $(ENV_FILE); \
		echo "" >> $(ENV_FILE); \
		echo "# SSL settings (build args for nginx)" >> $(ENV_FILE); \
		echo "CERT_FOLDER=/etc/nginx/certs/" >> $(ENV_FILE); \
		echo "CERTIFICATE=/etc/nginx/certs/certificate.crt" >> $(ENV_FILE); \
		echo "KEY=/etc/nginx/certs/certificate.key" >> $(ENV_FILE); \
		echo "COUNTRY=PT" >> $(ENV_FILE); \
		echo "STATE=Porto" >> $(ENV_FILE); \
		echo "LOCALITY=Porto" >> $(ENV_FILE); \
		echo "ORGANIZATION=42" >> $(ENV_FILE); \
		echo "UNIT=42" >> $(ENV_FILE); \
		echo "COMMON_NAME=$(HOST_URL)" >> $(ENV_FILE); \
	fi
	@while IFS='=' read -r key value; do \
		printf "%-25s:%s\n" "$$key" "$$value" | sed 's/ /_/g'; \
	done < $(ENV_FILE)
	@echo ""
	@mkdir -p $(DATA_VOLUME)/secrets
	@for secret in $(SECRETS); do \
		if [ ! -f $(DATA_VOLUME)/secrets/$$secret ]; then \
			openssl rand -base64 12 | head -c 12 > $(DATA_VOLUME)/secrets/$$secret; \
		fi; \
		printf "%-25s:%s\n" "$$secret" "$$(cat $(DATA_VOLUME)/secrets/$$secret)" | sed 's/ /_/g'; \
	done


.PHONY: up down env