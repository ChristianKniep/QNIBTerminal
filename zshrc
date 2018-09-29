## Alias
alias gs='git status'

# setup 2.0
export DOCKER_TARGET=""
export DOCKER_REG=${DOCKER_REG}
# \setup 2.0


function dsls {
    echo "REPLICAS        NAME"
    docker service ls --format "{{.Replicas}}\t\t{{.Name}}"
}

function dps {
    echo "ID              NAME"
    docker ps --format '{{.ID}}\t{{.Names}}'
}

function toggle_dorchestrator {
    if [[ "X${DOCKER_ORCHESTRATOR}" != "Xswarm" ]];then
        export DOCKER_ORCHESTRATOR=swarm
    else
        export DOCKER_ORCHESTRATOR=kubernetes
    fi
    echo "> Set DOCKER_ORCHESTRATOR=${DOCKER_ORCHESTRATOR}"
}


function d_getip {
    # returns ip of given container, if none returns last containers ip
    LAST_CONT=$(docker ps -l|egrep -v "(Exit \d|^CONTAINER ID)"|awk '{print $1}')
    DCONT=${1-${LAST_CONT}}
    if [ "X${DCONT}" == "X" ]; then
        echo "No container given"
        return 1
    else
        if [ $(docker ps|egrep -c ${1}) -eq 0 ];then
            return 0
        fi
        echo $(docker inspect -f '{{ .NetworkSettings.IPAddress }}' ${DCONT})
    fi
}

function d_getport {
    # returns external port for interal port $1 of given ($2) container
    # if $2=='' returns last containers ip
    if [ "X${1}" == "X" ]; then
        echo "No port given"
        return 1
    fi
    LAST_CONT=$(docker ps -l|egrep -v "(Exit \d|^CONTAINER ID)"|awk '{print $1}')
    DCONT=${2-${LAST_CONT}}
    if [ "X${DCONT}" == "X" ]; then
        echo "No container given"
        return 1
    else
        for line in $(docker inspect -f '{{ .NetworkSettings.Ports }}' ${DCONT}|sed -e 's/\ H/_H/g' |sed -e 's/^/"/'|sed -e "s/\]\ /\"\ \"/g"|sed -e 's/$/\"/');do
            echo $line|awk -F'] ' '{print $1}'|egrep -o "${1}.*HostPort\:[0-9]+"|sed -e 's#/tcp##'|awk -F\: '{print $NF}'
        done
    fi
}


function drun_priv {
    docker run -ti --rm --privileged \
         ${1} /bin/bash
}

function dexec {
    img=$1
    if [ "$#" -eq 1 ];then
        exe=bash
    else
        shift
        exe="$@"
    fi
    docker exec -ti ${img} ${exe}
}


function drun {
    docker run -ti --rm ${MOUNTS} ${1} /bin/bash
}

alias compose="docker-compose"

function dbuild {
    echo "> docker build '${1}'"
    docker build ${2} -t ${1} .
    EC=$?
    if [ ${EC} -ne 0 ];then
        echo ">> Build failed..."
        return ${EC}
    fi
}

