FROM php:8.4.20-apache AS builder

ARG MOODLE_HOME=/var/www/moodle
ARG MOODLEDATA=/var/www/moodledata
ARG MOODLE_TAG=v5.2.0

ENV MOODLE_HOME=${MOODLE_HOME} \
    MOODLEDATA=${MOODLEDATA} \
    MOODLE_TAG=${MOODLE_TAG}

RUN apt-get update && apt-get install -y --no-install-recommends \
    git=1:2.47.3-0+deb13u1 \
    pkg-config=1.8.1-4 \
    libpng-dev=1.6.48-1+deb13u4 \
    libjpeg62-turbo-dev=1:2.1.5-4 \
    libfreetype6-dev=2.13.3+dfsg-1+deb13u1 \
    libzip-dev=1.11.3-2 \
    libxml2-dev=2.12.7+dfsg+really2.9.14-2.1+deb13u2 \
    libicu-dev=76.1-4 \
    libpq-dev=17.9-0+deb13u1 \
    libonig-dev=6.9.9-1+b1 \
    libcurl4-openssl-dev=8.14.1-2+deb13u2 \
    libmagickwand-dev=8:7.1.1.43+dfsg1-1+deb13u7 \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install "-j$(nproc)" \
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
    curl=8.14.1-2+deb13u2 \
    postgresql-client=17+278 \
    default-mysql-client=1.1.1 \
    graphviz=2.42.4-3 \
    ghostscript=10.05.1~dfsg-1+deb13u1 \
    aspell=0.60.8.1-4 \
    aspell-en=2020.12.07-0-1 \
    imagemagick=8:7.1.1.43+dfsg1-1+deb13u7 \
    libicu76=76.1-4 \
    libzip5=1.11.3-2 \
    libpng16-16=1.6.48-1+deb13u4 \
    libjpeg62-turbo=1:2.1.5-4 \
    libfreetype6=2.13.3+dfsg-1+deb13u1 \
    libxml2=2.12.7+dfsg+really2.9.14-2.1+deb13u2 \
    libpq5=17.9-0+deb13u1 \
    libonig5=6.9.9-1+b1 \
    libcurl4=8.14.1-2+deb13u2 \
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