#!/usr/bin/env bash
set -euo pipefail
MOODLE_WWW="${MOODLE_WWW:-/var/www/moodle}"
php "${MOODLE_WWW}/admin/cli/cron.php"
