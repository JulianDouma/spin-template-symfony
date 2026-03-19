# Official Symfony Template by Spin

This is the official Spin template for Symfony that helps you get up and running with:

- Symfony 7 LTS
- Your choice of PHP runtime: FrankenPHP (default), fpm-nginx, or fpm-apache
- Traefik reverse proxy with automatic Let's Encrypt SSL
- Production-ready Docker Swarm deployment

## Default configuration

To use this template, you must have [Spin](https://serversideup.net/open-source/spin/docs) installed.

```bash
spin new symfony
```

By default, this template is configured to work with [`spin deploy`](https://serversideup.net/open-source/spin/docs/command-reference/deploy) out of the box.

Before running `spin deploy`, ensure you have completed the following:

1. **ALL** steps from the "Required Changes Before Using This Template" section have been completed
1. You've customized and have a valid [`.spin.yml`](https://serversideup.net/open-source/spin/docs/server-configuration/spin-yml-usage) file
1. You've customized and have a valid [`.spin-inventory.yml`](https://serversideup.net/open-source/spin/docs/guide/preparing-your-servers-for-spin#inventory) file
1. Your server is online and has been provisioned with [`spin provision`](https://serversideup.net/open-source/spin/docs/command-reference/provision)

Once the steps above are complete, you can run `spin deploy` to deploy your application:

```bash
spin deploy <environment-name>
```

### Default Development URL

- **Symfony**: [https://localhost](https://localhost)

## Required Changes Before Using This Template

> **You need to make changes before deploying this template to production.**

### Create an `.env.production` file

By default, this template is configured to use `spin deploy` which defaults to the `production` environment. You need to create an `.env.production` file in the root of your project.

```bash
cp .env.example .env.production
```

Configure your `.env.production` file with the appropriate values for your production environment. Ensure `APP_URL` is set correctly. Spin will use the domain from that variable as the production URL by default (`SPIN_APP_DOMAIN` is derived from `APP_URL`).

### Set your production URL

Almost everyone wants to run HTTPS with a valid certificate in production for free, and it's totally possible with Let's Encrypt. You'll need to let Let's Encrypt know which domain you are using.

> **Warning:** You must have your DNS configured correctly (with your provider like Cloudflare, Namecheap, etc) AND your server accessible to the outside world BEFORE running a deployment. When Let's Encrypt validates that you own the domain name, it will attempt to connect to your server over HTTP from the outside world using the [HTTP-01 challenge](https://letsencrypt.org/docs/challenge-types/). If your server is not accessible during this process, they will not issue a certificate.

By default, if you're using `spin deploy` it will use the `APP_URL` from your `.env.<environment>` file to generate the `SPIN_APP_DOMAIN`.

### Set your email contact for Let's Encrypt certificates

Let's Encrypt requires an email address to issue certificates. You can set this in the Traefik configuration for production.

```yml
# File to update:
# .infrastructure/conf/traefik/prod/traefik.yml

certificatesResolvers:
  letsencryptresolver:
    acme:
      email: "changeme@example.com"
```

Change `changeme@example.com` to a valid email address. This email address will be used by Let's Encrypt to send you notifications about your certificates.

## Running Symfony Commands

In development, you may want to run console commands or composer commands. Use [`spin run`](https://serversideup.net/open-source/spin/docs/command-reference/run) or [`spin exec`](https://serversideup.net/open-source/spin/docs/command-reference/exec) to run these commands.

```bash
spin run php php bin/console cache:clear
```

The above command will create a new container to run the `bin/console cache:clear` command. You can change `run` for `exec` if you'd like to run the command in an existing, running container.

```bash
spin run php composer install
```

The above command will create a new container to run the `composer install` command. This is helpful if you need to install new packages or update your `composer.lock` file.

If you need to attach your terminal to the container's shell, you can use `spin exec`:

```bash
spin exec -it php bash
```

This will attach your terminal to the `php` container's shell. If you're using an Alpine image, use `sh` instead of `bash`.

Feel free to run any commands you'd like with `spin run` or `spin exec`. The examples above should give you the patterns you need.

## Optional: Adding Mailpit for Email Testing

This template does not ship Mailpit by default to stay minimal and unopinionated. If you want to add Mailpit for local email testing, add the following service to your `docker-compose.dev.yml`:

```yaml
  mailpit:
    image: axllent/mailpit
    ports:
      - "8025:8025"
    networks:
      - development
```

Then set the following in your `.env`:

```bash
MAILER_DSN=smtp://mailpit:1025
```

The Mailpit web UI will be available at [http://localhost:8025](http://localhost:8025).

## Advanced Configuration

### Trusted SSL certificates in development

We provide certificates by default. If you'd like to trust these certificates, you need to install the CA on your machine.

**Download the CA Certificate:**

- https://serversideup.net/ca/

You can create your own certificate trust if you'd like. Simply replace the certificates with your own.

### Change the deployment image name

If you're using CI/CD (and NOT using `spin deploy`), you'll likely want to change the image name in the `docker-compose.prod.yml` file.

```yaml
  php:
    image: ${SPIN_IMAGE_DOCKERFILE} # Change this if you're not using `spin deploy`
```

Set this value to the published image in your image repository.

### Set the Traefik configuration MD5 hash

When running `spin deploy`, we automatically calculate the MD5 hash of the Traefik configuration and set it to `SPIN_MD5_HASH_TRAEFIK_YML`. This ensures your Docker Swarm config object is always up to date when `traefik.yml` changes.

```yaml
configs:
  traefik:
    name: "traefik-${SPIN_MD5_HASH_TRAEFIK_YML}.yml"
    file: ./.infrastructure/conf/traefik/prod/traefik.yml
```

### Switching PHP runtime after install

The template defaults to FrankenPHP. If you selected fpm-nginx or fpm-apache at install time, `post-install.sh` automatically patched the Traefik labels in `docker-compose.prod.yml`. If you need to switch runtimes manually after install, update the following:

1. **`template/Dockerfile`** — Change the `PHP_VARIATION` ARG to your desired runtime (`frankenphp`, `fpm-nginx`, `fpm-apache`)
2. **`template/docker-compose.prod.yml`** — Update the Traefik labels:
   - FrankenPHP: `loadbalancer.server.port=8443` and `loadbalancer.server.scheme=https`
   - fpm-nginx / fpm-apache: `loadbalancer.server.port=8080` and `loadbalancer.server.scheme=http`

## Resources

- **[Website](https://serversideup.net/open-source/spin/)** — Overview of the Spin project
- **[Docs](https://serversideup.net/open-source/spin/docs)** — Deep-dive on how to use Spin
- **[Discord](https://serversideup.net/discord)** — Friendly support from the community and team
- **[GitHub](https://github.com/serversideup/spin)** — Source code, bug reports, and project management
