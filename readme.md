# A Docker image for Moodle

[![Gitmoji](https://img.shields.io/badge/gitmoji-%20😜%20😍-FFDD67.svg?logo=git)](https://gitmoji.dev)
![Docker](https://img.shields.io/badge/build-docker-%230db7ed.svg?logo=docker&logoColor=white)
[![License](https://img.shields.io/badge/📝%20License-GPL%203.0-blue.svg)](https://opensource.org/license/gpl-3.0)
[![Build status](https://img.shields.io/github/actions/workflow/status/ad2ien/moodle-image/build.yml?label=CI&logo=github)](https://github.com/ad2ien/moodle-image/actions)

A docker image for [Moodle](https://moodle.com/), a [learning management system](https://en.wikipedia.org/wiki/Learning_management_system)

Dockerfile there : <https://github.com/ad2ien/moodle-image>

```sh
docker pull ad2ien/moodle:latest
```

## Needed env variables

```bash
################################################################################
# Moodle Docker Environment Configuration
# Copy this file to .env and customize the values for your installation
################################################################################

# Database Configuration
################################################################################
# Database type: pgsql (PostgreSQL), mysqli (MySQL/MariaDB), mssql (SQL Server)
DB_TYPE=pgsql

# Database hostname/IP
DB_HOST=db

# Database port (5432 for PostgreSQL, 3306 for MySQL/MariaDB)
DB_PORT=5432

# Database name
DB_NAME=moodle

# Database username
DB_USER=moodleuser

# Database password
DB_PASS=moodlepass123

# Root/Admin password (for MariaDB initialization)
DB_ROOT_PASS=rootpass123


# Moodle Site Configuration
################################################################################
# Web root URL (change to your domain)
WWW_ROOT=http://localhost

# Web server port
WEB_PORT=80

# Site admin password (user: admin)
ADMIN_PASS=Admin@123

# Site admin email address
ADMIN_EMAIL=admin@moodle.local

# PHP Configuration
################################################################################
# Memory limit for PHP (recommended: 512M or higher)
PHP_MEMORY_LIMIT=512M

# Maximum file upload size
PHP_UPLOAD_MAX_FILESIZE=200M

# Maximum POST size
PHP_POST_MAX_SIZE=200M

# Maximum number of input variables
PHP_MAX_INPUT_VARS=5000

# Maximum script execution time (in seconds)
PHP_MAX_EXECUTION_TIME=300

# Logging Configuration
################################################################################
# Log level for debugging (optional)
# DEBUG_LEVEL=developer

```

## docker compose

```yml
services:
  db:
    image: postgres:18.3-alpine
    environment:
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASS}
      POSTGRES_INITDB_ARGS: "--encoding=UTF8 --locale=en_US.UTF-8"
    volumes:
      - postgres_data:/var/lib/postgresql/18/docker
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -d ${DB_NAME} -U ${DB_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  moodle:
    image: ad2ien/moodle:latest
    depends_on:
      db:
        condition: service_healthy
    env_file:
      - .env
    ports:
      - "${WEB_PORT}:80"
    volumes:
      # Persistent storage for user data
      - moodle_data:/var/www/moodledata
    restart: unless-stopped

volumes:
  postgres_data:
    driver: local
  moodle_data:
    driver: local
```
