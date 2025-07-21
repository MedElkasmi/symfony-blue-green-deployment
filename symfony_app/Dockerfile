
FROM php:8.2-apache
  
  # Set working directory
    WORKDIR /var/www/html

    # Install system dependencies and PHP extensions
    # We need git for composer to clone packages, zip/unzip for composer and project dependencies.
    # libpq-dev for PostgreSQL, or libmysqlclient-dev for MySQL/MariaDB (choose based on your DB, or install both).
    # libonig-dev for mbstring, libzip-dev for zip extension.
    RUN apt-get update && apt-get install -y \
        git \
        zip \
        unzip \
        libpq-dev \
        libzip-dev \
        && rm -rf /var/lib/apt/lists/* \
        && docker-php-ext-install pdo pdo_pgsql zip opcache \
        && a2enmod rewrite

    # Install Composer globally in the container
    COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

    # Copy the Symfony application code into the container
    COPY . /var/www/html/

    # Install Composer dependencies (including dev for initial scripts)
    # Explicitly set APP_ENV to prod for cache:clear to run in production mode
    RUN APP_ENV=prod composer install --optimize-autoloader

    # Remove dev dependencies and dump optimized autoloader for production
    # This ensures dev packages are available for pre-dump scripts (like cache:clear)
    # but removed for the final production image.
    RUN APP_ENV=prod composer install --no-dev --optimize-autoloader

    # Configure Apache Virtual Host for Symfony
    # Apache's default config points to /var/www/html. Symfony's entry point is /var/www/html/public.
    # We'll copy a custom Apache config for this.
    COPY docker/apache/symfony.conf /etc/apache2/sites-available/000-default.conf
    RUN a2ensite 000-default.conf && a2dissite 000-default # Ensure our config is enabled and default is disabled

    # Expose port (Apache listens on 80 by default)
    EXPOSE 80

    # The default Apache CMD handles starting the server
