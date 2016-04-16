FROM rabbitmq:3.6.1

RUN rabbitmq-plugins enable --offline rabbitmq_management rabbitmq_mqtt rabbitmq_stomp rabbitmq_management_agent rabbitmq_management_visualiser rabbitmq_federation rabbitmq_federation_management sockjs

COPY docker-entrypoint.sh /
COPY filebeat /
COPY filebeat.yml.rabbitmq /filebeat.yml
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 4369 5671 5672 9100 9101 9102 9103 9104 9105 15671 15672 25672
CMD ["rabbitmq-server"]
