#!/usr/bin/env bash
. /etc/environment.sh
exec php /var/www/html/moodle/admin/cli/cron.php
