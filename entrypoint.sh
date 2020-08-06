#!/bin/bash

function check_db_access {
    for n in {1..667}; do
        [ $n -gt 666 ] && echo "Database unreachable... aborting" && exit 1
        echo -n "Testing network database access on host $DB_HOST (test $n)... "
        if (nc -w 1 -v ${DB_HOST} ${DB_PORT} > /dev/null 2>&1 </dev/null); then
            echo "SUCCESS"
            break
        else
            echo "FAILED"
        fi
        sleep 1
    done
}

echo "Update jahia.properties..."
sed -e 's,${FACTORY_DATA},'$FACTORY_DATA',' \
    -e "s/^#\?\s*\(operatingMode\s*=\).*/\1 $OPERATING_MODE/" \
    -e "s/^#jahiaGeneratedResourcesDiskPath/jahiaGeneratedResourcesDiskPath/" \
    -e "s/^#\s\?\s*\(jahiaFileUploadMaxSize\s*=\).*/\1 $MAX_UPLOAD/" \
    -e "s,^#\s\?\s*\(gitPath\s*=\).*,\1 /usr/bin/git," \
    -e "s,^#\s\?\s*\(svnPath\s*=\).*,\1 /usr/bin/svn," \
    -e "s,^#\s\?\s*\(mvnPath\s*=\).*,\1 $(find /opt -type f -executable -name mvn)," \
    -i /usr/local/tomcat/conf/digital-factory-config/jahia/jahia.properties
if [ "$DS_IN_DB" == "true" ]; then
    echo " -- Datastore have to be store in DB"
    sed -e 's,^#\?\s*\(jahia.jackrabbit.datastore.path\s*=\).*,#\1 ${jahia.jackrabbit.home}/datastore,' \
        -i /usr/local/tomcat/conf/digital-factory-config/jahia/jahia.properties
else
    echo " -- Datastore have to be store in $DS_PATH"
    sed -e "s,^#\?\s*\(jahia.jackrabbit.datastore.path\s*=\).*,\1 $DS_PATH," \
        -i /usr/local/tomcat/conf/digital-factory-config/jahia/jahia.properties
fi
if (which ffmpeg > /dev/null); then
    echo " -- ffmpeg is present"
    sed -e "s/^#\?\s*\(jahia.dm.thumbnails.video.enabled\s*=\).*/\1 true/" \
        -e "s,^#\?\s*\(jahia.dm.thumbnails.video.ffmpeg\s*=\).*,\1 /usr/bin/ffmpeg," \
        -i /usr/local/tomcat/conf/digital-factory-config/jahia/jahia.properties
else
    echo " -- ffmpeg is not present"
    sed -e "s/^#\?\s*\(jahia.dm.thumbnails.video.enabled\s*=\).*/\1 false/" \
        -i /usr/local/tomcat/conf/digital-factory-config/jahia/jahia.properties
fi
if (which soffice > /dev/null); then
    echo " -- libreoffice is present"
    sed -e "s/^#\?\s*\(documentConverter.enabled\s*=\).*/\1 true/" \
        -e "s,^#\?\s*\(documentConverter.officeHome\s*=\).*,\1 /usr/lib/libreoffice," \
        -i /usr/local/tomcat/conf/digital-factory-config/jahia/jahia.properties
else
    echo " -- libreoffice is not present"
    sed -e "s/^#\?\s*\(documentConverter.enabled\s*=\).*/\1 false/" \
        -i /usr/local/tomcat/conf/digital-factory-config/jahia/jahia.properties
fi



echo "Update jahia.node.properties..."
sed -e "s/^#\?\s*\(processingServer\s*=\).*/\1 ${PROCESSING_SERVER}/" \
    -e "s/\(cluster.node.serverId\s*=\).*/\1 jahia-$(hostname)/" \
    -i /usr/local/tomcat/conf/digital-factory-config/jahia/jahia.node.properties

echo "Update /data/digital-factory-data/karaf/etc/org.apache.karaf.cellar.groups.cfg..."
sed -i 's/\(^default.config.sync = \)cluster/\1disabled/' /data/digital-factory-data/karaf/etc/org.apache.karaf.cellar.groups.cfg

echo "Update /usr/local/tomcat/conf/server.xml..."
sed -i '/<!-- Access log processes all example./i \\t<!-- Remote IP Valve -->\n \t<Valve className="org.apache.catalina.valves.RemoteIpValve" protocolHeader="X-Forwarded-Proto" />\n' /usr/local/tomcat/conf/server.xml
sed -i 's/pattern="%h /pattern="%{org.apache.catalina.AccessLog.RemoteAddr}r /' /usr/local/tomcat/conf/server.xml
sed -i 's/prefix="localhost_access_log"/prefix="access_log" rotatable="true" maxDays="'$LOG_MAX_DAYS'"/g' /usr/local/tomcat/conf/server.xml
sed -i 's/^\([^#].*\.maxDays\s*=\s*\).*$/\1'$LOG_MAX_DAYS'/' /usr/local/tomcat/conf/logging.properties

echo "Update ${JMANAGER_USER} password..."
python3 /usr/local/bin/reset-jahia-tools-manager-password.py "$(echo -n $JMANAGER_PASS|base64)" /usr/local/tomcat/conf/digital-factory-config/jahia/jahia.properties
sed 's/${JMANAGER_USER}/'$JMANAGER_USER'/' -i /usr/local/tomcat/conf/digital-factory-config/jahia/jahia.properties


echo "Update setenv.sh"
echo "JAVA_OPTS=\"-XX:+UseParallelGC -Xlog:gc::time,uptime,level,pid,tid,tags -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=7199 -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false -XX:+HeapDumpOnOutOfMemoryError -XX:+PrintConcurrentLocks -XX:SurvivorRatio=8\"" > /usr/local/tomcat/bin/setenv.sh
echo 'export JAVA_OPTS="$JAVA_OPTS -XX:+UseContainerSupport -XX:MaxRAMPercentage=$MAX_RAM_PERCENTAGE -DDB_HOST='$DB_HOST' -DDB_PASS='$DB_PASS' -DDB_NAME='$DB_NAME' -DDB_USER='$DB_USER'"' \
    >> /usr/local/tomcat/bin/setenv.sh
chmod +x /usr/local/tomcat/bin/setenv.sh \

echo "Update root's password..."
echo "$SUPER_USER_PASSWORD" > $FACTORY_DATA/root.pwd


case "$DBMS_TYPE" in
    "mariadb")
        DB_PORT="3306"
        check_db_access

        db_exists=$(mysql -h $DB_HOST -u $DB_USER -p$DB_PASS --protocol=tcp -e "show databases like '$DB_NAME'")
        if [ "$db_exists" == "" ]; then
            echo "Database doesn't exist. Trying to create it..."
            mysql -h $DB_HOST -u $DB_USER -p$DB_PASS --protocol=tcp -e "create database $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
            if [ $? -ne 0 ]; then
                echo "This image won't start without a working database. Exiting"
                exit 1
            fi
        fi

        tables_list=$(mysql -h $DB_HOST -u $DB_USER -p$DB_PASS --protocol=tcp -e "show tables" $DB_NAME)
        if [ "$tables_list" == "" ]; then
            echo "Database is empty. Going to initialize the database schema..."
            mysql -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME --protocol=tcp <<< $(cat /data/digital-factory-data/db/sql/schema/mysql/01*)
        fi

        testdb_result="$(mysql -u $DB_USER -p$DB_PASS -h $DB_HOST -D $DB_NAME --protocol=tcp -e "select count(REVISION_ID) from JR_J_LOCAL_REVISIONS;" -s)"
        ;;
    "postgresql")
        DB_PORT="5432"
        check_db_access

        PGPASSWORD=$DB_PASS psql -h $DB_HOST -U $DB_USER $DB_NAME -c '\x'
        if [ "$?" -ne 0 ]; then
            echo "Database doesn't exist. Trying to create it..."
            PGPASSWORD=$DB_PASS psql -h $DB_HOST -U $DB_USER -d postgres -c "create database $DB_NAME"
            if [ $? -ne 0 ]; then
                echo "This image won't start without a working database. Exiting"
                exit 1
            fi
        fi

        tables_list=$(PGPASSWORD=$DB_PASS psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "\dt" 2> /dev/null)
        if [ "$tables_list" == "" ]; then
            files_path="/data/digital-factory-data/db/sql/schema/postgresql"
            for file in $files_path/01*.sql; do
                echo "Database is empty. Going to initialize the database schema..."
                PGPASSWORD=$DB_PASS psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f $file;
            done
        fi

        testdb_result="$(PGPASSWORD=$DB_PASS psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "select count(REVISION_ID) from JR_J_LOCAL_REVISIONS;" -tAq)"
        ;;
esac

if [ $testdb_result -eq 0 ]; then
    echo " -- Database is empty, do not try to restore module states"
    RESTORE_MODULE_STATES="false"
fi

if [ "$RESTORE_MODULE_STATES" == "true" ]; then
    echo " -- Restore module states have been asked"
    touch "$FACTORY_DATA/[persisted-bundles].dorestore"
else
    echo " -- Restore module states is not needed"
fi


echo "Start catalina..."
exec /usr/local/tomcat/bin/catalina.sh run

