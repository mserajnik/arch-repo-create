#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2024-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

# Container command wrapper that drops privileges via `fixuid`, builds the Arch
# packages mounted under `/packages` (resolving AUR dependencies with
# `pikaur`), and assembles them into a repository under `/repository`.

set -euo pipefail

eval "$(fixuid -q)"

makepkg_cmd="makepkg -fsc --needed --noconfirm"
repo_add_cmd="repo-add"
sig_level="SigLevel = Optional TrustAll"

install_aur_deps() {
  local package_name="$1"
  local missing_deps

  echo "[arch-repo-create]: Checking for missing dependencies for '$package_name'..."

  missing_deps="$(makepkg --printsrcinfo |
    grep -oP '(?<=(\s|make)depends = )\S+' |
    xargs -I{} bash -c 'pacman -T {} > /dev/null || echo "{}"')"

  if [ -n "$missing_deps" ]; then
    echo "[arch-repo-create]: Missing dependencies for '$package_name' detected: $missing_deps."
    echo "[arch-repo-create]: Installing '$package_name' dependencies with pikaur..."

    # Word-splitting `$missing_deps` is intentional; it is a list of package
    # names.
    # shellcheck disable=SC2086
    pikaur -S --needed --noconfirm $missing_deps
  else
    echo "[arch-repo-create]: No missing dependencies for '$package_name' found."
  fi
}

if [ -n "${GPG_PRIVATE_KEY:-}" ]; then
  echo "[arch-repo-create]: GPG key detected, importing key..."

  if ! echo "$GPG_PRIVATE_KEY" | base64 -d | gpg --batch --import; then
    echo "[arch-repo-create]: ERROR: Failed to import GPG key." >&2
    exit 1
  fi

  if [ -n "${GPG_PASSPHRASE:-}" ]; then
    echo "[arch-repo-create]: GPG passphrase detected."

    keygrip="$(gpg --list-keys --with-keygrip --fingerprint |
      grep Keygrip |
      awk '{print $3}' |
      head -n 1)"

    if [ -z "$keygrip" ]; then
      echo "[arch-repo-create]: ERROR: Could not determine the GPG keygrip; check the key import process." >&2
      exit 1
    fi

    if ! /usr/lib/gnupg/gpg-preset-passphrase --preset --passphrase "$GPG_PASSPHRASE" "$keygrip"; then
      echo "[arch-repo-create]: ERROR: Failed to set the GPG passphrase." >&2
      exit 1
    fi
  else
    echo "[arch-repo-create]: GPG passphrase is not provided, assuming none is needed for the provided GPG key."
  fi

  makepkg_cmd+=" --sign"
  repo_add_cmd+=" --sign"
  sig_level="SigLevel = Required DatabaseRequired TrustedOnly"
else
  echo "[arch-repo-create]: GPG key not provided, skipping key import."
fi

temp_dir="$(mktemp -d /tmp/packages.XXXXXX)"

cp -r /packages/* "$temp_dir"/

for dir in "$temp_dir"/*/; do
  if [ ! -d "$dir" ]; then
    continue
  fi

  if [ ! -f "$dir/PKGBUILD" ]; then
    echo "[arch-repo-create]: Skipping directory '$dir' (no PKGBUILD found)."
    continue
  fi

  cd "$dir"

  install_aur_deps "$(basename "$dir")"
  # Word-splitting `$makepkg_cmd` is intentional; it is a command line.
  # shellcheck disable=SC2086
  $makepkg_cmd

  mv -f ./*.pkg.tar.zst /repository/
  if compgen -G "./*.pkg.tar.zst.sig" >/dev/null; then
    mv -f ./*.pkg.tar.zst.sig /repository/
  fi
done

mapfile -t packages < <(find /repository -name '*.pkg.tar.zst')

if [ "${#packages[@]}" -eq 0 ]; then
  echo
  echo "[arch-repo-create]: No packages found, skipping repository creation."
  exit
fi

# Word-splitting `$repo_add_cmd` is intentional; it is a command line.
# shellcheck disable=SC2086
$repo_add_cmd "/repository/$REPOSITORY_NAME.db.tar.gz" "${packages[@]}"

echo
echo "[arch-repo-create]: Repository created."
echo "[arch-repo-create]: Deploy the contents of the mounted repository directory to your web server and add the following to your pacman.conf:"
echo
echo "[$REPOSITORY_NAME]"
echo "$sig_level"
echo "Server = https://your-domain.com/"
