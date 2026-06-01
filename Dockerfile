FROM ubuntu:22.04

LABEL maintainer="EllieBytes" \
      moodle.version="5.2" \
      description="Moodle LMS, purpose designed for Kenney's Class."

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC

ARG PHP_VERSION=8.2

RUN apt-get update && apt-get install -y --no-install-recommends \
        software-properties-common \
        ca-certificates \
        curl \
        git \
        unzip \
        tzdata \
        cron \
        gosu \
        apache2 \
    && apt-add-repository ppa:ondrej/php -y \
    && apt-get-update && apt-get-install -y --no-install-reccommends \
        php${PHP_VERSION} \
        php${PHP_VERSION}-cli \
        php${PHP_VERSION}-common \
        php${PHP_VERSION}-mysql \
        php${PHP_VERSION}-xml \
        php${PHP_VERSION}-xmlrpc \
        php${PHP_VERSION}-curl \
        php${PHP_VERSION}-gd \
        php${PHP_VERSION}-mbstring \
        php${PHP_VERSION}-zip \
        php${PHP_VERSION}-intl \
        php${PHP_VERSION}-soap \
        php${PHP_VERSION}-opcache \
        php${PHP_VERSION}-readline \
        php${PHP_VERSION}-sodium \
        libapache2-mod-php${PHP_VERSION} \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

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
    } > /etc/php/${PHP_VERSION}/apache2/conf.d/99-moodle.ini \
    && cp /etc/php/${PHP_VERSION}/apache2/conf.d/99-moodle.ini \
       /etc/php/${PHP_VERSION}/cli/conf.d/99-moodle.ini

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

RUN mkdir -p /var/moodledata \
    && chown www-data:www-data /var/moodledata \
    && chmod 770 /var/moodledata

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/moodle-cron.sh /usr/local/bin/moodle-cron.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/moodle-cron.sh

RUN echo "* * * * * www-data /usr/local/bin/moodle-cron.sh >> /var/log/moodle-cron.log 2>&1" \
        > /etc/cron.d/moodle \
    && chmod 0644 /etc/cron.d/moodle

VOLUME ["/var/moodledata"]

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
