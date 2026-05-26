#!/bin/bash
set -e

MANIFEST=/tmp/plugins.json

if [ ! -f "$MANIFEST" ]; then
    echo "Error: Plugin manifest not found at $MANIFEST"
    exit 1
fi

jq -c '.[]' "$MANIFEST" | while read -r plugin; do
    NAME=$(echo "$plugin" | jq -r '.name')
    TYPE=$(echo "$plugin" | jq -r '.type')
    REPO=$(echo "$plugin" | jq -r '.repo')
    VERSION=$(echo "$plugin" | jq -r '.version')

    TARGET="/opt/bitnami/moodle/$TYPE/$NAME"

    git clone --branch $VERSION --depth 1 "$REPO" "$TARGET"
done

echo "All plugins installed."
