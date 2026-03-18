FROM redmine:5.1-alpine

COPY config/database.yml /usr/src/redmine/config/database.yml
COPY config/configuration.yml /usr/src/redmine/config/configuration.yml
COPY docker-entrypoint-custom.sh /docker-entrypoint-custom.sh
RUN chmod +x /docker-entrypoint-custom.sh

ENTRYPOINT ["/docker-entrypoint-custom.sh"]
CMD ["rails", "server", "-b", "0.0.0.0"]
