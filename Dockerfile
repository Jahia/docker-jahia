FROM tomcat:9.0

MAINTAINER Jahia Devops team <paas@jahia.com>


# Image components
ARG BASE_URL="https://downloads.jahia.com/downloads/jahia/jahia7.3.4/Jahia-EnterpriseDistribution-7.3.4.1-r60321.4663.jar"
ARG DBMS_TYPE="mariadb"
ARG DEBUG_TOOLS="false"
ARG FFMPEG="false"
ARG HEALTHCHECK_VER="1.0.10"
ARG LIBREOFFICE="false"
ARG MAVEN_VER="3.6.3"
ARG MAVEN_BASE_URL="https://mirrors.ircam.fr/pub/apache/maven/maven-3"
ARG MODULES_BASE_URL="https://store.jahia.com/cms/mavenproxy/private-app-store/org/jahia/modules"

# Jahia's properties
ARG DS_IN_DB="true"
ARG DS_PATH="/datastore/jahia"
ARG JMANAGER_PASS="fakepassword"
ARG JMANAGER_USER="jahia"
ARG MAX_UPLOAD="268435456"
ARG OPERATING_MODE="development"
ARG PROCESSING_SERVER="false"
ARG SUPER_USER_PASSWORD="fakepassword"
ARG XMX="2048M"

# Database's properties
ARG DB_HOST="mariadb"
ARG DB_NAME="jahia"
ARG DB_USER="jahia"
ARG DB_PASS="fakepassword"


ENV RESTORE_MODULE_STATES="true"
ENV FACTORY_DATA="/data/digital-factory-data"
ENV FACTORY_CONFIG="/usr/local/tomcat/conf/digital-factory-config"
ENV PROCESSING_SERVER="$PROCESSING_SERVER"
ENV OPERATING_MODE="$OPERATING_MODE"
ENV XMX="$XMX" MAX_UPLOAD="$MAX_UPLOAD"

ENV CATALINA_BASE="/usr/local/tomcat" CATALINA_HOME="/usr/local/tomcat" CATALINA_TMPDIR="/usr/local/tomcat/temp"

ENV DBMS_TYPE="$DBMS_TYPE" DB_HOST="$DB_HOST" DB_NAME="$DB_NAME" DB_USER="$DB_USER" DB_PASS="$DB_PASS"
ENV JMANAGER_USER="$JMANAGER_USER" JMANAGER_PASS="$JMANAGER_PASS" SUPER_USER_PASSWORD="$SUPER_USER_PASSWORD"
ENV DS_IN_DB="$DS_IN_DB" DS_PATH="$DS_PATH"


ADD config_mariadb.xml /tmp
ADD config_postgresql.xml /tmp
ADD entrypoint.sh /
WORKDIR /tmp


ADD reset-jahia-tools-manager-password.py /usr/local/bin


RUN apt update \
    && packages="imagemagick python3 jq ncat" \
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
ADD installer.jar /tmp
ADD maven.zip /tmp
RUN printf "Start Jahia's installation...\n" \
    #&& wget --progress=dot:giga -O installer.jar $BASE_URL \
    #&& wget --progress=dot:giga -O maven.zip $MAVEN_BASE_URL/$MAVEN_VER/binaries/apache-maven-$MAVEN_VER-bin.zip \
    && sed -e 's/${MAVEN_VER}/'$MAVEN_VER'/' \
        -e 's/${DS_IN_DB}/'$DS_IN_DB'/' \
        -i /tmp/config_$DBMS_TYPE.xml \
    && java -jar installer.jar config_$DBMS_TYPE.xml \
    && unzip -q maven.zip -d /opt \
    && rm -f installer.jar config_*.xml maven.zip \
    && mv /data/jahia/tomcat/webapps/* /usr/local/tomcat/webapps \
    && mv /data/jahia/tomcat/lib/* /usr/local/tomcat/lib/ \
    && chmod +x /entrypoint.sh \
    && sed -e "s#common.loader=\"\\\$#common.loader=\"/usr/local/tomcat/conf/digital-factory-config\",\"\$#g" \
        -i /usr/local/tomcat/conf/catalina.properties \
    && echo

ADD $MODULES_BASE_URL/healthcheck/$HEALTHCHECK_VER/healthcheck-$HEALTHCHECK_VER.jar \
        $FACTORY_DATA/modules/healthcheck-$HEALTHCHECK_VER.jar


EXPOSE 8080
EXPOSE 7860
EXPOSE 7870

HEALTHCHECK --interval=30s \
            --timeout=5s \
            --start-period=600s \
            --retries=3 \
            CMD jsonhealth=$(curl http://localhost:8080/healthcheck -s -u root:$SUPER_USER_PASSWORD); \
                exitcode=$?; \
                if (test $exitcode -ne 0); then \
                    echo "cURL's exit code: $exitcode"; \
                    exit 1; \
                fi; \
                echo $jsonhealth; \
                if (test "$(echo $jsonhealth | jq -r '.status')" = "RED"); then \
                    exit 1; \
                else \
                    exit 0; \
                fi

CMD /entrypoint.sh
