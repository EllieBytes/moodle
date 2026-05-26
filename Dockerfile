FROM bitnami/moodle:latest

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends git jq && \
    rm -fr /var/lib/apt/lists/*

COPY plugins.json /tmp/plugins.json
COPY plugins.bash /tmp/plugins.bash

RUN chmod +x /tmp/plugins.bash && \
    /tmp/plugins.bash && \
    rm /tmp/plugins.json /tmp/plugins.bash

USER 1001
