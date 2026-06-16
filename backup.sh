BACKUPS="$(pwd)/moodle.bak"
mkdir -p $BACKUPS

VOLUMES=$(docker volume ls -q)

for VOL in $VOLUMES; do
    echo "Backing up $VOL"

    docker run --rm -v "${VOL}:/source:ro" -v "${BACKUPS}:/backup:ro" alpine \
        tar czf "/backup/${VOL}-$(date +%Y_%m_%D_%H_%M).tgz"
done

echo "All backups complete."
