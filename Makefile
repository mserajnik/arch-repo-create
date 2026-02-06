
IMAGE_NAME ?= ghcr.io/mserajnik/arch-repo-create

.PHONY: run build image


run: .env
	docker compose run --rm buildpkgs


build:
	docker compose build

.env:
	@echo "create .env file according to README.md"


image:
	docker build -t $(IMAGE_NAME) ./image
