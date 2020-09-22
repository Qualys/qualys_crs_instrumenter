#!/bin/bash
# set -x  

#declare const

USERNAME=""
PASSWORD=""
DOCKER_URL=""
ENDPOINT=""
# proxy const
IS_PROXY=""
PROXY=""
SKIP_TLS="true"
# vault const
V_ENGINE="" 
V_BASE64=""
V_PATH="" 
V_TOKEN=""
V_ADDRESS=""
STORAGE="/etc/layint/lilibs"

# read the options
TEMP=`getopt -o d:e:v:h --long help,docker-url:,endpoint:,proxy:,vault-token:,vault-engine:,vault-base64,vault-path:,vault-address: -- "$@"`
eval set -- "$TEMP"

usage() {
    echo """
username: CRS Username
password: CRS Password
endpoint: Qualys endpoint for instrumenter (Pod URL) (Mandatory)
proxy: Proxy url for your system

Usage Examples:
Default Example:
./deploy-instrumenter.sh --endpoint <endpoint>

Vault Example:
./deploy-instrumenter.sh --endpoint <endpoint> --vault-token <token> --vault-engine <engine version> [--vault-base64] --vault-path <vault-path>

Proxy Example:
./deploy-instrumenter.sh --endpoint <endpoint> --proxy <proxy>

Note: endpoint should be of the form username:password@url if you are not using vault; otherwise just url is needed
""" ;
}

# extract options and their arguments into variables.
while true ; do
    case "$1" in
        -h|--help)
            usage ; exit 0 ;;
        -v|--proxy)
            PROXY=$2 ; shift 2 ;;
        -d|--docker-url)
            DOCKER_URL=$2 ; shift 2 ;;
        -e|--endpoint)
            ENDPOINT=$2 ; shift 2 ;;
        --vault-engine)
            V_ENGINE=$2 ; shift 2 ;;
        --vault-base64)
            V_BASE64="true"; shift ;;
        --vault-path)
            V_PATH=$2 ; shift 2 ;;
        --vault-address)
            V_ADDRESS=$2 ; shift 2 ;;
        --) shift ; break ;;
        *) usage ; exit 1 ;;
    esac
done

create_network() {
    # create isolated network
    echo "network id: $(docker network create -d bridge dockersock.jail)"
}

start_proxy() {
    # create docker.sock proxy
    echo "proxy container id: $(docker run -d --name qualys-docker-proxy --restart=always --network dockersock.jail -v /var/run/docker.sock:/var/run/docker.sock alpine/socat tcp-listen:2375,fork,reuseaddr unix-connect:/var/run/docker.sock)"
} 

create_instrumenter() {
    if [[ $DOCKER_URL == "" ]]; then
        DOCKER_URL="tcp://qualys-docker-proxy.dockersock.jail:2375";
    fi
    mkdir -p $STORAGE

    # create instrumenter
    # endpoint should be of the form username:password@url if you are not using vault otherwise just url is needed
    echo "instrumenter id: $(docker run -itd --name qualys-crs-instrumenter --network dockersock.jail \
    -e LI_ALLOWHTTPPROXY=$IS_PROXY -e https_proxy=$PROXY -e LI_MQSKIPVERIFYTLS=$SKIP_TLS \
    -e DOCKER_HOST=$DOCKER_URL \
    -e LI_VAULT_SECRET_ENGINE=$V_ENGINE -e LI_VAULT_DATA_VALUES_BASE64=$V_BASE64 \
    -e LI_VAULTPATH=$V_PATH -e LI_VAULT_TOKEN=$V_TOKEN -e LI_VAULT_ADDRESS=$V_ADDRESS \
    -e LI_MQURL=qas://$ENDPOINT \
    qualys/crs-instrumenter:latest)"
}

validate_params() {
    if [[ $ENDPOINT == "" ]]; then
        echo "Please enter endpoint";
        usage
        exit 1;
    fi

    if [[ $V_ADDRESS != "" ]]; then
        if [[ $V_ENGINE == "" || $V_TOKEN == "" || $V_PATH == "" ]]; then 
            echo "Please provide all params for vault";
            usage
            exit 1;
        fi
    fi

    if [[ $PROXY != "" ]]; then
        IS_PROXY="true"
    fi

}

validate_params
create_network

if [[ $DOCKER_URL == "" ]]; then
    echo "DOCKER_URL not provided so creating a docker proxy from default docker host"
    start_proxy
fi

create_instrumenter
