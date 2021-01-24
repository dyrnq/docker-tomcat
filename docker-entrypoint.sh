#!/bin/bash

# Exit immediately if a *pipeline* returns a non-zero status. (Add -x for command tracing)
set -e


if [ ! -z "$TOMCAT_USER_ID" ] && [ ! -z "$TOMCAT_GROUP_ID" ]; then
    ###
    # Tomcat user
    ###
    groupadd -r tomcat --gid=${TOMCAT_GROUP_ID} && useradd -g tomcat --uid=${TOMCAT_USER_ID} --home-dir=${CATALINA_HOME} --shell=/sbin/nologin -c "Tomcat user" tomcat

    ###
    # Change CATALINA_HOME ownership to tomcat user and tomcat group
    # Restrict permissions on conf
    ###

    chown -R tomcat:tomcat ${CATALINA_HOME} && chmod 400 ${CATALINA_HOME}/conf/*
    sync
    exec gosu tomcat "$@"
fi

exec "$@"