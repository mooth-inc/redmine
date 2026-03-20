#!/bin/sh
set -e

# Run plugin migrations on startup
bundle exec rake redmine:plugins:migrate RAILS_ENV=production

exec /docker-entrypoint.sh "$@"
