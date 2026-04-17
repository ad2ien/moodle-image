FROM php:8.4.20-apache AS builder

ARG MOODLE_HOME=/var/www/moodle
ARG MOODLEDATA=/var/www/moodledata
ARG MOODLE_TAG=v5.1.3

ENV MOODLE_HOME=${MOODLE_HOME} \
    MOODLEDATA=${MOODLEDATA} \
    MOODLE_TAG=${MOODLE_TAG}

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    pkg-config \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libzip-dev \
    libxml2-dev \
    libicu-dev \
    libpq-dev \
    libonig-dev \
    libcurl4-openssl-dev \
    libmagickwand-dev

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install -j$(nproc) \
    bcmath bz2 curl gd gmp iconv intl mbstring mysqli opcache pdo \
    pdo_mysql pdo_pgsql pgsql soap xml zip

RUN pecl install imagick && docker-php-ext-enable imagick

# Clone Moodle
RUN git clone  --depth 1 --branch ${MOODLE_TAG} https://github.com/moodle/moodle.git ${MOODLE_HOME}

# Stage 2: Runtime (clean, minimal)
FROM php:8.4.20-apache

ARG MOODLE_HOME=/var/www/moodle
ARG MOODLEDATA=/var/www/moodledata

ENV MOODLE_HOME=${MOODLE_HOME} \
    MOODLEDATA=${MOODLEDATA}

# Only runtime dependencies (no -dev packages)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    postgresql-client \
    default-mysql-client \
    graphviz \
    ghostscript \
    aspell \
    aspell-en \
    imagemagick \
    libicu76 \
    libzip5 \
    libpng16-16 \
    libjpeg62-turbo \
    libfreetype6 \
    libxml2 \
    libpq5 \
    libonig5 \
    libcurl4 \
    && rm -rf /var/lib/apt/lists/*

# Copy PHP extensions from builder
COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# Copy Moodle with correct ownership during copy (more efficient than COPY then chown)
COPY --chown=www-data:www-data --from=builder ${MOODLE_HOME} ${MOODLE_HOME}

RUN a2enmod rewrite headers env ssl

# Create and set permissions for Moodle data directory
RUN mkdir -p ${MOODLEDATA} && \
    chown -R www-data:www-data ${MOODLEDATA} && \
    chmod 755 ${MOODLEDATA}

# Copy entrypoint script and set permissions
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR ${MOODLE_HOME}

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]