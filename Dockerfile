FROM redmine:5.1-alpine

# Install timezone data and build dependencies for plugins
RUN sed -i 's|https://|http://|' /etc/apk/repositories && \
    apk add --no-cache tzdata build-base ca-certificates && \
    update-ca-certificates && \
    sed -i 's|http://|https://|' /etc/apk/repositories

# Default environment (RAILS_ENV is also set in Cloud Run for consistency)
ENV RAILS_ENV=production \
    REDMINE_LANG=ja \
    TZ=Asia/Tokyo

# Plugins
COPY plugins/ /usr/src/redmine/plugins/
RUN cd /usr/src/redmine && bundle install --without development test

COPY config/database.yml /usr/src/redmine/config/database.yml
COPY config/configuration.yml /usr/src/redmine/config/configuration.yml
COPY config/initializers/default_language.rb /usr/src/redmine/config/initializers/default_language.rb
COPY docker-entrypoint-custom.sh /docker-entrypoint-custom.sh
RUN chmod +x /docker-entrypoint-custom.sh

ENTRYPOINT ["/docker-entrypoint-custom.sh"]
CMD ["rails", "server", "-b", "0.0.0.0"]
