FROM nginx:latest

RUN apt-get update && apt-get install -y \
    cron \
    logrotate

COPY cron/logrotate.conf /etc/logrotate.d/nginx

COPY cron/logrotate /etc/cron.d/logrotate
RUN chmod 0644 /etc/cron.d/logrotate

COPY cron/start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

CMD ["/usr/local/bin/start.sh"]
