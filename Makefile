NAME		= inception
SRCS		= ./srcs
COMPOSE	= $(SRCS)/docker-compose.yml
HOST_URL	= pevieira.42.fr

# Optional: set DETACH=-d when calling make to run containers in background
DETACH ?=

.PHONY: up down

up:
	mkdir -p /home/${USER}/data/database
	mkdir -p /home/${USER}/data/wordpress_files
	sudo hostsed add 127.0.0.1 $(HOST_URL) || true
	docker compose -p $(NAME) -f $(COMPOSE) up $(DETACH) --build || (echo "Build or up failed" && exit 1)

down:
	sudo hostsed rm 127.0.0.1 $(HOST_URL) || true
	docker compose -p $(NAME) -f $(COMPOSE) down --volumes
