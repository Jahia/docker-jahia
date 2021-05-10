FROM tomcat:9.0

LABEL maintainer="Jahia Devops team <paas@jahia.com>"


# Image components
ARG BASE_URL="https://downloads.jahia.com/downloads/jahia/jahia8.0.0/Jahia-EnterpriseDistribution-8.0.0.0-r60557.4681.jar"
ARG DBMS_TYPE="mariadb"
ARG INSTALL_FILE_SUFFIX="_v8"
ARG DEBUG_TOOLS="false"
ARG FFMPEG="false"
ARG HEALTHCHECK_VER="2.3.1"
ARG LIBREOFFICE="false"
ARG MAVEN_VER="3.6.3"
ARG MAVEN_BASE_URL="https://mirrors.ircam.fr/pub/apache/maven/maven-3"
ARG MODULES_BASE_URL="https://store.jahia.com/cms/mavenproxy/private-app-store/org/jahia/modules"
ARG IMAGEMAGICK_BINARIES_DOWNLOAD_URL="https://imagemagick.org/download/binaries/magick"
ARG LOG_MAX_DAYS="5"

# Jahia's properties
ARG DS_IN_DB="true"
ARG DS_PATH="/datastore/jahia"
ARG JMANAGER_PASS="fakepassword"
ARG JMANAGER_USER="jahia"
ARG MAX_UPLOAD="268435456"
ARG OPERATING_MODE="development"
ARG PROCESSING_SERVER="false"
ARG SUPER_USER_PASSWORD="fakepassword"
ARG MAX_RAM_PERCENTAGE=95
ARG MAVEN_XMX="256m"

# Database's properties
ARG DB_HOST="mariadb"
ARG DB_NAME="jahia"
ARG DB_USER="jahia"
ARG DB_PASS="fakepassword"

# Container user
ARG C_USER="tomcat"
ARG C_GROUP="tomcat"

ENV RESTORE_MODULE_STATES="true"
ENV RESTORE_PERSISTED_CONFIGURATION="true"
ENV INITIAL_FACTORY_DATA="/usr/local/tomcat/digital-factory-data"
ENV FACTORY_DATA="/data/digital-factory-data"
ENV FACTORY_CONFIG="/usr/local/tomcat/conf/digital-factory-config"
ENV PROCESSING_SERVER="$PROCESSING_SERVER"
ENV OPERATING_MODE="$OPERATING_MODE"
ENV MAX_UPLOAD="$MAX_UPLOAD"
ENV MAX_RAM_PERCENTAGE="$MAX_RAM_PERCENTAGE"
ENV MAVEN_OPTS="-Xmx$MAVEN_XMX"

ENV CATALINA_BASE="/usr/local/tomcat" CATALINA_HOME="/usr/local/tomcat" CATALINA_TMPDIR="/usr/local/tomcat/temp" LOG_MAX_DAYS="$LOG_MAX_DAYS"

ENV DBMS_TYPE="$DBMS_TYPE" DB_HOST="$DB_HOST" DB_NAME="$DB_NAME" DB_USER="$DB_USER" DB_PASS="$DB_PASS"
ENV JMANAGER_USER="$JMANAGER_USER" JMANAGER_PASS="$JMANAGER_PASS" SUPER_USER_PASSWORD="$SUPER_USER_PASSWORD"
ENV DS_IN_DB="$DS_IN_DB" DS_PATH="$DS_PATH"


COPY config_mariadb$INSTALL_FILE_SUFFIX.xml /tmp
COPY config_postgresql$INSTALL_FILE_SUFFIX.xml /tmp
COPY entrypoint.sh /
WORKDIR /tmp
# these two files need to be copied on the same line since we want to copy installer.jar IF it exists, and copy doesn't support conditional copy (only copy if file exists)
COPY entrypoint.sh installer.jar* ./


COPY reset-jahia-tools-manager-password.py /usr/local/bin


RUN apt-get update \
    && packages="python3 jq ncat libx11-6 libharfbuzz0b libfribidi0" \
    && case "$DBMS_TYPE" in \
        "mariadb") packages="$packages mariadb-client";; \
        "postgresql") packages="$packages postgresql-client";; \
       esac \
    && if $DEBUG_TOOLS; then \
        packages="$packages vim binutils"; \
       fi \
    && if $LIBREOFFICE; then \
        packages="$packages libreoffice"; \
       fi \
    && if $FFMPEG; then \
        packages="$packages ffmpeg"; \
       fi \
    && apt-get install -y --no-install-recommends \
        $packages \
    && rm -rf /var/lib/apt/lists/*
RUN printf "Start Jahia's installation...\n" \
    && ls -l \
    && if [ ! -f "installer.jar" ]; then \
        wget --progress=dot:giga -O installer.jar $BASE_URL; \
       fi \
    && wget --progress=dot:giga -O maven.zip $MAVEN_BASE_URL/$MAVEN_VER/binaries/apache-maven-$MAVEN_VER-bin.zip \
    && sed -e "s/\${MAVEN_VER}/$MAVEN_VER/" \
        -e "s/\${DS_IN_DB}/$DS_IN_DB/" \
        -i /tmp/config_$DBMS_TYPE$INSTALL_FILE_SUFFIX.xml \
    && java -jar installer.jar config_$DBMS_TYPE$INSTALL_FILE_SUFFIX.xml \
    && unzip -q maven.zip -d /opt \
    && rm -f installer.jar config_*.xml maven.zip \
    && mv /data/jahia/tomcat/webapps/* /usr/local/tomcat/webapps \
    && mv /data/jahia/tomcat/lib/* /usr/local/tomcat/lib/ \
    && mv ${FACTORY_DATA} ${INITIAL_FACTORY_DATA} \
    && chmod +x /entrypoint.sh \
    && sed -e "s#common.loader=\"\\\$#common.loader=\"/usr/local/tomcat/conf/digital-factory-config\",\"\$#g" \
        -i /usr/local/tomcat/conf/catalina.properties \
    && echo

## fix hadolint DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN unzip -aap /usr/local/tomcat/webapps/ROOT/WEB-INF/lib/jahia-impl-*.jar META-INF/MANIFEST.MF \
    | awk '$1~/^Implementation-Version/ {split($2,a,"-");print a[1]}' > /usr/local/tomcat/jahia-version.txt \
    && echo Current Jahia Version : "$(cat /usr/local/tomcat/jahia-version.txt)"
ADD $MODULES_BASE_URL/healthcheck/$HEALTHCHECK_VER/healthcheck-$HEALTHCHECK_VER.jar \
        ${INITIAL_FACTORY_DATA}/modules/healthcheck-$HEALTHCHECK_VER.jar

COPY optional_modules* /tmp
## allows the Docker build to continue if no modules were provided
RUN mv /tmp/*.jar ${FACTORY_DATA}/modules || true

# Add CORS filter for GraphQL queries
COPY filter_graphql_update.xml /tmp
RUN line=$(awk '/<listener>/ {print NR-1; exit}' /usr/local/tomcat/webapps/ROOT/WEB-INF/web.xml) \
    && sed "$line r /tmp/filter_graphql_update.xml" -i /usr/local/tomcat/webapps/ROOT/WEB-INF/web.xml \
    && rm /tmp/filter_graphql_update.xml

# logs retention
RUN sed 's/^\([^#].*\.maxDays\s*=\s*\).*$/\1'$LOG_MAX_DAYS'/' -i /usr/local/tomcat/conf/logging.properties \
    && sed '/name="ROLL"/,+2 s/debug/warn/' -i /usr/local/tomcat/webapps/ROOT/WEB-INF/etc/config/log4j.xml

# Retrieve latest ImageMagick binaries
RUN echo "Retrieve latest ImageMagick binaries..." \
    && wget --progress=dot:mega -O magick $IMAGEMAGICK_BINARIES_DOWNLOAD_URL \
    && chmod +x magick \
    && ./magick --appimage-extract \
    && mkdir /opt/magick \
    && mv squashfs-root/usr/* /opt/magick \
    && rm -rf /opt/magick/share/ squashfs-root/ ./magick

# add container user and grant permissions
RUN groupadd -g 999 $C_GROUP
RUN useradd -r -u 999 -g $C_GROUP $C_USER -d $CATALINA_BASE/temp -m
RUN mkdir -p $FACTORY_DATA \
    && chown -R $C_USER: $CATALINA_BASE /data \
    && chown $C_USER: /entrypoint.sh
RUN $DS_IN_DB || ( mkdir -p $DS_PATH \
    && chown -R $C_USER:$C_GROUP $DS_PATH )
USER $C_USER

STOPSIGNAL SIGINT

EXPOSE 8080
EXPOSE 7860
EXPOSE 7870

HEALTHCHECK --interval=30s \
            --timeout=5s \
            --start-period=600s \
            --retries=3 \
            CMD cookie="/var/tmp/healthcheck.cookie" \
                jsonhealth=$(curl http://localhost:8080/healthcheck -s -u root:$SUPER_USER_PASSWORD -c $cookie -b $cookie); \
                exitcode=$?; \
                if (test $exitcode -ne 0); then \
                    echo "cURL's exit code: $exitcode"; \
                    exit 1; \
                fi; \
                echo $jsonhealth; \
                if (test "$(echo $jsonhealth | jq -r '.status')" = "GREEN"); then \
                    exit 0; \
                else \
                    exit 1; \
                fi

CMD ["/entrypoint.sh"]
