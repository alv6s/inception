NAME		= inception
SRCS		= ./srcs
COMPOSE	= $(SRCS)/docker-compose.yml
HOST_URL	= pevieira.42.fr

.PHONY: up down

up:
	mkdir -p /home/${USER}/data/database
	mkdir -p /home/${USER}/data/wordpress_files
	sudo hostsed add 127.0.0.1 $(HOST_URL) || true
	docker compose -p $(NAME) -f $(COMPOSE) up --build || (echo "Build or up failed" && exit 1)

down:
	sudo hostsed rm 127.0.0.1 $(HOST_URL) || true
	docker compose -p $(NAME) -f $(COMPOSE) down --volumes


https://prod.liveshare.vsengsaas.visualstudio.com/join?A584DC23DE0F5E49BB848B75E2553E3AC6AA