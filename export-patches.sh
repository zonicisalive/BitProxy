#!/usr/bin/env bash
# Export BitProxy commits as patch files (one folder per repo), based on versions.env.
# Re-apply on a new release:  git switch -c bitproxy <new-base> && git am -3 patches/android/*.patch
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
source versions.env
rm -rf patches && mkdir -p patches/core patches/android
git -C sing-box format-patch -q "$SING_BOX_TAG..bitproxy" -o "$PWD/patches/core"
git -C sing-box/clients/android format-patch -q "$SFA_COMMIT..bitproxy" -o "$PWD/patches/android"
ls patches/*
