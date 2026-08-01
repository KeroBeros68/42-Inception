.SILENT:
.ONESHELL:
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# **************************************************************************** #
#                                   COLORS                                     #
# **************************************************************************** #

GREEN   := \033[0;32m
RED     := \033[0;31m
YELLOW  := \033[0;33m
BLUE    := \033[0;34m
MAGENTA := \033[0;35m
CYAN    := \033[0;36m
RESET   := \033[0m

ECHO    := echo -e

# **************************************************************************** #
#                                  VARIABLES                                   #
# **************************************************************************** #

-include srcs/.env

DOCKER_COMPOSE := srcs/docker-compose.yml

# **************************************************************************** #
#									.PHONY									   #
# **************************************************************************** #

.PHONY: all help run down re clean fclean db

.DEFAULT_GOAL := all

# **************************************************************************** #
#									Help								  	   #
# **************************************************************************** #

# Show available make commands.
help:
	$(ECHO) "$(YELLOW)Available commands:$(RESET)"
	$(ECHO) ""
	$(ECHO) "$(CYAN)run$(RESET) - Run the main program."
	$(ECHO) "$(CYAN)down$(RESET) - Stop the running containers."
	$(ECHO) "$(CYAN)re$(RESET) - Restart the main program."
	$(ECHO) "$(CYAN)clean$(RESET) - Stop containers and remove this project's images/volumes."
	$(ECHO) "$(CYAN)fclean$(RESET) - Same as clean, plus a full Docker system prune."
	$(ECHO) "$(CYAN)db$(RESET) - Open a MySQL shell on the wordpress database."
	$(ECHO) "$(CYAN)help$(RESET) - Show this help message."


# **************************************************************************** #
#									Rules									   #
# **************************************************************************** #

# ###		APP RULES 		### #

all: run

# Run the main program.
run:
	mkdir -p $(REDIS_DATA_PATH)
	mkdir -p $(MARIADB_DATA_PATH)
	mkdir -p $(WORDPRESS_DATA_PATH)
	touch secrets/db_root_password.txt
	touch secrets/db_password.txt
	touch secrets/wp_admin_password.txt
	touch secrets/wp_password.txt
	touch secrets/redis_password.txt
	touch secrets/ftp_password.txt
	docker compose -f $(DOCKER_COMPOSE) up --build -d

down:
	docker compose -f $(DOCKER_COMPOSE) down

re: down run

# ###		CLEAN RULES 		### #

clean:
	$(ECHO) "$(CYAN)Suppression des conteneurs, images et volumes du projet...$(RESET)"
	docker compose -f $(DOCKER_COMPOSE) down --rmi all --volumes --remove-orphans

# Also prune the whole Docker system (affects images/containers outside this project too).
fclean: clean
	$(ECHO) "$(CYAN)Nettoyage complet de Docker...$(RESET)"
	docker system prune -af 2>/dev/null

# Database access
db:
	docker exec -it inception_mariadb mariadb -u root -p"$$(cat /run/secrets/db_root_password)" wordpress -e "SELECT * FROM wp_comments;"
