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
