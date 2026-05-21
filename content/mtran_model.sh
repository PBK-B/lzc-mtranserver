#!/bin/bash  
set -e  
  
RECORDS_URL="https://firefox.settings.services.mozilla.com/v1/buckets/main-preview/collections/translations-models/records"  
ATTACHMENTS_BASE="https://firefox-settings-attachments.cdn.mozilla.net"  
CONFIG_DIR="${MT_CONFIG_DIR:-$HOME/.config/mtran/server}"  
MODEL_DIR="${MT_MODEL_DIR:-$HOME/.config/mtran/models}"  
RECORDS_CACHE="$CONFIG_DIR/records.json"  
  
for cmd in curl jq sha256sum; do  
    if ! command -v "$cmd" >/dev/null 2>&1; then  
        echo "Error: $cmd is required but not installed"  
        exit 1  
    fi  
done  
  
fetch_records() {  
    mkdir -p "$CONFIG_DIR" 2>/dev/null || true  
    if ! touch "$CONFIG_DIR/.write_test" 2>/dev/null; then  
        RECORDS_CACHE="${TMPDIR:-/tmp}/mtran_records.json"  
        echo "Warning: $CONFIG_DIR not writable, using $RECORDS_CACHE"  
    else  
        rm -f "$CONFIG_DIR/.write_test"  
    fi  
    if [ ! -f "$RECORDS_CACHE" ] || [ ! -r "$RECORDS_CACHE" ] || [ "${FORCE_REFRESH:-0}" = "1" ]; then  
        echo "Fetching records.json to $RECORDS_CACHE ..."  
        curl -fsSL "$RECORDS_URL" -o "$RECORDS_CACHE"  
    fi  
}  
  
list_pairs() {  
    fetch_records  
    echo "Supported language pairs (fromLang -> toLang):"  
    jq -r '.data[] | "\(.fromLang) -> \(.toLang)"' "$RECORDS_CACHE" | sort -u  
}  
  
download_model() {  
    local from_lang="$1"  
    local to_lang="$2"  
    fetch_records  
  
    local count  
    count=$(jq --arg from "$from_lang" --arg to "$to_lang" '[.data[] | select(.fromLang==$from and .toLang==$to)] | length' "$RECORDS_CACHE")  
    if [ "$count" -eq 0 ]; then  
        echo "Error: unsupported language pair $from_lang -> $to_lang"  
        return 1  
    fi  
  
    local lang_dir="$MODEL_DIR/${from_lang}_${to_lang}"  
    mkdir -p "$lang_dir"  
    echo "Downloading model $from_lang -> $to_lang to $lang_dir ..."  
  
    local file_types  
    file_types=$(jq -r --arg from "$from_lang" --arg to "$to_lang" '[.data[] | select(.fromLang==$from and .toLang==$to) | .fileType] | unique[]' "$RECORDS_CACHE")  
  
    if [ -z "$file_types" ]; then  
        echo "Error: no file types found for $from_lang -> $to_lang"  
        return 1  
    fi  
  
    while IFS= read -r file_type; do  
        [ -z "$file_type" ] && continue  
  
        local record  
        record=$(jq -c --arg from "$from_lang" --arg to "$to_lang" --arg ft "$file_type" '[.data[] | select(.fromLang==$from and .toLang==$to and .fileType==$ft)] | sort_by(.version) | last' "$RECORDS_CACHE")  
  
        local filename location hash  
        filename=$(printf '%s' "$record" | jq -r '.attachment.filename')  
        location=$(printf '%s' "$record" | jq -r '.attachment.location')  
        hash=$(printf '%s' "$record" | jq -r '.attachment.hash')  
  
        if [ -z "$filename" ] || [ "$filename" = "null" ]; then  
            echo "  [warn] fileType=$file_type: no valid record, skipping"  
            continue  
        fi  
  
        local url="$ATTACHMENTS_BASE/$location"  
        local dest="$lang_dir/$filename"  
  
        if [ -f "$dest" ]; then  
            local actual_hash  
            actual_hash=$(sha256sum "$dest" | awk '{print $1}')  
            if [ "$actual_hash" = "$hash" ]; then  
                echo "  [skip] $filename (exists, SHA256 OK)"  
                continue  
            fi  
            echo "  [warn] $filename SHA256 mismatch, re-downloading..."  
        fi  
  
        echo "  [down] $filename ($file_type)..."  
        curl -fL --progress-bar "$url" -o "$dest"  
  
        local actual_hash  
        actual_hash=$(sha256sum "$dest" | awk '{print $1}')  
        if [ "$actual_hash" != "$hash" ]; then  
            echo "  [fail] $filename SHA256 verification failed, removing"  
            rm -f "$dest"  
            return 1  
        fi  
        echo "  [ok]   $filename"  
    done <<< "$file_types"  
  
    echo "Done: $from_lang -> $to_lang"  
}  
  
download_all() {  
    fetch_records  
    echo "Downloading all language pair models..."  
    local pairs  
    pairs=$(jq -r '.data[] | "\(.fromLang) \(.toLang)"' "$RECORDS_CACHE" | sort -u)  
  
    while IFS=' ' read -r from to; do  
        [ -z "$from" ] || [ -z "$to" ] && continue  
        download_model "$from" "$to" || echo "  [warn] $from -> $to failed, continuing..."  
    done <<< "$pairs"  
  
    echo "All done."  
}  
  
usage() {  
    echo "Usage: $0 {list|download <from> <to>|download-all|refresh}"  
    echo ""  
    echo "  list                    List all supported language pairs"  
    echo "  download <from> <to>    Download model for a language pair (latest version)"  
    echo "  download-all            Download all language pair models"  
    echo "  refresh                 Force refresh records.json cache"  
    echo ""  
    echo "Environment variables:"  
    echo "  MT_CONFIG_DIR   Config dir for records.json (default: \$HOME/.config/mtran/server)"  
    echo "  MT_MODEL_DIR    Model storage dir (default: \$HOME/.config/mtran/models)"  
    echo ""  
    echo "Examples:"  
    echo "  MT_CONFIG_DIR=/app/config MT_MODEL_DIR=/app/models $0 list"  
    echo "  MT_CONFIG_DIR=/app/config MT_MODEL_DIR=/app/models $0 download en zh-Hans"  
    echo "  MT_CONFIG_DIR=/app/config MT_MODEL_DIR=/app/models $0 download-all"  
}  
  
case "${1:-}" in  
    list)  
        list_pairs  
        ;;  
    download)  
        if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then  
            echo "Usage: $0 download <from_lang> <to_lang>"  
            exit 1  
        fi  
        download_model "$2" "$3"  
        ;;  
    download-all)  
        download_all  
        ;;  
    refresh)  
        FORCE_REFRESH=1 fetch_records  
        echo "records.json refreshed to $RECORDS_CACHE"  
        ;;  
    *)  
        usage  
        ;;  
esac
