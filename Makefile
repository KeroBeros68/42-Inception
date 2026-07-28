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

DOCKER_COMPOSE := srcs/docker-compose.yml

# **************************************************************************** #
#									.PHONY									   #
# **************************************************************************** #

.PHONY: help run down re clean fclean

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
	$(ECHO) "$(CYAN)clean$(RESET) - Clean up the containers."
	$(ECHO) "$(CYAN)fclean$(RESET) - Force clean up the containers."
	$(ECHO) "$(CYAN)help$(RESET) - Show this help message."


# **************************************************************************** #
#									Rules									   #
# **************************************************************************** #

# ###		APP RULES 		### #

# Run the main program.
run:
	docker compose -f $(DOCKER_COMPOSE) up --build -d

down:
	docker compose -f $(DOCKER_COMPOSE) down

re: down run

# ###		CLEAN RULES 		### #

clean:
	$(ECHO) "$(CYAN)Suppression des conteneurs...$(RESET)"
	docker system prune -f 2>/dev/null

# Remove logs after cleaning.
fclean: clean
	$(ECHO) "$(CYAN)Suppression de tous les conteneurs...$(RESET) "
		docker system prune -af 2>/dev/null

# Database acces
db:
	docker exec -it inception_mariadb /bin/sh
	mysql -u root -p"$(cat /run/secrets/db_root_password)" wordpress -e "SELECT * FROM wp_comments;"
