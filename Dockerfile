# Use official PHP image with Apache
FROM php:8.4.20-apache

# Set environment variables
ENV MOODLE_HOME=/var/www/moodle \
    MOODLEDATA=/var/moodledata

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    unzip \
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
    libmagickwand-dev \
    imagemagick \
    graphviz \
    aspell \
    aspell-en \
    ghostscript \
    postgresql-client \
    default-mysql-client \
    && rm -rf /var/lib/apt/lists/*

# Configure and install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install -j$(nproc) \
    bcmath \
    bz2 \
    curl \
    gd \
    gmp \
    iconv \
    intl \
    mbstring \
    mysqli \
    opcache \
    pdo \
    pdo_mysql \
    pdo_pgsql \
    pgsql \
    soap \
    xml \
    zip

# Install ImageMagick PHP extension
RUN pecl install imagick && docker-php-ext-enable imagick

# Configure PHP settings for Moodle
RUN { \
    echo "memory_limit = 512M"; \
    echo "upload_max_filesize = 200M"; \
    echo "post_max_size = 200M"; \
    echo "max_input_vars = 5000"; \
    echo "default_charset = utf-8"; \
    echo "date.timezone = UTC"; \
    echo "session.save_handler = files"; \
    echo "session.use_strict_mode = 1"; \
    } > /usr/local/etc/php/conf.d/moodle.ini

# Enable Apache modules
RUN a2enmod rewrite headers env ssl

# Create Moodle directories
RUN mkdir -p ${MOODLE_HOME} && \
    mkdir -p ${MOODLEDATA} && \
    chown -R www-data:www-data ${MOODLE_HOME} && \
    chown -R www-data:www-data ${MOODLEDATA} && \
    chmod 755 ${MOODLEDATA}

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Copy Moodle source code into container
COPY --chown=www-data:www-data --exclude=docker-entrypoint.sh . ${MOODLE_HOME}/

# Set working directory
WORKDIR ${MOODLE_HOME}

# Expose HTTP port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Run entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]