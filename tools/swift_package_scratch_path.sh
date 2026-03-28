#!/usr/bin/env bash
set -euo pipefail

swift_package_scratch_path() {
  local package_path="$1"
  local cache_root="${2:-$HOME/Library/Caches/icu/swiftpm}"
  local package_name package_hash

  package_name="$(basename "$package_path")"

  if command -v shasum >/dev/null 2>&1; then
    package_hash="$(printf '%s' "$package_path" | shasum -a 256 | awk '{print substr($1, 1, 12)}')"
  else
    package_hash="$(printf '%s' "$package_path" | cksum | awk '{print $1}')"
  fi

  printf '%s/%s-%s\n' "$cache_root" "$package_name" "$package_hash"
}
