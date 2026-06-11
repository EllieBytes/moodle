#!/usr/bin/env bash
set -euo pipefail

log()  { echo "[entrypoint] $*"; }
die()  { echo "[entrypoint] ERROR: $*" >&2; exit 1; }
php_cli() { gosu www-data php /var/www/html/moodle/admin/cli/"$@"; }
composer_cli() { gosu www-data composer --working-dir=/var/www/html/moodle "$@"; }

: "${MOODLE_DB_HOST:?Need MOODLE_DB_HOST}"
: "${MOODLE_DB_NAME:?Need MOODLE_DB_NAME}"
: "${MOODLE_DB_USER:?Need MOODLE_DB_USER}"
: "${MOODLE_DB_PASS:?Need MOODLE_DB_PASS}"
: "${MOODLE_WWWROOT:?Need MOODLE_WWWROOT}"
: "${MOODLE_ADMIN_USER:?Need MOODLE_ADMIN_USER}"
: "${MOODLE_ADMIN_PASS:?Need MOODLE_ADMIN_PASS}"
: "${MOODLE_ADMIN_EMAIL:?Need MOODLE_ADMIN_EMAIL}"

MOODLE_DB_PORT="${MOODLE_DB_PORT:-3306}"
MOODLE_DB_TYPE="${MOODLE_DB_TYPE:-mariadb}"
MOODLE_DATAROOT="${MOODLE_DATAROOT:-/var/moodledata}"
MOODLE_SITE_FULLNAME="${MOODLE_SITE_FULLNAME:-Moodle LMS}"
MOODLE_SITE_SHORTNAME="${MOODLE_SITE_SHORTNAME:-moodle}"

CONFIG_PHP=/var/www/html/moodle/config.php

log "Waiting for database at ${MOODLE_DB_HOST}:${MOODLE_DB_PORT} ..."
max_tries=30
count=0
until php -r "
    \$c = @new mysqli('${MOODLE_DB_HOST}', '${MOODLE_DB_USER}', '${MOODLE_DB_PASS}', '', ${MOODLE_DB_PORT});
    exit(\$c->connect_errno ? 1 : 0);
" 2>/dev/null; do
    count=$((count + 1))
    [ $count -ge $max_tries ] && die "Database not reachable after ${max_tries} attempts."
    log "  ... attempt ${count}/${max_tries}, retrying in 3 s"
    sleep 3
done
log "Database is reachable."

DB_INSTALLED=$(php -r "
    \$c = new mysqli('${MOODLE_DB_HOST}', '${MOODLE_DB_USER}', '${MOODLE_DB_PASS}', '${MOODLE_DB_NAME}', ${MOODLE_DB_PORT});
    \$r = \$c->query(\"SHOW TABLES LIKE 'mdl_config'\");
    echo (\$r && \$r->num_rows > 0) ? 'yes' : 'no';
" 2>/dev/null || echo "no")

if [[ "$DB_INSTALLED" == "no" ]]; then
    log "Fresh install – running Moodle CLI installer ..."
    php_cli install_database.php \
        --fullname="${MOODLE_SITE_FULLNAME}" \
        --shortname="${MOODLE_SITE_SHORTNAME}" \
        --adminuser="${MOODLE_ADMIN_USER}" \
        --adminpass="${MOODLE_ADMIN_PASS}" \
        --adminemail="${MOODLE_ADMIN_EMAIL}" \
        --agree-license
    log "Installation complete."
else
    log "Existing installation detected, running upgrade check ..."
    php_cli upgrade.php --non-interactive
    log "Upgrade check done."
fi

printenv | grep -v "^_=" | sed 's/\(.*\)=\(.*\)/export \1="\2"/' > /etc/environment.sh
chmod 644 /etc/environment.sh

log "Starting cron ..."
service cron start
crontab /etc/cron.d/moodle

chown -R www-data:www-data /var/www/html/moodle
log "Starting Apache ..."
exec apache2ctl -D FOREGROUND
