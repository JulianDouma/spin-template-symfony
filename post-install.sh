#!/bin/bash

# Capture Spin Variables
SPIN_ACTION=${SPIN_ACTION:-"install"}
SPIN_PHP_VERSION="${SPIN_PHP_VERSION:-8.3}"
SPIN_PHP_VARIATION="${SPIN_PHP_VARIATION:-frankenphp}"
SPIN_PHP_DOCKER_INSTALLER_IMAGE="${SPIN_PHP_DOCKER_INSTALLER_IMAGE:-serversideup/php:${SPIN_PHP_VERSION}-cli}"
SPIN_PHP_DOCKER_BASE_IMAGE="${SPIN_PHP_DOCKER_BASE_IMAGE:-serversideup/php:${SPIN_PHP_VERSION}-frankenphp}"

# Set local path variables
project_dir=${SPIN_PROJECT_DIRECTORY:-"$(pwd)/template"}
template_src_dir=${SPIN_TEMPLATE_TEMPORARY_SRC_DIR:-"$(pwd)"}
php_dockerfile="Dockerfile"

###############################################
# Functions
###############################################

initialize_git_repository() {
    local current_dir=""
    current_dir=$(pwd)

    cd "$project_dir" || exit
    echo "Initializing Git repository..."
    git init

    cd "$current_dir" || exit
}

###############################################
# Main
###############################################

# Clear screen before starting
clear

# Append Symfony-specific .dockerignore entries (Spin creates the base file)
line_in_file --file "$project_dir/.dockerignore" \
    "**/*.log" \
    "**/*.php~" \
    "**/*.dist.php" \
    "**/*.dist" \
    "**/*.cache" \
    "**/.DS_Store" \
    ".env.*.local" \
    ".env.local" \
    ".env.local.php" \
    ".env.test" \
    "var/" \
    "vendor/" \
    "tests/" \
    "node_modules/" \
    "public/bundles/" \
    ".planning/"

# Patch Dockerfile ARG defaults to match user selections
line_in_file --action replace \
    --file "$project_dir/$php_dockerfile" \
    'ARG PHP_VERSION=' \
    "ARG PHP_VERSION=\"${SPIN_PHP_VERSION}\""

line_in_file --action replace \
    --file "$project_dir/$php_dockerfile" \
    'ARG PHP_VARIATION=' \
    "ARG PHP_VARIATION=\"${SPIN_PHP_VARIATION}\""

line_in_file --action replace \
    --file "$project_dir/$php_dockerfile" \
    'ARG PHP_OS_SUFFIX=' \
    "ARG PHP_OS_SUFFIX=\"${PHP_OS_SUFFIX}\""

# Patch Traefik prod labels and env vars for fpm-nginx / fpm-apache (FrankenPHP is shipped default)
if [[ "$SPIN_PHP_VARIATION" != "frankenphp" ]]; then
    line_in_file --action replace \
        --file "$project_dir/docker-compose.prod.yml" \
        'traefik.http.services.symfony.loadbalancer.server.port=' \
        '      - "traefik.http.services.symfony.loadbalancer.server.port=8080"'

    line_in_file --action replace \
        --file "$project_dir/docker-compose.prod.yml" \
        'traefik.http.services.symfony.loadbalancer.server.scheme=' \
        '      - "traefik.http.services.symfony.loadbalancer.server.scheme=http"'

    line_in_file --action replace \
        --file "$project_dir/docker-compose.prod.yml" \
        'traefik.http.services.symfony.loadbalancer.healthcheck.scheme=' \
        '      - "traefik.http.services.symfony.loadbalancer.healthcheck.scheme=http"'

    if [[ "$SPIN_PHP_VARIATION" == "fpm-nginx" ]]; then
        line_in_file --action replace \
            --file "$project_dir/docker-compose.dev.yml" \
            'CADDY_SERVER_ROOT:' \
            '      NGINX_WEBROOT: /var/www/html/public'

        line_in_file --action replace \
            --file "$project_dir/docker-compose.prod.yml" \
            'CADDY_SERVER_ROOT:' \
            '      NGINX_WEBROOT: "/var/www/html/public"'
    fi

    if [[ "$SPIN_PHP_VARIATION" == "fpm-apache" ]]; then
        line_in_file --action replace \
            --file "$project_dir/docker-compose.dev.yml" \
            'CADDY_SERVER_ROOT:' \
            '      APACHE_DOCUMENT_ROOT: /var/www/html/public'

        line_in_file --action replace \
            --file "$project_dir/docker-compose.prod.yml" \
            'CADDY_SERVER_ROOT:' \
            '      APACHE_DOCUMENT_ROOT: "/var/www/html/public"'
    fi
fi

# Generate Symfony APP_SECRET (unconditional -- both new and init need it)
if [[ -f "$project_dir/.env" ]]; then
    APP_SECRET=$(openssl rand -hex 16)
    line_in_file --action replace \
        --file "$project_dir/.env" \
        'APP_SECRET=' \
        "APP_SECRET=${APP_SECRET}"
fi

# Install Composer dependencies
if [[ "$SPIN_INSTALL_DEPENDENCIES" == "true" ]]; then
    docker pull "$SPIN_PHP_DOCKER_INSTALLER_IMAGE"

    if [[ "$SPIN_ACTION" == "init" ]]; then
        echo "Re-installing composer dependencies..."
        docker compose run --rm --no-deps --build \
            -e COMPOSER_CACHE_DIR=/dev/null \
            -e "SHOW_WELCOME_MESSAGE=false" \
            php \
            composer install

        echo "Installing Spin..."
        docker compose run --rm --build --no-deps --remove-orphans \
            -e COMPOSER_CACHE_DIR=/dev/null \
            -e "SHOW_WELCOME_MESSAGE=false" \
            php \
            composer require serversideup/spin --dev
    else
        echo "Installing Spin..."
        docker run --rm \
            -v "$project_dir:/var/www/html" \
            --user "${SPIN_USER_ID}:${SPIN_GROUP_ID}" \
            -e COMPOSER_CACHE_DIR=/dev/null \
            -e "SHOW_WELCOME_MESSAGE=false" \
            "$SPIN_PHP_DOCKER_INSTALLER_IMAGE" \
            composer require serversideup/spin --dev
    fi
fi

# Patch server contact email in Traefik prod config (--ignore-missing: file is a Phase 4 deliverable)
line_in_file --action exact --ignore-missing \
    --file "$project_dir/.infrastructure/conf/traefik/prod/traefik.yml" \
    "changeme@example.com" \
    "$SERVER_CONTACT"

# Patch server contact email in .spin.yml (--ignore-missing: fetched by spin, may not contain placeholder)
line_in_file --action exact --ignore-missing \
    --file "$project_dir/.spin.yml" \
    "changeme@example.com" \
    "$SERVER_CONTACT"

# Initialize git repository if not already present
if [[ ! -d "$project_dir/.git" ]]; then
    initialize_git_repository
fi
