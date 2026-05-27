FROM ubuntu:22.04

LABEL maintainer="EllieBytes"
LABEL description="Moodle LMS image."

ARG MOODLE_VERSION=MOODLE_404_STABLE
ARG MOODLE_DB_TYPE=mariadb
ARG PHP_VERSION=8.2

ENV DEBIAN_FRONTEND=noninteractive \
    MOODLE_VERSION=${MOODLE_VERSION} \
    MOODLE_WWW=/var/www/moodle \
    MOODLE_DATA=/var/moodledata \
    MOODLE_DB_TYPE=${MOODLE_DB_TYPE} \
    PHP_VERSION=${PHP_VERSION}

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificate \
    curl \
    git \
    unzip \
    zip \
    wget \
    gnupg \
    lsb-release \
    supervisor \
    cron \
    apache2 \
    php${PHP_VERSION} \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-pgsql \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-intl \
    php${PHP_VERSION}-soap \
    php${PHP_VERSION}-xmlrpc \
    php${PHP_VERSION}-redis \
    php${PHP_VERSION}-opcache \
    php${PHP_VERSION}-apcu \
    libapache2-mod-php${PHP_VERSION} \
    jq \
    && apt-get clean && rm -fr /var/lib/apt/list/*

RUN a2enmod rewrite headers expires deflate php${PHP_VERSION}
COPY config/apache-moodle.conf /etc/apache2/sites-available/moodle.conf
RUN a2dissite 000-default && a2ensite moodle

COPY config/php-moodle.ini /etc/php/${PHP_VERSION}/apache2/conf.d/99-moodle.ini
COPY config/php-moodle.ini /etc/php/${PHP_VERSION}/cli/conf.d/99-moodle.ini

RUN git clone --depth=1 \
    --branch ${MOODLE_VERSION} \
    https://github.com/moodle/moodle.git \
    ${MOODLE_WWW} \
    && chown -R www-data:www-data ${MOODLE_WWW}

RUN mkdir -p ${MOODLE_DATA} \
    && chown -R www-data:www-data ${MOODLE_DATA} \
    && chmod 0770 ${MOODLE_DATA}

COPY plugins/ tmp/bundled-plugins/

COPY plugins.json /etc/moodle/plugins.json

COPY scripts/install-plugins.sh /usr/local/bin/install-plugins
COPY scripts/bootstrap.sh /usr/local/bin/bootstrap
COPY scripts/cron.sh /usr/local/bin/moodle-cron
RUN chmod +x \
    /usr/local/bin/moodle-cron \
    /usr/local/bin/bootstrap \
    /usr/local/bin/install-plugins

COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN echo "*/1 * * * * www-data /usr/local/bin/moodle-cron >> /var/log/moodle-cron.log 2>&1" \
    > /etc/cron.d/moodle && chmod 0664 /etc/cron.d/moodle

VOLUME [ "${MOODLE_DATA}" ]

EXPOSE 80

ENTRYPOINT [ "/usr/local/bin/bootstrap" ]
