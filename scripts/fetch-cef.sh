#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CEF_BASE_URL="${CEF_BASE_URL:-https://cef-builds.spotifycdn.com}"
CEF_PLATFORM="${CEF_PLATFORM:-macosarm64}"
CEF_CHANNEL="${CEF_CHANNEL:-stable}"
CEF_DISTRIBUTION="${CEF_DISTRIBUTION:-standard}"
CEF_VERSION="${CEF_VERSION:-}"
CEF_DRY_RUN="${CEF_DRY_RUN:-0}"

CEF_HOME="$ROOT/vendor/cef"
INDEX_PATH="$CEF_HOME/index.json"
CACHE_DIR="$CEF_HOME/cache"
DIST_DIR="$CEF_HOME/dist"

mkdir -p "$CACHE_DIR" "$DIST_DIR"

curl -fsSL -o "$INDEX_PATH" "$CEF_BASE_URL/index.json"

if [[ -n "$CEF_VERSION" ]]; then
  filter='
    .[$platform].versions
    | map(select(.cef_version == $version) as $v
      | $v.files[]
      | select(.type == $distribution)
      | {
          cef_version: $v.cef_version,
          chromium_version: $v.chromium_version,
          name,
          sha1,
          size
        })
    | first
    | [.cef_version, .chromium_version, .name, .sha1, (.size | tostring)]
    | @tsv
  '
  metadata_tsv="$(jq -r \
    --arg platform "$CEF_PLATFORM" \
    --arg version "$CEF_VERSION" \
    --arg distribution "$CEF_DISTRIBUTION" \
    "$filter" "$INDEX_PATH")"
else
  filter='
    .[$platform].versions
    | map(select(.channel == $channel) as $v
      | $v.files[]
      | select(.type == $distribution)
      | {
          cef_version: $v.cef_version,
          chromium_version: $v.chromium_version,
          name,
          sha1,
          size,
          version_key: ($v.chromium_version | split(".") | map(tonumber))
        })
    | max_by(.version_key)
    | [.cef_version, .chromium_version, .name, .sha1, (.size | tostring)]
    | @tsv
  '
  metadata_tsv="$(jq -r \
    --arg platform "$CEF_PLATFORM" \
    --arg channel "$CEF_CHANNEL" \
    --arg distribution "$CEF_DISTRIBUTION" \
    "$filter" "$INDEX_PATH")"
fi

if [[ -z "$metadata_tsv" || "$metadata_tsv" == "null" ]]; then
  printf "No CEF build matched platform=%s channel=%s distribution=%s version=%s\n" \
    "$CEF_PLATFORM" "$CEF_CHANNEL" "$CEF_DISTRIBUTION" "${CEF_VERSION:-latest}" >&2
  exit 1
fi

IFS=$'\t' read -r cef_version chromium_version archive_name archive_sha1 archive_size <<< "$metadata_tsv"
archive_path="$CACHE_DIR/$archive_name"
extract_name="${archive_name%.tar.bz2}"
extract_path="$DIST_DIR/$extract_name"

printf "CEF %s / Chromium %s\n" "$cef_version" "$chromium_version"
printf "Archive %s\n" "$archive_name"
printf "Size %s bytes\n" "$archive_size"

if [[ "$CEF_DRY_RUN" == "1" ]]; then
  exit 0
fi

if [[ ! -f "$archive_path" ]]; then
  curl -fL --continue-at - -o "$archive_path" "$CEF_BASE_URL/$archive_name"
fi

actual_sha1="$(shasum -a 1 "$archive_path" | awk '{print $1}')"
if [[ "$actual_sha1" != "$archive_sha1" ]]; then
  printf "SHA1 mismatch for %s\nexpected %s\nactual   %s\n" \
    "$archive_name" "$archive_sha1" "$actual_sha1" >&2
  exit 1
fi

if [[ ! -d "$extract_path" ]]; then
  staging="$DIST_DIR/.extracting-$extract_name"
  rm -rf "$staging"
  mkdir -p "$staging"
  tar -xjf "$archive_path" -C "$staging"
  extracted="$(find "$staging" -mindepth 1 -maxdepth 1 -type d -print -quit)"
  if [[ -z "$extracted" ]]; then
    printf "CEF archive did not extract to a directory\n" >&2
    exit 1
  fi
  mv "$extracted" "$extract_path"
  rm -rf "$staging"
fi

ln -sfn "dist/$extract_name" "$CEF_HOME/current"
printf "CEF ready at %s\n" "$CEF_HOME/current"
