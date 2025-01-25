# Chagall Deploy

**Chagall Deploy** is a streamlined deployment tool for Rails applications, optimized for development and production single-server setups. 

- It generates Docker configurations based on your application’s dependencies
- Don't require Container Registry like Docker Hub or ECR
- Detect dependecies and include services like
  - Redis
  - Sidekiq
  - Mariadb, MySQL
  - PostgreSQL
  - MongoDB
  - Elasticsearch
- Generate development and production environments with a single `compose.yaml`
- For production TLS/SSL using [reproxy](https://github.com/umputun/reproxy)

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

```bash
bin/chagall deploy
```
