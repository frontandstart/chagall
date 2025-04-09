# Chagall Deploy

## Project under active development

**Chagall Deploy** is a deployment tool for applications for staging and production single-server setups. 


Install `gem install chagall --pre`

- [x] `bin/chagall setup` Bootstap server
  - Install docker with sudo if user not root
  - Make docker deamon accessable from user

- [x] `bin/chagall deploy` Build docker image and deploy docker compose application into server

- [x] `bin/chagall compose` Wrap docker compose commands on server project through ssh
  for example `bin/chagall compose logs app -f --tail 500`

- [x] Don't require Container Registry like Docker Hub or ECR
- [ ] Generates Docker and docker compose configurations based on your application’s dependencies suck like: (not implemented yet)
  - Redis
  - Sidekiq
  - Mariadb, MySQL
  - PostgreSQL
  - MongoDB
  - Elasticsearch
- [x] For production TLS/SSL using [reproxy](https://github.com/umputun/reproxy)

## Features

- **Dynamic Service Configuration**: Detects and includes services based on your application’s `Gemfile`, `package.json`,`.ruby-version` or `.node-version`.
- **Multi-Stage Docker Builds**: Uses a single Dockerfile for both development and production environments.
- **Unified `compose.yaml`**: Configures development and production profiles in one Compose file.
- **Quick Installation**: Installs with a single `curl` command, generating the necessary `Dockerfile`, `compose.yaml` and `bin/chagall` file.

## Installation

To install Chagall Deploy, run this command in your project root:

```bash
curl -sSL https://github.com/frontandstart/chagall-deploy/install.sh | bash
```

## Usage

Generate compose and compose.prod.yaml
```bash
bin/chagall install
```

Setup server for deploy:
  - install docker
  - install reproxy(optional can be part of compose.prod.yaml) for signe compose per server deployments
```bash
bin/chagall setup
```

Deploy application
  - Build image
  - Trigger compose project update
```bash
bin/chagall deploy
```
