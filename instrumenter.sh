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
CLI_MODE="true"
IMAGE="false"
POLICY_ID="false"
CLI_MODE_ARGS="-cli-mode"
INSTRUMETER_IMAGE="qualys/crs-instrumenter:latest"
DOCKER_RUN_ARGS="-itd --name qualys-crs-instrumenter --network dockersock.jail "

# read the options
# TEMP=`getopt -o d:e:v:h --long help,docker-url:,endpoint:,proxy:,vault-token:,vault-engine:,vault-base64,vault-path:,vault-address:,cli-mode,image:,policyid: -- "$@"`
# eval set -- "$TEMP"

usage() {
    echo """
username: CRS Username
password: CRS Password
endpoint: Qualys endpoint for instrumenter (Pod URL) (Mandatory)
proxy: Proxy url for your system

Usage Examples:
Default Example:
CLI:
./instrumenter.sh --endpoint <endpoint> --image <image> [--policyid <policy id>]
Daemon:
./instrumenter.sh --endpoint <endpoint> --daemon-mode

Vault Example:
CLI:
./instrumenter.sh --endpoint <endpoint> --vault-token <token> --vault-engine <engine version> [--vault-base64] --vault-path <vault-path> --vault-address <vault-address>  --image <image> [--policyid <policy id>]
Daemon:
./instrumenter.sh --endpoint <endpoint> --vault-token <token> --vault-engine <engine version> [--vault-base64] --vault-path <vault-path> --vault-address <vault-address> --daemon-mode

Proxy Example:
CLI:
./instrumenter.sh --endpoint <endpoint> --proxy <proxy> --image <image> [--policyid <policy id>]
Daemon:
./instrumenter.sh --endpoint <endpoint> --proxy <proxy> --daemon-mode

Note: endpoint should be of the form username:password@url if you are not using vault; otherwise just url is needed
""" ;
}

# extract options and their arguments into variables.
while [[ $# -gt 0 ]] ; do
    case "$1" in
        -h|--help)
            usage ; exit 0 ;;
        -v|--proxy)
            PROXY=$2 ; shift 2 ;;
        -v=*|--proxy=*)
            PROXY="${1#*=}"
            shift # past argument=value
            ;;
        -d|--docker-url)
            DOCKER_URL=$2 ; shift 2 ;;
        -d=*|--docker-url=*)
            DOCKER_URL="${1#*=}"
            shift # past argument=value
            ;;
        -e|--endpoint)
            ENDPOINT=$2 ; shift 2 ;;
        -e=*|--endpoint=*)
            ENDPOINT="${1#*=}"
            shift # past argument=value
            ;;
        --vault-engine)
            V_ENGINE=$2 ; shift 2 ;;
        --vault-engine=*)
            V_ENGINE="${1#*=}"
            shift # past argument=value
            ;;
        --vault-base64)
            V_BASE64="true"; shift ;;
        --vault-path)
            V_PATH=$2 ; shift 2 ;;
        --vault-path=*)
            V_PATH="${1#*=}"
            shift
            ;;
        --vault-address)
            V_ADDRESS=$2 ; shift 2 ;;
        --vault-address=*)
            V_ADDRESS="${1#*=}"
            shift
            ;;
        --vault-token)
            V_TOKEN=$2 ; shift 2 ;;
        --vault-token=*)
            V_TOKEN="${1#*=}"
            shift
            ;;
        --daemon-mode)
            CLI_MODE_ARGS="" ; CLI_MODE="false" ; shift ;;
        --image)
            CLI_MODE_ARGS="$CLI_MODE_ARGS -image=$2" ; IMAGE="true" ; shift 2 ;;
        --image=*)
            TEMP="${1#*=}"
            CLI_MODE_ARGS="$CLI_MODE_ARGS -image=$TEMP" ; IMAGE="true" ;
            shift
            ;;
        --policyid)
            CLI_MODE_ARGS="$CLI_MODE_ARGS -policyid=$2" ; POLICY_ID="true" ; shift 2 ;;
        --policyid=*)
            TEMP="${1#*=}"
            CLI_MODE_ARGS="$CLI_MODE_ARGS -policyid=$TEMP" ; IMAGE="true" ;
            shift
            ;;
        --) shift ; break ;;
        *) usage ; exit 1 ;;
    esac
done

create_network() {
    # create isolated network
    if [[ $CLI_MODE == "true" ]]; then
        echo "network id: $(docker network create -d bridge dockersock.jail.$1)"    
        return
    fi
    echo "network id: $(docker network create -d bridge dockersock.jail)"
}

start_proxy() {
    
    if [[ $CLI_MODE == "true" ]]; then
        echo "proxy container id: $(docker run -d --name qualys-docker-proxy-$1 --restart=always --network dockersock.jail.$1 -v /var/run/docker.sock:/var/run/docker.sock alpine/socat tcp-listen:2375,fork,reuseaddr unix-connect:/var/run/docker.sock)"
        return
    fi
    # create docker.sock proxy
    echo "proxy container id: $(docker run -d --name qualys-docker-proxy --restart=always --network dockersock.jail -v /var/run/docker.sock:/var/run/docker.sock alpine/socat tcp-listen:2375,fork,reuseaddr unix-connect:/var/run/docker.sock)"
} 

create_instrumenter() {
    if [[ $DOCKER_URL == "" ]]; then
        DOCKER_URL="tcp://qualys-docker-proxy.dockersock.jail:2375";
        if [[ $CLI_MODE == "true" ]]; then
            DOCKER_URL="tcp://qualys-docker-proxy-$1.dockersock.jail.$1:2375";
        fi
    fi

    if [[ $CLI_MODE == "true" ]]; then
        echo "Running in CLI Mode"
        INSTRUMETER_IMAGE="qualys/crs-cli-instrumenter:latest"
        DOCKER_RUN_ARGS="-it --name qualys-crs-cli-instrumenter-$1 --network dockersock.jail.$1"
        DOCKER_URL="tcp://qualys-docker-proxy-$1.dockersock.jail.$1:2375";
    else
        echo "Running in daemon Mode"
    fi

    docker pull $INSTRUMETER_IMAGE
    if [[ "$?" -ne "0" ]]; then
        echo "Error pulling docker image please contact qualys support"
        exit 2;
    fi
    # create instrumenter
    # endpoint should be of the form username:password@url if you are not using vault otherwise just url is needed
    echo "instrumenter id: $(docker run $DOCKER_RUN_ARGS \
    -e LI_ALLOWHTTPPROXY=$IS_PROXY -e https_proxy=$PROXY -e LI_MQSKIPVERIFYTLS=$SKIP_TLS \
    -e DOCKER_HOST=$DOCKER_URL \
    -e LI_VAULT_SECRET_ENGINE=$V_ENGINE -e LI_VAULT_DATA_VALUES_BASE64=$V_BASE64 \
    -e LI_VAULTPATH=$V_PATH -e LI_VAULT_TOKEN=$V_TOKEN -e LI_VAULT_ADDRESS=$V_ADDRESS \
    -e LI_MQURL=qas://$ENDPOINT \
    $INSTRUMETER_IMAGE \
    $CLI_MODE_ARGS)"
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

    if [[ $CLI_MODE == "true" ]]; then 
        if [[ $IMAGE == "false" ]]; then 
            echo "Please mention image to instrument"
            usage
            exit 1
        fi
    fi
}

validate_params
RANDOM=$$
ID=""
if [[ $CLI_MODE == "true" ]]; then 
   ID="$RANDOM"
   while [[ $(docker ps -a --format {{.Names}} | grep -w dockersock.jail.$ID) ]] 
   do
    ID="$RANDOM"
   done
fi

create_network $ID

if [[ $DOCKER_URL == "" ]]; then
    echo "DOCKER_URL not provided so creating a docker proxy from default docker host"
    start_proxy $ID
fi

create_instrumenter $ID


# CLI Delete procedure

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

if [[ $CLI_MODE == "true" ]]; then 
    findAndDeleteContainer "qualys-crs-cli-instrumenter-$ID"
    findAndDeleteContainer "qualys-docker-proxy-$ID"
    findAndDeleteNetwork "dockersock.jail.$ID"
fi
