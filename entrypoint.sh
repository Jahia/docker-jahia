#!/bin/bash


echo "Update jahia.properties..."
sed -e 's,${FACTORY_DATA},'$FACTORY_DATA',' \
    -e "s/^#\?\s*\(operatingMode\s*=\).*/\1 $OPERATING_MODE/" \
    -e "s/^#jahiaGeneratedResourcesDiskPath/jahiaGeneratedResourcesDiskPath/" \
    -e "s/^#\s\?\s*\(jahiaFileUploadMaxSize\s*=\).*/\1 $MAX_UPLOAD/" \
    -e "s,^#\s\?\s*\(gitPath\s*=\).*,\1 /usr/bin/git," \
    -e "s,^#\s\?\s*\(svnPath\s*=\).*,\1 /usr/bin/svn," \
    -e "s,^#\s\?\s*\(mvnPath\s*=\).*,\1 $(find /opt -type f -executable -name mvn)," \
    -i /usr/local/tomcat/conf/digital-factory-config/jahia/jahia.properties
if (which ffmpeg > /dev/null); then
    echo " -- ffmpeg is present"
    sed -e "s/^#\?\s*\(jahia.dm.thumbnails.video.enabled\s*=\).*/\1 true/" \
        -e "s,^#\?\s*\(jahia.dm.thumbnails.video.ffmpeg\s*=\).*,\1 /usr/bin/ffmpeg," \
        -i /usr/local/tomcat/conf/digital-factory-config/jahia/jahia.properties
fi
if (which soffice > /dev/null); then
    echo " -- libreoffice is present"
    sed -e "s/^#\?\s*\(documentConverter.enabled\s*=\).*/\1 true/" \
        -e "s,^#\?\s*\(documentConverter.officeHome\s*=\).*,\1 /usr/lib/libreoffice," \
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
sed -i 's/prefix="localhost_access_log"/prefix="access_log" rotatable="false"/g' /usr/local/tomcat/conf/server.xml

echo "Update ${JMANAGER_USER} password..."
python3 /usr/local/bin/reset-jahia-tools-manager-password.py "$(echo -n $JMANAGER_PASS|base64)" /usr/local/tomcat/conf/digital-factory-config/jahia/jahia.properties
sed 's/${JMANAGER_USER}/'$JMANAGER_USER'/' -i /usr/local/tomcat/conf/digital-factory-config/jahia/jahia.properties


echo "Update setenv.sh"
echo "JMX_OPTS=\-XX:+UseParallelGC" >> /usr/local/tomcat/bin/setenv.sh
echo "export JAHIA_JAVA_XMX=$XMX" >> /usr/local/tomcat/bin/setenv.sh

echo "Update root's password..."
echo "$SUPER_USER_PASSWORD" > $FACTORY_DATA/root.pwd




case "$DBMS_TYPE" in
    "mariadb") DB_PORT="3306";;
    "postgresql") DB_PORT="5432";;
esac


for n in {1..667}; do
    echo -n "Testing network database access on host $DB_HOST (test $n)... "
    [ $n -gt 666 ] && echo "We are doomed !" && exit 1
    if (nc -w 1 -v ${DB_HOST} ${DB_PORT} > /dev/null 2>&1 </dev/null); then
        echo "SUCCESS"
        break
    else
        echo "FAILED"
    fi
    sleep 1
done




echo "Start catalina..."
exec /usr/local/tomcat/bin/catalina.sh run

