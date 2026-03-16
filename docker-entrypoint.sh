#!/bin/sh
set -e

var_status() {
  var_name="$1"
  eval "var_value=\${$var_name}"

  if [ -n "$var_value" ]; then
    echo "$var_name=present"
  else
    echo "$var_name=missing"
  fi
}

database_user_present() {
  [ -n "$DATABASE_USER" ] || [ -n "$DATABASE_USERNAME" ]
}

if [ "$RAILS_ENV" = "production" ] || [ "$RAILS_ENV" = "staging" ]; then
  if [ -z "$DATABASE_URL" ] && { [ -z "$DATABASE_HOST" ] || [ -z "$DATABASE_NAME" ] || ! database_user_present || [ -z "$DATABASE_PASSWORD" ]; }; then
    echo "Database config missing for $RAILS_ENV. Set DATABASE_URL or DATABASE_HOST, DATABASE_NAME, DATABASE_USER, and DATABASE_PASSWORD." >&2
    echo "Runtime DB env status: $(var_status DATABASE_URL) $(var_status DATABASE_HOST) $(var_status DATABASE_PORT) $(var_status DATABASE_NAME) $(var_status DATABASE_USER) $(var_status DATABASE_USERNAME) $(var_status DATABASE_PASSWORD)" >&2
    exit 1
  fi

  echo "Runtime DB env status: $(var_status DATABASE_URL) $(var_status DATABASE_HOST) $(var_status DATABASE_PORT) $(var_status DATABASE_NAME) $(var_status DATABASE_USER) $(var_status DATABASE_USERNAME) $(var_status DATABASE_PASSWORD)" >&2
fi

bundle exec rails db:prepare

exec bundle exec puma -C config/puma.rb
