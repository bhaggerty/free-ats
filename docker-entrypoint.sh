#!/bin/sh
set -e

if [ "$RAILS_ENV" = "production" ] || [ "$RAILS_ENV" = "staging" ]; then
  if [ -z "$DATABASE_URL" ]; then
    echo "DATABASE_URL must be set in $RAILS_ENV before starting the app." >&2
    exit 1
  fi
fi

bundle exec rails db:prepare

exec bundle exec puma -C config/puma.rb
