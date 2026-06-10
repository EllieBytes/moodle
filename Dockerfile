FROM ubuntu:24.04

LABEL maintainer="EllieBytes" \
      moodle.version="5.2" \
      description="Moodle LMS, Made for Kenney's class, revamped for reusability"

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC

RUN apt-get update && apt-get install -y --no-install-recommends \
        # Base
        software-properties-common \
        ca-certificates \
        curl \
        git \
        unzip \
        tzdata \
        openssh-client \
        cron \
        gosu \
        apache2 \
        # PHP
        php \
        php-cli \
        php-common \
        php-mysql \
        php-xml \
        php-xmlrpc \
        php-curl \
        php-gd \
        php-mbstring \
        php-zip \
        php-intl \
        php-soap \
        php-opcache \
        php-readline \
        libapache2-mod-php \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

RUN { \
        echo "max_input_vars = 5000"; \
        echo "upload_max_filesize = 512M"; \
        echo "post_max_size = 512M"; \
        echo "memory_limit = 256M"; \
        echo "max_execution_time = 300"; \
        echo "date.timezone = UTC"; \
        echo "opcache.enable = 1"; \
        echo "opcache.memory_consumption = 128"; \
        echo "opcache.max_accelerated_files = 10000"; \
        echo "opcache.revalidate_freq = 60"; \
    } > /etc/php/8.3/apache2/conf.d/99-moodle.ini \
    && cp /etc/php/8.3/apache2/conf.d/99-moodle.ini \
       /etc/php/8.3/cli/conf.d/99-moodle.ini

COPY config/moodle-apache.conf /etc/apache2/sites-available/moodle.conf

RUN a2enmod rewrite \
    && a2dissite 000-default \
    && a2ensite moodle \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf

ARG MOODLE_VERSION=5.2
ARG MOODLE_BRANCH=MOODLE_52_STABLE

RUN git clone --depth=1 --branch ${MOODLE_BRANCH} \
        https://github.com/moodle/moodle.git /var/www/html/moodle \
    && chown -R www-data:www-data /var/www/html/moodle

COPY composer.json /var/www/html/moodle/composer.json
COPY config/config.php /var/www/html/moodle/config.php

RUN mkdir -p /var/moodledata \
    && chown www-data:www-data /var/moodledata \
    && chmod 770 /var/moodledata

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/moodle-cron.sh /usr/local/bin/moodle-cron.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/moodle-cron.sh

RUN echo "* * * * * www-data /usr/local/bin/moodle-cron.sh >> /var/log/moodle-cron.log 2>&1" \
        > /etc/cron.d/moodle \
    && chown root:root /etc/cron.d/moodle \
    && chmod 0600 /etc/cron.d/moodle

RUN chown www-data:www-data /var/www/html/moodle

VOLUME ["/var/moodledata"]

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
