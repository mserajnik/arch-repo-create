#!/bin/env bash

# arch-repo-create
# Copyright (C) 2024-2026  Michael Serajnik  https://github.com/mserajnik

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

set -e

eval $(fixuid -q)

makepkg_cmd="makepkg -fsc --needed --noconfirm"
repo_add_cmd="repo-add"
sig_level="SigLevel = Optional TrustAll"

install_aur_deps() {
  local package_name="$1"

  echo "Checking for missing dependencies for $package_name..."

  missing_deps=$(makepkg --printsrcinfo | grep -oP '(?<=depends = )\S+' | xargs -I{} bash -c 'pacman -T {} > /dev/null || echo {}')

  if [ -n "$missing_deps" ]; then
    echo "Missing dependencies for $package_name detected: $missing_deps"
    echo "Installing $package_name dependencies with pikaur..."

    pikaur -S --needed --noconfirm $missing_deps
  else
    echo "No missing dependencies for $package_name found."
  fi
}

if [ -n "$GPG_PRIVATE_KEY" ]; then
  echo "GPG key detected. Importing key..."

  echo "$GPG_PRIVATE_KEY" | base64 -d | gpg --batch --import
  if [ $? -ne 0 ]; then
    echo "Error importing GPG key."
    exit 1
  fi

  if [ -n "$GPG_PASSPHRASE" ]; then
    echo "GPG passphrase detected."

    keygrip=$(gpg --list-keys --with-keygrip --fingerprint | grep Keygrip | awk '{print $3}' | head -n 1)

    if [ -n "$keygrip" ]; then
      /usr/lib/gnupg/gpg-preset-passphrase --preset --passphrase "$GPG_PASSPHRASE" $keygrip
      if [ $? -ne 0 ]; then
        echo "Error setting GPG passphrase."
        exit 1
      fi
    else
      echo "Couldn't set the GPG passphrase. Check the key import process."
      exit 1
    fi
  else
    echo "GPG passphrase is not provided. Assuming none is needed for the provided GPG key."
  fi

  makepkg_cmd+=" --sign"
  repo_add_cmd+=" --sign"
  sig_level="SigLevel = Required DatabaseRequired TrustedOnly"
else
  echo "GPG key not provided. Skipping key import."
fi

temp_dir=$(mktemp -d /tmp/packages.XXXXXX)

cp -r /packages/* "$temp_dir"/

for dir in "$temp_dir"/*/; do
  if [ -d "$dir" ]; then
    if [ ! -f "$dir/PKGBUILD" ]; then
      echo "Skipping directory $dir (no PKGBUILD found)."
      continue
    fi

    cd "$dir"

    install_aur_deps "$(basename "$dir")"
    $makepkg_cmd

    mv -f *.pkg.tar.zst /repository/
    if ls *.pkg.tar.zst.sig 1> /dev/null 2>&1; then
      mv -f *.pkg.tar.zst.sig /repository/
    fi
  fi
done

packages=$(find /repository -name "*.pkg.tar.zst");

if [ -n "$packages" ]; then
  $repo_add_cmd "/repository/$REPOSITORY_NAME.db.tar.gz" $packages;
else
  echo # Empty line
  echo "No packages found. Skipping repository creation."
  exit
fi

echo # Empty line
echo "Repository created!"
echo "Deploy the contents of the mounted repository directory to your web server and add the following to your pacman.conf:"
echo # Empty line
echo "[$REPOSITORY_NAME]"
echo $sig_level
echo "Server = https://your-domain.com/"
