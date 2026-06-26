# SPDX-FileCopyrightText: 2024-2026 Michael Serajnik <https://github.com/mserajnik>
# SPDX-License-Identifier: AGPL-3.0-or-later

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
  existing_group=$(getent group "$BUILDER_GROUP_ID") || true && \
  existing_user=$(getent passwd "$BUILDER_USER_ID") || true && \
  if [ -n "$existing_group" ]; then \
    old_groupname=${existing_group%%:*} && \
    groupmod -n "$BUILDER_GROUP_NAME" "$old_groupname"; \
  else \
    groupadd -g "$BUILDER_GROUP_ID" "$BUILDER_GROUP_NAME"; \
  fi && \
  if [ -n "$existing_user" ]; then \
    old_username=${existing_user%%:*} && \
    usermod -l "$BUILDER_USER_NAME" -d "/home/$BUILDER_USER_NAME" "$old_username" && \
    mv "/home/$old_username" "/home/$BUILDER_USER_NAME"; \
  else \
    useradd -l -u "$BUILDER_USER_ID" -g "$BUILDER_GROUP_NAME" -d "/home/$BUILDER_USER_NAME" -s /bin/sh -m "$BUILDER_USER_NAME"; \
  fi && \
  echo "$BUILDER_USER_NAME ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/$BUILDER_USER_NAME" && \
  mkdir -p /packages /repository && \
  chown -R "$BUILDER_USER_NAME:$BUILDER_GROUP_NAME" /packages /repository && \
  # See https://github.com/boxboat/fixuid
  curl -SsL "https://github.com/boxboat/fixuid/releases/download/v0.6.0/fixuid-0.6.0-linux-amd64.tar.gz" -o /tmp/fixuid.tar.gz && \
  tar -C /usr/local/bin -xzf /tmp/fixuid.tar.gz && \
  rm /tmp/fixuid.tar.gz && \
  chown root:root /usr/local/bin/fixuid && \
  chmod 4755 /usr/local/bin/fixuid && \
  mkdir -p /etc/fixuid && \
  printf 'user: %s\ngroup: %s\n' "$BUILDER_USER_NAME" "$BUILDER_GROUP_NAME" > /etc/fixuid/config.yml

COPY --chmod=755 ./docker-cmd-run.sh /usr/local/bin/run

USER $BUILDER_USER_NAME:$BUILDER_GROUP_NAME

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
