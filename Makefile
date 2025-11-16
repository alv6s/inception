NAME		= inception
SRCS		= ./srcs
COMPOSE	= $(SRCS)/docker-compose.yml
HOST_URL	= login.42.fr

.PHONY: up down

up:
	mkdir -p ~/data/database
	mkdir -p ~/data/wordpress_files
	sudo hostsed add 127.0.0.1 $(HOST_URL) || true
	docker compose -p $(NAME) -f $(COMPOSE) up --build || (echo "Build or up failed" && exit 1)

down:
	sudo hostsed rm 127.0.0.1 $(HOST_URL) || true
	docker compose -p $(NAME) -f $(COMPOSE) down --volumes
