# Mangal Deploy

**Mangal Deploy** is a streamlined deployment tool for Rails applications, optimized for single-server setups. 

- It generates Docker configurations based on your application’s dependencies
- Don't require Container Registry like Docker Hub or ECR
  - Kamal deploy requires it
- Automatically including services like Redis, Sidekiq, PostgreSQL, and MongoDB as needed
- Mangal Deploy supports both development and production environments with a single `compose.yaml` file
- For TLS/SSL, it uses [reproxy](https://github.com/umputun/reproxy) and [acme.sh](https://github.com/acmesh-official/acme.sh)

## Features

- **Dynamic Service Configuration**: Detects and includes services based on your application’s `Gemfile`, `package.json`,`.ruby-version` or `.node-version`.
- **Multi-Stage Docker Builds**: Uses a single Dockerfile for both development and production environments.
- **Unified `compose.yaml`**: Configures development and production profiles in one Compose file.
- **Quick Installation**: Installs with a single `curl` command, generating the necessary `Dockerfile`, `compose.yaml` and `bin/mangal` file.

## Installation

To install Mangal Deploy, run this command in your project root:

```bash
curl -sSL https://github.com/frontandstart/mangal-deploy/install.sh | bash
```

## Usage

```bash
bin/mangal deploy
```
