#!/bin/sh
set -e

bundle exec rake db:migrate RAILS_ENV=production

exec /docker-entrypoint.sh "$@"
