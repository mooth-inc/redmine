FROM redmine:5.1-alpine

# Install timezone data and build dependencies for plugins
RUN apk add --no-cache tzdata build-base

# Default environment (RAILS_ENV is also set in Cloud Run for consistency)
ENV RAILS_ENV=production \
    REDMINE_LANG=ja \
    TZ=Asia/Tokyo

COPY config/database.yml /usr/src/redmine/config/database.yml
COPY config/configuration.yml /usr/src/redmine/config/configuration.yml
COPY plugins/redmine_header_auth /usr/src/redmine/plugins/redmine_header_auth
COPY docker-entrypoint-custom.sh /docker-entrypoint-custom.sh
RUN chmod +x /docker-entrypoint-custom.sh

ENTRYPOINT ["/docker-entrypoint-custom.sh"]
CMD ["rails", "server", "-b", "0.0.0.0"]
