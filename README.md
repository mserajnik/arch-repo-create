# arch-repo-create [![GitHub Actions status][actions-status-badge]][actions-status]

> A Docker image for creating Arch Linux package repositories

This Docker image provides an easy way to create and manage Arch Linux package
repositories. It is based on the [official Arch Linux image][arch-linux-image]
and builds packages using [`makepkg`][makepkg] before adding them to a
repository via [`repo-add`][repo-add]. Dependencies are installed with
[pikaur][pikaur] and can therefore also come from the AUR. Both the packages
and the repository can optionally be signed by providing a GPG key.

The primary use case are CI/CD platforms that don't have an Arch Linux
environment available by default. See [my personal repository][repo-example]
for an example of how this image can be utilized in a GitHub Actions workflow.

## Usage

To get started, clone the Git repository and create a .env file with configuration:

```sh
git clone https://github.com/mserajnik/arch-repo-create.git
cd arch-repo-create
```

Create environment file

```sh
cp .env.example .env`
```
> **Note**: The repository includes `.env.example` as a template with default 
  settings and documentation. Your actual `.env` file is excluded from version
  control (via `.gitignore`) to prevent accidentally committing sensitive
  information like keys and passwords.


Next, copy the packages you want to build and add to the repository to the
[`./packages`](packages) directory. Each package must be in its own
subdirectory and contain (at least) a `PKGBUILD` file, like this:

```sh
tree ./packages
./packages/
└── example-package
    └── PKGBUILD
```

Finally, run the container:

```sh
docker compose run --rm buildpkgs

# if you have make installed you can also use
make
```

Do not use `docker compose up`; the container is not supposed to keep running
after the one-off command has finished executing. Docker Compose is used mainly
to have an easy way to configure the container, considering how long the
base64 GPG key is and how cumbersome it would be to pass it via the command
line when using `docker run` instead.

After the container has exited, the repository files will be inside the
[`./repository`](repository) directory. Simply deploy these files to a web
server to host your repository and add it to your Arch Linux system by editing
your `/etc/pacman.conf`. E.g., for a signed repository with the default name
`arch-repo`:

```ini
[arch-repo]
SigLevel = Required DatabaseRequired TrustedOnly
Server = https://your-domain.com/
```

### Recreating the repository

If you want to cleanly recreate the repository from scratch, delete all the
files from the [`./repository`](repository) directory before running the
container again:

```sh
rm -rf ./repository/*
docker compose run --rm buildpkgs
```

Otherwise, the existing repository will be updated instead and old package
versions will be kept.

### Use a local image and or develop

## 1. Use local override

Edit your `.env` file to say `COMPOSE_FILE=compose.yaml:options/local.yaml`

## 2. Build local image

If the local image is missing it will be built the first
time you run `docker compose run --rm buildpkgs`.

If you make changes to any of the image files, located in `./image` and you
need to rebuild the image you can do it in several ways.

```sh
# at the same time you run
docker compose run --rm --build buildpkgs

# using the compose build command
docker compose build

# or the make task called build
make build
```





## Maintainer

[Michael Serajnik][maintainer]

## Contribute

You are welcome to help out!

[Open an issue][issues] or [make a pull request][pull-requests].

## License

[AGPL-3.0-or-later](LICENSE) © Michael Serajnik

[arch-linux-image]: https://hub.docker.com/_/archlinux/
[makepkg]: https://man.archlinux.org/man/makepkg.8.en
[pikaur]: https://github.com/actionless/pikaur
[repo-add]: https://man.archlinux.org/man/repo-add.8.en
[repo-example]: https://github.com/mserajnik/pkg.mser.at

[actions-status]: https://github.com/mserajnik/arch-repo-create/actions
[actions-status-badge]: https://github.com/mserajnik/arch-repo-create/actions/workflows/build-docker-image.yaml/badge.svg
[issues]: https://github.com/mserajnik/arch-repo-create/issues
[maintainer]: https://github.com/mserajnik
[pull-requests]: https://github.com/mserajnik/arch-repo-create/pulls
