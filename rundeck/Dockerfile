# syntax=docker/dockerfile:1

ARG RUNDECK_VERSION

FROM rundeck/rundeck:${RUNDECK_VERSION}

# Copy rundeck configuration files
COPY config/rundeck/realm.properties /home/rundeck/server/config/realm.properties
COPY config/rundeck/acl /home/rundeck/server/config/acl

# Install curl for health checks
USER root
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
USER rundeck

EXPOSE 4440

CMD ["java", "-Dlogging.config=/home/rundeck/server/config/log4j2.properties", "-Dlogging.dir=/home/rundeck/var/logs", "-Drundeck.config.location=/home/rundeck/server/config/rundeck-config.properties", "-Dserver.datastore.path=/home/rundeck/server/data", "-Drundeck.server.configDir=/home/rundeck/server/config", "-Drundeck.server.serverDir=/home/rundeck", "-Drundeck.jetty.connector.forwarded=true", "-XX:+UnlockExperimentalVMOptions", "-XX:MaxRAMPercentage=75", "-jar", "/home/rundeck/rundeck.war"] 
