#!/usr/bin/env bash
set -euo pipefail

date_value="${RELEASE_DATE:-$(date -u +%Y-%m-%d)}"
year="${date_value%%-*}"
month_with_day="${date_value#*-}"
month="${month_with_day%%-*}"
month="$((10#$month))"
prefix="${year}.${month}"
latest_patch=0

while IFS= read -r tag; do
  version="${tag#v}"
  patch="${version##*.}"

  if [[ "$version" =~ ^${year}\.${month}\.[0-9]+$ ]] && (( patch > latest_patch )); then
    latest_patch="$patch"
  fi
done < <(git tag --list "v${prefix}.*")

patch="$((latest_patch + 1))"
version="${prefix}.${patch}"
tag="v${version}"

printf "version=%s\n" "$version"
printf "tag=%s\n" "$tag"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    printf "version=%s\n" "$version"
    printf "tag=%s\n" "$tag"
  } >> "$GITHUB_OUTPUT"
fi

