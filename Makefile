# Makefile for managing a Docker Compose app with Traefik
# Usage examples:
#   make up
#   make logs
#   make logs s=traefik
#   make exec s=app c="php -v"
#   make shell s=app
#   make down V=1       # remove volumes as well
#   make restart s=traefik
#   make open-dashboard # tries to open DOMAIN in your browser

SHELL := /bin/bash

# Detect docker compose command (v2 or v1)
COMPOSE := $(shell if docker compose version >/dev/null 2>&1; then echo "docker compose"; else echo "docker-compose"; fi)

# Basic parameters (override with: make ... PROJECT_NAME=myproj COMPOSE_FILE=compose.yml)
PROJECT_NAME ?= $(notdir $(CURDIR))
COMPOSE_FILE ?= docker-compose.yaml
ENV_FILE ?= .env

# Helper: extract DOMAIN from .env if present
DOMAIN := $(shell sed -n 's/^DOMAIN=\(.*\)/\1/p' $(ENV_FILE) 2>/dev/null)

# Optional: service selector (e.g., make logs s=traefik)
s ?=
# Optional: command for exec (e.g., make exec s=app c="bash")
c ?=

# Remove volumes on down if V=1
V ?= 0
REMOVE_VOLUMES := $(if $(filter 1,$(V)),-v,)

# Compose base command
C := $(COMPOSE) -p $(PROJECT_NAME) -f $(COMPOSE_FILE)

.PHONY: help init up down restart start stop build pull ps status logs exec shell top events open-dashboard url doctor prune

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nAvailable targets:\n"} /^[a-zA-Z0-9_.-]+:.*##/ { printf "  %-18s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

init: ## Initialize local environment (.env from example if missing)
	@if [ ! -f "$(ENV_FILE)" ] && [ -f ".env.example" ]; then \
		cp .env.example $(ENV_FILE); \
		echo "Created $(ENV_FILE) from .env.example"; \
	else \
		echo "$(ENV_FILE) already exists or no .env.example found."; \
	fi

up: ## Start all services in the background
	@$(C) up -d

down: ## Stop and remove containers (use V=1 to remove volumes)
	@$(C) down $(REMOVE_VOLUMES)

restart: ## Restart services (optionally: s=service)
	@$(C) restart $(s)

start: ## Start stopped services (optionally: s=service)
	@$(C) start $(s)

stop: ## Stop running services (optionally: s=service)
	@$(C) stop $(s)

build: ## Build images (add flags via BUILD_ARGS="--no-cache --pull")
	@$(C) build $(BUILD_ARGS)

pull: ## Pull images
	@$(C) pull $(s)

ps: status ## Show service status
status: ## Show service status
	@$(C) ps

logs: ## Follow logs (optionally: s=service, add LARGS="-n 100" for tail lines)
	@$(C) logs -f $(LARGS) $(s)

top: ## Show running processes
	@$(C) top

events: ## Stream compose events
	@$(C) events

exec: ## Exec into a service and run command (requires s=service, c="command")
	@if [ -z "$(s)" ]; then echo "Usage: make exec s=service c=\"command\""; exit 2; fi
	@$(C) exec $(s) sh -lc '$(c)'

shell: ## Open an interactive shell in a service (requires s=service)
	@if [ -z "$(s)" ]; then echo "Usage: make shell s=service"; exit 2; fi
	@$(C) exec $(s) sh -lc 'command -v bash >/dev/null 2>&1 && exec bash || exec sh'

url: ## Print Traefik dashboard/entrypoint URL (from DOMAIN in .env)
	@if [ -n "$(DOMAIN)" ]; then \
		echo "https://$(DOMAIN)"; \
	else \
		echo "DOMAIN not set in $(ENV_FILE)."; \
	fi

open-dashboard: ## Try to open the DOMAIN URL in your browser
	@if [ -z "$(DOMAIN)" ]; then \
		echo "DOMAIN not set in $(ENV_FILE). Use: echo DOMAIN=example.com >> $(ENV_FILE)"; exit 2; \
	fi; \
	URL="https://$(DOMAIN)"; \
	echo "Opening $$URL ..."; \
	if command -v xdg-open >/dev/null 2>&1; then xdg-open $$URL >/dev/null 2>&1 & exit 0; fi; \
	if command -v open >/dev/null 2>&1; then open $$URL >/dev/null 2>&1 & exit 0; fi; \
	echo "Please open $$URL in your browser."

doctor: ## Quick diagnostics
	@echo "Compose cmd: $(COMPOSE)"
	@echo "Project:     $(PROJECT_NAME)"
	@echo "File:        $(COMPOSE_FILE)"
	@echo "Env file:    $(ENV_FILE) $$( [ -f "$(ENV_FILE)" ] && echo "(present)" || echo "(missing)" )"
	@echo "Domain:      $$( [ -n "$(DOMAIN)" ] && echo "$(DOMAIN)" || echo "(unset)" )"
	@echo "Docker:      $$( docker --version 2>/dev/null || echo "not found" )"
	@echo "Compose:     $$( $(COMPOSE) version 2>/dev/null || echo "not found" )"

prune: ## Prune unused Docker data (dangling images, networks, cache)
	@docker system prune -f