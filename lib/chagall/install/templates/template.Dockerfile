ARG RUBY_VERSION=<%= @versions['ruby'] %>
ARG NODE_VERSION=<%= @versions['node'] %>

FROM ruby:${RUBY_VERSION}-slim AS development

LABEL app.name="<%= @app_name %>"

ARG NODE_VERSION
ENV NODE_VERSION=${NODE_VERSION}
WORKDIR /app

RUN apt-get update -qq && apt-get install -y \
    build-essential \
    libvips \
    libffi-dev \
    libssl-dev \
    gnupg2 \
    curl \
    git

# Node section
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash && \
    export NVM_DIR="/root/.nvm" && \
    . "$NVM_DIR/nvm.sh" && \
    nvm install "$NODE_VERSION" && \
    nvm use "$NODE_VERSION" && \
    nvm alias default "$NODE_VERSION"

RUN gem install bundler

FROM development AS production

COPY . .

RUN bundle config set production true
RUN BUNDLE_JOBS=$(nproc) bundle install
RUN bundle exec rails assets:precompile