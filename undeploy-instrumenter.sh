#!/bin/bash

# set -x

if [[ $1 != "-s" ]]; then
    read -p "Are you sure you want to uninstall instrumenter? " -n 1 -r
    echo # (optional) move to a new line
    if ! [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Uninstall aborted by user"
        exit 0
    fi
fi

findAndDeleteContainer() {
    if [[ $(docker ps -a --format {{.Names}} | grep -w $1) ]]; then
        docker rm -f $(docker ps -a --format {{.Names}} | grep -w $1) 2>&1 >/dev/null
    fi
}

findAndDeleteNetwork() {
    if [[ $(docker network ls --format {{.Name}} | grep -w $1) ]]; then
        docker network rm $(docker network ls --format {{.Name}} | grep -w $1) 2>&1 >/dev/null
    fi
}

findAndDeleteContainer qualys-crs-instrumenter
findAndDeleteContainer qualys-docker-proxy
findAndDeleteNetwork dockersock.jail
