#!/usr/bin/env bash
set -euo pipefail

MOODLE_WWW="${MOODLE_WWW:-/var/www/html/moodle}"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

log()  { echo "[install-plugins] $*"; }
warn() { echo "[install-plugins] WARNING: $*" >&2; }

plugin_dir() {
    local type="$1" name="$2"
    case "$type" in
        mod)           echo "mod/${name}" ;;
        block)         echo "blocks/${name}" ;;
        theme)         echo "theme/${name}" ;;
        auth)          echo "auth/${name}" ;;
        enrol)         echo "enrol/${name}" ;;
        local)         echo "local/${name}" ;;
        filter)        echo "filter/${name}" ;;
        format)        echo "course/format/${name}" ;;
        editor)        echo "lib/editor/${name}" ;;
        repository)    echo "repository/${name}" ;;
        plagiarism)    echo "plagiarism/${name}" ;;
        qtype)         echo "question/type/${name}" ;;
        qbehaviour)    echo "question/behaviour/${name}" ;;
        qformat)       echo "question/format/${name}" ;;
        report)        echo "report/${name}" ;;
        gradeexport)   echo "grade/export/${name}" ;;
        gradeimport)   echo "grade/import/${name}" ;;
        gradereport)   echo "grade/report/${name}" ;;
        atto)          echo "lib/editor/atto/plugins/${name}" ;;
        tinymce)       echo "lib/editor/tinymce/plugins/${name}" ;;
        tool)          echo "admin/tool/${name}" ;;
        availability)  echo "availability/condition/${name}" ;;
        calendartype)  echo "calendar/type/${name}" ;;
        datafield)     echo "mod/data/field/${name}" ;;
        datapreset)    echo "mod/data/preset/${name}" ;;
        fileconverter) echo "files/converter/${name}" ;;
        mlbackend)     echo "lib/mlbackend/${name}" ;;
        portfolio)     echo "portfolio/type/${name}" ;;
        media)         echo "media/player/${name}" ;;
        webservice)    echo "webservice/${name}" ;;
        *)             echo "local/${name}" ; warn "Unknown type '${type}', defaulting to local/" ;;
    esac
}

install_dir() {
    local src="$1" type="$2" name="$3"
    local dest="${MOODLE_WWW}/$(plugin_dir "$type" "$name")"
    if [[ -d "$dest" ]]; then
        log "  Replacing existing: $dest"
        rm -rf "$dest"
    fi
    cp -r "$src" "$dest"
    chown -R www-data:www-data "$dest"
    log "  ✔ Installed ${type}_${name} → $dest"
}

install_from_source() {
    local source_dir="$1"
    [[ -d "$source_dir" ]] || { log "Source dir not found: $source_dir"; return; }

    for plugin_path in "$source_dir"/*/; do
        [[ -d "$plugin_path" ]] || continue
        local basename
        basename=$(basename "$plugin_path")

        if [[ "$basename" == *_* ]]; then
            local type="${basename%%_*}"
            local name="${basename#*_}"
            log "Bundled plugin: ${basename}"
            install_dir "$plugin_path" "$type" "$name"
        else
            warn "Skipping '$basename' – directory must be named <type>_<pluginname>"
        fi
    done
}

install_from_manifest() {
    local manifest="$1"
    local count
    count=$(jq '. | length' "$manifest")
    log "Manifest contains $count plugin(s)."

    for i in $(seq 0 $((count - 1))); do
        local entry name type source url branch version dest_parent tmp_plugin

        name=$(jq -r ".[$i].name"    "$manifest")
        type=$(jq -r ".[$i].type"    "$manifest")
        source=$(jq -r ".[$i].source // \"git\"" "$manifest")
        url=$(jq -r    ".[$i].url    // empty"   "$manifest")
        branch=$(jq -r ".[$i].branch // \"main\"" "$manifest")
        version=$(jq -r ".[$i].version // empty"  "$manifest")

        log "Processing [$((i+1))/$count]: ${type}_${name} (source: $source)"

        tmp_plugin="${TMP_DIR}/${type}_${name}"

        case "$source" in
            git)
                [[ -n "$url" ]] || { warn "No URL for ${name}, skipping."; continue; }
                git clone --depth=1 --branch "$branch" "$url" "$tmp_plugin"
                install_dir "$tmp_plugin" "$type" "$name"
                ;;

            zip)
                [[ -n "$url" ]] || { warn "No URL for ${name}, skipping."; continue; }
                local zip_file="${TMP_DIR}/${name}.zip"
                curl -fsSL -o "$zip_file" "$url"
                mkdir -p "$tmp_plugin"
                unzip -q "$zip_file" -d "$tmp_plugin"
                # If zip extracted a single subdirectory, use that
                local extracted
                extracted=$(find "$tmp_plugin" -mindepth 1 -maxdepth 1 -type d | head -1)
                if [[ -n "$extracted" && $(find "$tmp_plugin" -mindepth 1 -maxdepth 1 | wc -l) -eq 1 ]]; then
                    install_dir "$extracted" "$type" "$name"
                else
                    install_dir "$tmp_plugin" "$type" "$name"
                fi
                ;;

            moodle)
                [[ -n "$version" ]] || { warn "No version for moodle-source ${name}, skipping."; continue; }
                local dl_url="https://moodle.org/plugins/download.php?plugin=${type}_${name}&version=${version}"
                local zip_file="${TMP_DIR}/${name}.zip"
                curl -fsSL -L -o "$zip_file" "$dl_url"
                mkdir -p "$tmp_plugin"
                unzip -q "$zip_file" -d "$tmp_plugin"
                local extracted
                extracted=$(find "$tmp_plugin" -mindepth 1 -maxdepth 1 -type d | head -1)
                if [[ -n "$extracted" ]]; then
                    install_dir "$extracted" "$type" "$name"
                else
                    install_dir "$tmp_plugin" "$type" "$name"
                fi
                ;;

            *)
                warn "Unknown source type '${source}' for ${name}, skipping."
                ;;
        esac
    done
}

MODE=""
TARGET=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source)   MODE="source";   TARGET="$2"; shift 2 ;;
        --manifest) MODE="manifest"; TARGET="$2"; shift 2 ;;
        *) warn "Unknown argument: $1"; shift ;;
    esac
done

case "$MODE" in
    source)   install_from_source   "$TARGET" ;;
    manifest) install_from_manifest "$TARGET" ;;
    *)        warn "No mode specified. Use --source or --manifest."; exit 1 ;;
esac
