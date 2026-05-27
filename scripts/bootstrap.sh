#!/usr/bin/env bash
set -euo pipefail

MOODLE_WWW="${MOODLE_WWW:-/var/www/html/moodle}"
MOODLE_DATA="${MOODLE_DATA:-/var/moodledata}"
STAMP="${MOODLE_DATA}/.bootstrapped"

log() { echo "[bootstrap] $*"; }

log "Installing bundled plugins..."
install-plugins --source /tmp/bundled-plugins

PLUGIN_MANIFEST="${PLUGIN_MANIFEST:-/etc/moodle/plugins.json}"
if [[ -f "$PLUGIN_MANIFEST" ]]; then
    log "Processing plugin manifest: $PLUGIN_MANIFEST"
    install-plugins --manifest "$PLUGIN_MANIFEST"
else
    log "No plugin manifest found at $PLUGIN_MANIFEST, skipping."
fi

if [[ ! -f "$STAMP" ]]; then
    log "First run detected – installing Moodle database..."

    : "${MOODLE_DB_HOST:?Need MOODLE_DB_HOST}"
    : "${MOODLE_DB_NAME:?Need MOODLE_DB_NAME}"
    : "${MOODLE_DB_USER:?Need MOODLE_DB_USER}"
    : "${MOODLE_DB_PASS:?Need MOODLE_DB_PASS}"
    : "${MOODLE_ADMIN_USER:?Need MOODLE_ADMIN_USER}"
    : "${MOODLE_ADMIN_PASS:?Need MOODLE_ADMIN_PASS}"
    : "${MOODLE_SITE_URL:?Need MOODLE_SITE_URL}"

    SITE_NAME="${MOODLE_SITE_NAME:-Moodle LMS}"
    ADMIN_EMAIL="${MOODLE_ADMIN_EMAIL:-admin@example.com}"

    # Wait for DB...
    log "Waiting for database at ${MOODLE_DB_HOST}..."
    for i in $(seq 1 30); do
        if php -r "
            \$c = new mysqli('${MOODLE_DB_HOST}','${MOODLE_DB_USER}','${MOODLE_DB_PASS}','${MOODLE_DB_NAME}');
            exit(\$c->connect_error ? 1 : 0);
        " 2>/dev/null; then
            log "Database ready."
            break
        fi
        log "  attempt $i/30 – sleeping 3s..."
        sleep 3
    done

    php "${MOODLE_WWW}/admin/cli/install.php" \
        --chmod=2777 \
        --lang=en \
        --wwwroot="${MOODLE_SITE_URL}" \
        --dataroot="${MOODLE_DATA}" \
        --dbtype="${MOODLE_DB_TYPE:-mariadb}" \
        --dbhost="${MOODLE_DB_HOST}" \
        --dbname="${MOODLE_DB_NAME}" \
        --dbuser="${MOODLE_DB_USER}" \
        --dbpass="${MOODLE_DB_PASS}" \
        --dbport="${MOODLE_DB_PORT:-3306}" \
        --fullname="${SITE_NAME}" \
        --shortname="$(echo "${SITE_NAME}" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')" \
        --adminuser="${MOODLE_ADMIN_USER}" \
        --adminpass="${MOODLE_ADMIN_PASS}" \
        --adminemail="${ADMIN_EMAIL}" \
        --non-interactive \
        --agree-license

    if [[ -f /etc/moodle/extra-config.php ]]; then
        log "Appending extra-config.php..."
        cat /etc/moodle/extra-config.php >> "${MOODLE_WWW}/config.php"
    fi

    log "Running Moodle upgrade..."
    php "${MOODLE_WWW}/admin/cli/upgrade.php" --non-interactive

    chown -R www-data:www-data "${MOODLE_DATA}"
    touch "$STAMP"
    log "Bootstrap complete."
else
    log "Already bootstrapped – running upgrade check for new plugins..."
    php "${MOODLE_WWW}/admin/cli/upgrade.php" --non-interactive || true
fi

log "Starting services via supervisord..."
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
