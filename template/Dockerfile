############################################
# Build Arguments
############################################
ARG PHP_VERSION="8.5"
ARG PHP_VARIATION="frankenphp"
# PHP_OS_SUFFIX: "" for Debian (default), "-alpine" for Alpine
# NOTE: Docker's FROM line only supports literal ARG interpolation — no shell
# conditionals. The install.sh script (Phase 3) sets PHP_OS_SUFFIX="-alpine"
# when the user selects Alpine.
ARG PHP_OS_SUFFIX=""

############################################
# Base Image
############################################
# Learn more about the Server Side Up PHP Docker Images at:
# https://serversideup.net/open-source/docker-php/
FROM serversideup/php:${PHP_VERSION}-${PHP_VARIATION}${PHP_OS_SUFFIX} AS base

## Uncomment to install additional PHP extensions:
# USER root
# RUN install-php-extensions \
#     intl \
#     bcmath \
#     gd
# NOTE: FrankenPHP worker mode is incompatible with Xdebug for HTTP request
# debugging (only CLI commands work). If using fpm-nginx or fpm-apache,
# you can safely add xdebug here.
# USER www-data

############################################
# Development Image
############################################
FROM base AS development

# We can pass USER_ID and GROUP_ID as build arguments
# to ensure the www-data user has the same UID and GID
# as the user running Docker.
ARG USER_ID
ARG GROUP_ID

# Switch to root so we can set the user ID and group ID
USER root

# Set the user ID and group ID for www-data
RUN docker-php-serversideup-set-id www-data $USER_ID:$GROUP_ID && \
    docker-php-serversideup-set-file-permissions --owner $USER_ID:$GROUP_ID

# Drop privileges back to www-data
USER www-data

############################################
# CI Image
############################################
FROM base AS ci

# CI runs as root — sandboxed, short-lived environment (POLP acceptable)
USER root

############################################
# Deploy (Production/Staging) Image
############################################
FROM base AS deploy

ENV APP_ENV=prod

WORKDIR /var/www/html

# Layer-cached vendor install: copy lockfiles first so code changes don't
# bust the dependency installation layer
COPY --chown=www-data:www-data composer.json composer.lock ./
RUN composer install --no-dev --no-autoloader --no-scripts --no-progress

# Copy application code
COPY --chown=www-data:www-data . .

# Symfony production build sequence
# Source: https://symfony.com/doc/current/deployment.html
#         https://github.com/dunglas/symfony-docker
RUN composer dump-autoload --classmap-authoritative --no-dev && \
    composer dump-env prod && \
    composer run-script --no-dev post-install-cmd

# Uncomment to compile assets if using Symfony AssetMapper
# RUN if [ -f importmap.php ]; then php bin/console asset-map:compile; fi

# Install startup hook (cache warmup runs at container start, not build time,
# so that Redis/database/etc. are available when the cache is built)
COPY --chmod=755 .infrastructure/entrypoint.d/ /etc/entrypoint.d/

USER www-data
