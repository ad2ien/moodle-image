#!/bin/bash
set -e

MOODLE_HOME="/var/www/moodle"
MOODLEDATA="/var/www/moodledata"

# Get configuration from environment
DB_TYPE=${DB_TYPE:-pgsql}
DB_HOST=${DB_HOST:-db}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-moodle}
DB_USER=${DB_USER:-moodleuser}
DB_PASS=${DB_PASS:-moodlepass123}
ADMIN_PASS=${ADMIN_PASS:-Admin@123}
WWW_ROOT=${WWW_ROOT:-http://localhost}

echo "========================================="
echo "Moodle Docker Entrypoint"
echo "========================================="

# Fix permissions
echo "Setting up file permissions..."
chown -R www-data:www-data "${MOODLE_HOME}"
chown -R www-data:www-data "${MOODLEDATA}"
chmod 755 "${MOODLEDATA}"

# Generate config.php if it doesn't exist
if [ ! -f "${MOODLE_HOME}/public/config.php" ]; then
    echo "Generating config.php from config-dist.php..."
    
    if [ ! -f "${MOODLE_HOME}/public/config-dist.php" ]; then
        echo "ERROR: config-dist.php not found!"
        exit 1
    fi
    
    # Create config.php
    cp "${MOODLE_HOME}/public/config-dist.php" "${MOODLE_HOME}/public/config.php"
    
    # Use PHP to update config.php with proper quoting
    php << 'PHPEOD'
<?php
$configFile = getenv('MOODLE_HOME') . '/public/config.php';
$content = file_get_contents($configFile);

$dbtype = getenv('DB_TYPE') ?: 'pgsql';
$dbhost = getenv('DB_HOST') ?: 'postgres';
$dbport = getenv('DB_PORT') ?: '';
$dbname = getenv('DB_NAME') ?: 'moodle';
$dbuser = getenv('DB_USER') ?: 'moodleuser';
$dbpass = getenv('DB_PASS') ?: 'moodlepass123';
$moodledata = getenv('MOODLEDATA') ?: '/var/www/moodledata';
$wwwroot = getenv('WWW_ROOT') ?: 'http://localhost';
$moodlehome = getenv('MOODLE_HOME') ?: '/var/www/moodle';

// Replace database type
$content = preg_replace(
    '/\$CFG->dbtype\s*=\s*[\'"][^\'"]*[\'"];/',
    "\$CFG->dbtype    = '{$dbtype}';",
    $content
);

// Replace database host
$content = preg_replace(
    '/\$CFG->dbhost\s*=\s*[\'"][^\'"]*[\'"];/',
    "\$CFG->dbhost    = '{$dbhost}';",
    $content
);

// Replace database name
$content = preg_replace(
    '/\$CFG->dbname\s*=\s*[\'"][^\'"]*[\'"];/',
    "\$CFG->dbname    = '{$dbname}';",
    $content
);

// Replace database user
$content = preg_replace(
    '/\$CFG->dbuser\s*=\s*[\'"][^\'"]*[\'"];/',
    "\$CFG->dbuser    = '{$dbuser}';",
    $content
);

// Replace database password
$content = preg_replace(
    '/\$CFG->dbpass\s*=\s*[\'"][^\'"]*[\'"];/',
    "\$CFG->dbpass    = '{$dbpass}';",
    $content
);

// Handle dbport in dboptions array
if ($dbport) {
    if ($dbtype === 'pgsql' && $dbport === '5432') {
        // PostgreSQL default, leave empty
        $content = preg_replace(
            "/('dbport'\s*=>\s*)'[^']*'/",
            "\$1''",
            $content
        );
    } else {
        // Set custom port
        $content = preg_replace(
            "/('dbport'\s*=>\s*)'[^']*'/",
            "\$1'{$dbport}'",
            $content
        );
    }
}

// Add or replace wwwroot
if (preg_match('/\$CFG->wwwroot\s*=/', $content)) {
    $content = preg_replace(
        '/\$CFG->wwwroot\s*=\s*[\'"][^\'"]*[\'"];/',
        "\$CFG->wwwroot   = '{$wwwroot}';",
        $content
    );
} else {
    // Add after prefix
    $content = preg_replace(
        '/(\$CFG->prefix\s*=\s*[\'"][^\'"]*[\'"];)/',
        "\$1\n\n\$CFG->wwwroot   = '{$wwwroot}';",
        $content
    );
}

// Add or replace dataroot
if (preg_match('/\$CFG->dataroot\s*=/', $content)) {
    $content = preg_replace(
        '/\$CFG->dataroot\s*=\s*[\'"][^\'"]*[\'"];/',
        "\$CFG->dataroot  = '{$moodledata}';",
        $content
    );
} else {
    // Add after wwwroot
    $content = preg_replace(
        '/(\$CFG->wwwroot\s*=\s*[\'"][^\'"]*[\'"];)/',
        "\$1\n\n\$CFG->dataroot  = '{$moodledata}';",
        $content
    );
}

// Add or replace dirroot
if (preg_match('/\$CFG->dirroot\s*=/', $content)) {
    $content = preg_replace(
        '/\$CFG->dirroot\s*=\s*[\'"][^\'"]*[\'"];/',
        "\$CFG->dirroot   = '{$moodlehome}';",
        $content
    );
} else {
    // Add after dataroot
    $content = preg_replace(
        '/(\$CFG->dataroot\s*=\s*[\'"][^\'"]*[\'"];)/',
        "\$1\n\n\$CFG->dirroot   = '{$moodlehome}';",
        $content
    );
}

// Add or replace libdir
$libdir = $moodlehome . '/lib';
if (preg_match('/\$CFG->libdir\s*=/', $content)) {
    $content = preg_replace(
        '/\$CFG->libdir\s*=\s*[\'"][^\'"]*[\'"];/',
        "\$CFG->libdir    = '{$libdir}';",
        $content
    );
} else {
    // Add after dirroot
    $content = preg_replace(
        '/(\$CFG->dirroot\s*=\s*[\'"][^\'"]*[\'"];)/',
        "\$1\n\n\$CFG->libdir    = '{$libdir}';",
        $content
    );
}

file_put_contents($configFile, $content);
echo "config.php configured successfully\n";
?>
PHPEOD

    # Set proper permissions
    chown www-data:www-data "${MOODLE_HOME}/public/config.php"
    chmod 600 "${MOODLE_HOME}/public/config.php"
    
    echo ""
    echo "========================================="
    echo "Configuration Summary:"
    echo "Database Type: ${DB_TYPE}"
    echo "Database Host: ${DB_HOST}:${DB_PORT}"
    echo "Database Name: ${DB_NAME}"
    echo "Database User: ${DB_USER}"
    echo "Site URL: ${WWW_ROOT}"
    echo "Moodle Home: ${MOODLE_HOME}"
    echo "Moodle Data: ${MOODLEDATA}"
    echo "========================================="
    echo ""
else
    echo "config.php already exists, skipping generation"
fi

# Configure PHP settings from environment variables
echo ""
echo "Configuring PHP settings..."
PHP_MEMORY_LIMIT=${PHP_MEMORY_LIMIT:-512M}
PHP_UPLOAD_MAX_FILESIZE=${PHP_UPLOAD_MAX_FILESIZE:-200M}
PHP_POST_MAX_SIZE=${PHP_POST_MAX_SIZE:-200M}
PHP_MAX_INPUT_VARS=${PHP_MAX_INPUT_VARS:-5000}
PHP_MAX_EXECUTION_TIME=${PHP_MAX_EXECUTION_TIME:-300}

{
    echo "memory_limit = ${PHP_MEMORY_LIMIT}"
    echo "upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE}"
    echo "post_max_size = ${PHP_POST_MAX_SIZE}"
    echo "max_input_vars = ${PHP_MAX_INPUT_VARS}"
    echo "max_execution_time = ${PHP_MAX_EXECUTION_TIME}"
    echo "default_charset = utf-8"
    echo "date.timezone = UTC"
    echo "session.save_handler = files"
    echo "session.use_strict_mode = 1"
} > /usr/local/etc/php/conf.d/moodle.ini

# Wait for database to be ready
echo "Waiting for database to be available..."
if [ "$DB_TYPE" = "pgsql" ]; then
    export PGPASSWORD="${DB_PASS}"
    while ! pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME"  > /dev/null 2>&1; do
        echo "  Database not ready, waiting..."
        sleep 2
    done
    echo "Database is ready!"
    
    # Check if Moodle tables exist
    TABLE_COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';" | xargs)
    if ! echo "$TABLE_COUNT" | grep -qE '^[0-9]+$'; then
        TABLE_COUNT="0"
    fi
    if [ "$TABLE_COUNT" -eq 0 ]; then
        echo "Database is empty, running Moodle installer..."
        cd "${MOODLE_HOME}/admin/cli"
        php install_database.php \
            --adminpass="${ADMIN_PASS}" \
            --agree-license
        if [ $? -eq 0 ]; then
            echo "Moodle installation completed successfully!"
        else
            echo "WARNING: Moodle installation may have failed. Check logs above."
        fi
    else
        echo "Database already initialized with $TABLE_COUNT tables, skipping installation"
    fi
elif [ "$DB_TYPE" = "mysqli" ] || [ "$DB_TYPE" = "mariadb" ]; then
    while ! mysqladmin ping -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" > /dev/null 2>&1; do
        echo "  Database not ready, waiting..."
        sleep 2
    done
    echo "Database is ready!"
    
    # Check if Moodle tables exist
    TABLE_COUNT=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -D "$DB_NAME" -se "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME';" 2>/dev/null || echo "0")
    
    if [ "$TABLE_COUNT" -eq 0 ]; then
        echo "Database is empty, running Moodle installer..."
        cd "${MOODLE_HOME}/admin/cli"
        php install_database.php \
            --adminpass="${ADMIN_PASS}" \
            --agree-license
        if [ $? -eq 0 ]; then
            echo "Moodle installation completed successfully!"
        else
            echo "WARNING: Moodle installation may have failed. Check logs above."
        fi
    else
        echo "Database already initialized with $TABLE_COUNT tables, skipping installation"
    fi
fi



# Configure Apache VirtualHost from environment variables
echo "Configuring Apache VirtualHost..."
SERVERNAME=${WWW_ROOT#http://}
SERVERNAME=${SERVERNAME#https://}
SERVERNAME=${SERVERNAME%%/*}

[ -f /etc/apache2/sites-enabled/000-default.conf ] && rm /etc/apache2/sites-enabled/000-default.conf

{
    echo '<VirtualHost *:80>'
    echo "    ServerName ${SERVERNAME}"
    echo '    ServerAdmin admin@moodle.local'
    echo "    DocumentRoot ${MOODLE_HOME}/public"
    echo ''
    echo "    <Directory ${MOODLE_HOME}/public>"
    echo '        Options -Indexes +FollowSymLinks'
    echo '        AllowOverride All'
    echo '        Require all granted'
    echo '    </Directory>'
    echo ''
    echo '    # Protect moodledata directory'
    echo "    <Directory ${MOODLEDATA}>"
    echo '        Require all denied'
    echo '    </Directory>'
    echo ''
    echo '    # Security headers'
    echo '    Header always set X-Content-Type-Options "nosniff"'
    echo '    Header always set X-Frame-Options "SAMEORIGIN"'
    echo '    Header always set X-XSS-Protection "1; mode=block"'
    echo ''
    echo '    ErrorLog ${APACHE_LOG_DIR}/moodle-error.log'
    echo '    CustomLog ${APACHE_LOG_DIR}/moodle-access.log combined'
    echo '</VirtualHost>'
} > /etc/apache2/sites-available/moodle.conf

# Enable Apache modules and site
a2enmod rewrite headers env ssl > /dev/null 2>&1
a2ensite moodle > /dev/null 2>&1

echo ""
echo "========================================="
echo "PHP Configuration:"
echo "  Memory Limit: ${PHP_MEMORY_LIMIT}"
echo "  Upload Max Size: ${PHP_UPLOAD_MAX_FILESIZE}"
echo "  POST Max Size: ${PHP_POST_MAX_SIZE}"
echo "  Max Input Vars: ${PHP_MAX_INPUT_VARS}"
echo "========================================="
echo "Apache Configuration:"
echo "  Server Name: ${SERVERNAME}"
echo "  Document Root: ${MOODLE_HOME}/public"
echo "========================================="
echo ""
echo "Starting Apache..."
exec apache2-foreground