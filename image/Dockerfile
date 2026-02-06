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

FROM archlinux:base-devel

ARG BUILDER_USER_ID=1000
ARG BUILDER_GROUP_ID=1000
ARG BUILDER_USER_NAME=builder
ARG BUILDER_GROUP_NAME=builder

ENV REPOSITORY_NAME=arch-repo

RUN \
  pacman -Syu --noconfirm --needed \
    archlinux-keyring \
    git && \
  rm -rf /var/cache/pacman/pkg/* && \
  existing_group=$(getent group ${BUILDER_GROUP_ID}) || true && \
  existing_user=$(getent passwd ${BUILDER_USER_ID}) || true && \
  if [ -n "$existing_group" ]; then \
    old_groupname=$(echo "$existing_group" | cut -d: -f1) && \
    groupmod -n ${BUILDER_GROUP_NAME} "$old_groupname"; \
  else \
    groupadd -g ${BUILDER_GROUP_ID} ${BUILDER_GROUP_NAME}; \
  fi && \
  if [ -n "$existing_user" ]; then \
    old_username=$(echo "$existing_user" | cut -d: -f1) && \
    usermod -l ${BUILDER_USER_NAME} -d "/home/${BUILDER_USER_NAME}" "$old_username" && \
    mv "/home/${old_username}" "/home/${BUILDER_USER_NAME}"; \
  else \
    useradd -u ${BUILDER_USER_ID} -g ${BUILDER_GROUP_NAME} -d "/home/${BUILDER_USER_NAME}" -s /bin/sh -m ${BUILDER_USER_NAME}; \
  fi && \
  echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder && \
  mkdir -p /packages /repository && \
  chown -R ${BUILDER_USER_NAME}:${BUILDER_GROUP_NAME} /packages /repository && \
  # See https://github.com/boxboat/fixuid
  curl -SsL https://github.com/boxboat/fixuid/releases/download/v0.6.0/fixuid-0.6.0-linux-amd64.tar.gz | tar -C /usr/local/bin -xzf - && \
  chown root:root /usr/local/bin/fixuid && \
  chmod 4755 /usr/local/bin/fixuid && \
  mkdir -p /etc/fixuid && \
  printf "user: ${BUILDER_USER_NAME}\ngroup: ${BUILDER_GROUP_NAME}\n" > /etc/fixuid/config.yml

COPY ./docker-cmd-run.sh /usr/local/bin/run

RUN chmod +x /usr/local/bin/run

USER ${BUILDER_USER_NAME}:${BUILDER_GROUP_NAME}

RUN \
  cd && \
  mkdir ~/.gnupg && \
  touch ~/.gnupg/gpg.conf && \
  echo "keyserver-options auto-key-retrieve" >> ~/.gnupg/gpg.conf && \
  echo "use-agent" >> ~/.gnupg/gpg.conf && \
  echo "allow-preset-passphrase" >> ~/.gnupg/gpg-agent.conf && \
  find ~/.gnupg -type f -exec chmod 600 {} \; && \
  find ~/.gnupg -type d -exec chmod 700 {} \; && \
  git clone https://aur.archlinux.org/pikaur.git && \
  cd pikaur && \
  makepkg -sri --noconfirm --needed && \
  cd .. && \
  rm -rf pikaur

WORKDIR /packages

CMD ["run"]
