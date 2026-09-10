FROM php:8.2-cli

# Install system dependencies and PDO pgsql extension
RUN apt-get update && apt-get install -y libpq-dev git unzip && \
    docker-php-ext-install pdo_pgsql pgsql && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy project files
COPY . .

# Install Composer dependencies
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
    rm composer-setup.php && \
    composer install --no-interaction --prefer-dist --optimize-autoloader

# Expose any needed ports (none for CLI)

# Default command to run the connection test script
CMD ["php", "./artisan"]
