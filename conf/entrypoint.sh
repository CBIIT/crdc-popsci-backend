#!/bin/sh
set -e

# Fix ownership of volume-mounted paths so the non-root tomcat user can write to them
chown -R tomcat:tomcat \
    /usr/local/tomcat/logs \
    /usr/local/tomcat/work \
    /usr/local/tomcat/temp

exec gosu tomcat catalina.sh run
