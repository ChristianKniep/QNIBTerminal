export QNIB_DNS_DOMAIN=${QNIB_DNS_DOMAIN-qnib}
export QNIB_DNS_HOST=${QNIB_DNS_HOST-dns}
export QNIB_HOST_SHARE=${QNIB_HOST_SHARE-/data/}
export QNIB_MAX_MEMORY=${QNIB_MAX_MEMORY-125M}
export QNIB_LAST_SERVICE_CPUID=${QNIB_LAST_SERVICE_CPUID-1}
export QNIB_BASE_PROJECTS="fd20 supervisor consul terminal elk grafana influxdb"
export QNIB_TERM_PROJECTS="${QNIB_PROJECTS} slurm compute slurmctld haproxy"
export QNIB_PROJECTS="${QNIB_BASE_PROJECTS} ${QNIB_TERM_PROJECTS}"
export QNIB_IBSIM_NODES=${QNIB_IBSIM_NODES-4}
export QNIB_IMG_PREFIX=${QNIB_IMG_PREFIX-qnib}
export DHOST=${DHOST-localhost}
export QNIB_PIPE=${QNIB_PIPE-0}
export QNIB_REG=${QNIB_REG}
export QNIB_CONTAINERS="consul elk influxdb grafana slurmctld compute0 haproxy"

# setup 2.0
export DOCKER_TARGET=""
export DOCKER_REG=${DOCKER_REG}
export DOCKER_DEF_HOP=""
export DOCKER_PORT=6000
export CONT_LIST_BASE="etcd dns carbon elk"
export CONT_LIST_INFO="graphite-api graphite-web grafana"
export CONT_LIST_COMPUTE="slurmctld compute0 compute1"
# \setup 2.0

function start_qnibterminal {
   # starts the complete stack
   if [ "X${1}" != "X" ];then
      MY_CONT=$*
   else
      MY_CONT=${QNIB_CONTAINERS}
   fi
   GLOBAL_EC=0
   for cont in ${MY_CONT};do
      if [ ${cont} == "dns" ];then
         IMG_NAME="helixdns"
      elif [ ${cont} == "compute0" ];then
         sleep 5
         IMG_NAME="compute"
      else
         IMG_NAME=${cont}
      fi
      if [ $(docker ps|egrep -c " qnib/${IMG_NAME}\:") -ne 0 ];then
         printf "Starting %-20s EC:%-2s CONT_ID:%s || %s\n" ${cont} OK 0 "container already running..."
         continue
      fi
      CONT_ID=$(eval "start_$(echo ${cont}|sed -e 's/-/_/g')")
      EC=$?
      if [ $(docker ps|egrep -c " qnib/${IMG_NAME}\:") -ne 1 ];then
         printf "Starting %-20s EC:%-2s CONT_ID:%s || %s\n" ${cont} NOK ${CONT_ID-X} "container was not started... :("
         return 1
      fi
      GLOBAL_EC=$(echo "${GLOBAL_EC}+${EC}"|bc)
      CONT_IP=$(d_getip ${cont})
      printf "Starting %-20s EC:%-2s CONT_IP:%s\n" ${cont} ${EC} ${CONT_IP}
      if [ ${EC} -ne 0 ];then
         return ${EC}
      fi
      if [ "X${QNIBT_DEBUG}" != "X" ];then
         echo "[press <enter> to continue]"
         read
      else
         sleep 2
      fi
   done
}

function dgit_check {
   for x in ${QNIB_PROJECTS};do 
       if [ -d docker-${x} ];then
           pushd docker-${x}
           git status -s
           popd
       fi
   done
}

function dgit_push {
   for x in ${QNIB_PROJECTS};do 
       if [ -d docker-${x} ];then
           pushd docker-${x}
           git push
           popd
       fi
   done
}

function dgit_pull {
   for x in ${QNIB_PROJECTS};do 
       if [ -d docker-${x} ];then
           pushd docker-${x}
           git pull
           popd
       fi
   done
}

function dgit_clone {
   echo -n "Where to put the git-directories? [.] "
   read WORKDIR
   if [ "X${WORKDIR}" == "X" ];then
      WORKDIR="./"
   fi
   for proj in ${QNIB_PROJECTS};do
      echo "########## docker-${proj}"
      DIR="${WORKDIR}/docker-${proj}"
      if [ -d ${DIR} ];then
         pushd ${DIR} >/dev/null
         git pull
         popd >/dev/null
      else
         git clone https://github.com/ChristianKniep/docker-${proj}.git
      fi
   done
}

function dgit_build {
   echo -n "Where create git-directories? [.] "
   read WORKDIR
   if [ "X${WORKDIR}" == "X" ];then
      WORKDIR="./"
   fi
   if [ "X${1}" != "X" ];then
      MY_PROJECTS=$*
   else
      MY_PROJECTS=${QNIB_PROJECTS}
   fi
   for proj in ${MY_PROJECTS};do
      DIR="${WORKDIR}/docker-${proj}"
      if [ -d ${DIR} ];then
         echo "########## build> qnib/${proj}"
         pushd ${DIR} >/dev/null
         docker build --rm -t qnib/${proj} .
         EC=$?
         if [ ${EC} -ne 0 ];then
            echo "'docker build --rm -t qnib/${proj} .' failed with EC:${EC}"
            return 1
         fi
         popd >/dev/null
         sleep 2
      fi
      done
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

function d_getcpu {
   cpuid=$(docker inspect -f '{{ .HostConfig.LxcConf }}' ${1}|sed -e 's/\[map\[Key:lxc.cgroup.cpuset.cpus Value://'|sed -e 's/\]\]//')
   printf "%-20s %s\n" $1 ${cpuid}
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

function eval_cpuset {
   # returns cpuset.cpus for different types`
   if [ "X${1}" == "Xelk" ];then
      if [ ${QNIB_LAST_SERVICE_CPUID} -eq 2 ];then
         echo 0,1
         return 0
      fi
   elif [[ "X${1}" == Xgraphite* ]];then
      if [ ${QNIB_LAST_SERVICE_CPUID} -eq 2 ];then
         echo 0,1
         return 0
      fi
   elif [[ "X${1}" == Xcompute* ]] ; then
      comp_id=$(echo ${1} | sed 's/compute\([0-9]*\)/\1/')
      echo "(${comp_id} / 16) + ${QNIB_LAST_SERVICE_CPUID}"|bc
      return 0
   elif [ "X${1}" == "Xqnibng" ];then
      if [ ${QNIB_LAST_SERVICE_CPUID} -eq 2 ];then
         echo 0,1
         return 0
      fi
   fi
   echo 0
   return 0
}



function start_nginxproxy {
   CON_VOL=""
   CON_LINKED=""
   DETACHED=${1-0}
   FORWARD_PORTS="9200 80"
   OPTS="--privileged"
   MOUNTS=""
   start_function nginxproxy ${DETACHED}
}

function start_qnibng {
   CON_VOL=""
   CON_LINKED="carbon elk"
   DETACHED=${1-0}
   FORWARD_PORTS=""
   OPTS="--privileged -e IBSIM_NODES=${QNIB_IBSIM_NODES}"
   if [ -e /dev/infiniband ];then
      OPTS="${OPTS} -v /dev/infiniband/:/dev/infiniband/"
   fi
   MOUNTS="/home/docker/:/home/docker/"
   start_function qnibng ${DETACHED}
}

function start_haproxy {
   CON_VOL=""
   CON_LINKED=""
   DETACHED=${1-0}
   FORWARD_PORTS="80 9200"
   MOUNTS=""
   OPTS=""
   start_function haproxy ${DETACHED}
}

function start_grafana {
   CON_VOL=""
   CON_LINKED=""
   DETACHED=${1-0}
   FORWARD_PORTS=""
   MOUNTS=""
   OPTS=""
   start_function grafana ${DETACHED}
}


function start_slurmctld {
   CON_VOL=""
   CON_LINKED=""
   DETACHED=${1-0}
   FORWARD_PORTS=""
   MOUNTS="${QNIB_HOST_SHARE}/chome:/chome"
   OPTS=""
   start_function slurmctld ${DETACHED}
}

function start_ib {
   CON_VOL=""
   CON_LINKED=""
   DETACHED=${2-0}
   CON_NAME=${1}
   FORWARD_PORTS=""
   MOUNTS="${HOST_SHARE}/chome:/chome"
   OPTS="--privileged -v /dev/infiniband/:/dev/infiniband/"
   start_function infiniband ${DETACHED} ${CON_NAME}

}

function d_getcpus {
   if [ $# -eq 0 ];then
      CONTAINERS=${QNIB_CONTAINERS}
   else
      CONTAINERS=$*
   fi
   for comp in ${CONTAINERS};do d_getcpu ${comp};done
}

function start_comp {
   #starts slurm container and links with DNS
   CON_VOL=""
   CON_LINKED=""
   IMG_NAME=compute
   CON_NAME=${1}
   FORWARD_PORTS=""
   if [[ "X${1}" != Xcompute* ]] ; then
      echo "1st argument must be 'compute\d+'"
      return 1
   else
      if [ $(docker ps|egrep -c "${CON_NAME}\s+$") -eq 1 ];then
         echo "Container already started?!"
         return 1
      fi
   fi
   DETACHED=${2-0}
   OPTS="--memory=${QNIB_MAX_MEMORY}"
   MOUNTS="${QNIB_HOST_SHARE}/chome:/chome"
   if [ "X${QNIB_IB}" != "X" ];then
      OPTS="${OPTS} --privileged -v /dev/infiniband/:/dev/infiniband/"
   fi
   FORWARD_PORTS=""
   start_function ${IMG_NAME} ${DETACHED} ${CON_NAME}
}


function d_shutdown {
   #removes exited container
   NOT=${1-0}
   for cont in $(docker ps -a|grep Up|awk '{print $1}'|xargs);do
      docker stop ${cont}
   done
}

function d_garbage_collect {
   #removes exited container
   NOT=${1-0}
   if [ "X${NOT}" == "X0" ];then
      docker rm $(docker ps -a|grep -v Up|grep -v CONTAINER|awk '{print $1}'|xargs)
   else
      for cont in $(docker ps -a|grep Exit|grep ${NOT}|awk '{print $1}'|xargs);do
         echo -n "${cont} [n/Y] "
         read ok
         if [ "X${ok}" == "X" ];then
            docker rm ${cont}
         fi
      done
   fi
}

## start 2.0
function set_dockerenv {
    for item in $(env);do
        if [[ ${item} == DOCKER_* ]];then
            key=$(echo ${item}| awk -F\= '{print $1}')
            val=$(echo ${item}| sed -e "s/${key}\=//")
                
            if [ ${key} == "DOCKER_HOST" ];then
                echo -n "${key}? [${val} # <blank to reset>] "
                read new
                export ${key}="${new}"
            else
                echo -n "${key}? [${val}] "
                read new_val
                if [ "X${new_val}" != "X" ];then
                    export ${key}="${new_val}"
                else
                    export ${key}="${val}"
                fi
            fi
        fi
    done
    if [ "X${DOCKER_HOST}" != "X" ];then
        echo "DOCKER_HOST already set '${DOCKER_HOST}' (unset DOCKER_HOST to proceed)"
    else
        echo -n "# Do you have direct access to the docker server '${DOCKER_TARGET}'? [Y/n] "
        read inp
        if [ "${inp}" == "n" ];then
            ask_hop
            check_hop
            DTUNNEL_LOCAL_PORT=$(get_free_port)
            echo "# > create STUNNEL: ${DTUNNEL_LOCAL_PORT}:${DOCKER_TARGET}:${DOCKER_PORT} ${DOCKER_HOP}"
            ssh -N -f -L ${DTUNNEL_LOCAL_PORT}:${DOCKER_TARGET}:${DOCKER_PORT} ${DOCKER_HOP}
            export DOCKER_HOST=tcp://localhost:${DTUNNEL_LOCAL_PORT}
            export DHOST="${DOCKER_HOP}->${DOCKER_TARGET}"
        else
            export DHOST="${DOCKER_TARGET}"
            export DOCKER_HOST=tcp://${DOCKER_TARGET}:${DOCKER_PORT}
            
        fi
        
    fi
}
function d_start {
   ###### Starts a container
   ## if $1==1 it will start into a bash
    if [ "X${INTERACTIVE}" != "X0" ];then
        if [ "X${INTERACTIVE}" != "X1" ];then
            CMD=/bin/bash
        else
            CMD=${INTERACTIVE}
        fi
        docker run -ti --rm ${OPTS} qnib/${CONT_NAME} ${CMD}
    else
        printf "# Start %-20s as %-30s > " "'${CONT_NAME}'" "'${USER}_${NAME}'"
        CONT_ID=$(docker run -d ${OPTS} qnib/${CONT_NAME})
        EC=$?
        if [ ${EC} -eq 0 ];then
            echo "[OK]   IP: $(d_getip ${USER}_${NAME})"
        else
            echo "[FAIL] EC: ${EC}"
        fi
    fi
}

function stop_cont {
    NAME=${1}
    docker rm -f ${USER}_${NAME}
}

function start_cont {
    ## starts container resolve options by name
    NAME=${1}
    CONT_NAME=${NAME}
    OPTS="--name ${USER}_${NAME} -h ${NAME} -p 22 --dns-search=qnib"
    OPTS="${OPTS} --privileged -v /dev/null:/dev/null -v /dev/random:/dev/random -v /dev/urandom:/dev/urandom"
    if [ ${NAME} != 'dns' -a $(docker ps |egrep -c "qnib/[a-z]+dns.*${USER}.*$") -eq 1 ];then
        OPTS="${OPTS} --dns $(d_getip ${USER}_dns)"
    fi
    if [ "X${SYNC_DIR}" != "X" ];then
        OPTS="${OPTS} -v ${SYNC_DIR}:/data/"
    fi
    INTERACTIVE=${2-0}
    case ${NAME} in
        dns)
            CONT_NAME="skydns"
            OPTS="${OPTS} --dns 127.0.0.1"
            if [ $(docker ps|egrep -c "7001/tcp.*${USER}.*$") -eq 1 ];then
                OPTS="${OPTS} --link ${USER}_etcd:etcd"
            fi
        ;;
        skydock)
            OPTS="${OPTS} -v /var/run/docker.sock:/docker.sock"
        ;;
        term*)
            CONT_NAME="terminal"
        ;;
        compute*)
            CONT_NAME="compute"
        ;;
        etcd)
            OPTS="${OPTS} -p 4001 -p 7001"
        ;;
        carbon)
            OPTS="${OPTS} -p 2003 -p 2004 -p 7002 -v /var/lib/carbon/whisper/"
        ;;
        graphite-web|graphite-api)
            OPTS="${OPTS} -p 80 --volumes-from ${USER}_carbon "
        ;;
        elk)
            HTTP_PORT=8080
            OPTS="${OPTS} -e HTTPPORT=${HTTP_PORT} -p ${HTTP_PORT}:80"
        ;;
        grafana)
            OPTS="${OPTS} -p 80"
        ;;
    esac
    d_start
}

function qssh_base {
    ### ssh into given container
    # if no name is given fvt is used
    TARGET=${1-fvt}
    DCONT=$(docker ps |egrep -o "${USER}_${TARGET}")
    DHOST=$(echo $DOCKER_HOST |egrep -o "[A-Za-z0-9\.\:]+$"|awk -F\: '{print $1}')
    DPORT=$(echo $DOCKER_HOST |egrep -o "\:[0-9]+$"|awk -F\: '{print $2}')
    DO_HOP=0
    if [ ${DHOST} == "localhost" ];then
        # if we are on localhost, we might check if there is a stunnel to the DOCKER PORT
        HOP_HOST=$(ps -ef|grep -v grep|egrep -o "${DPORT}\:.*\:6000.*"|awk '{print $NF}')
        echo "# HOP_HOST: ${HOP_HOST}"
        DTUNNEL=$(ps -ef|grep -v grep|egrep -o "${DPORT}\:.*\:6000.*"|awk '{print $1}')
        D_DEST=$(echo ${DTUNNEL}|awk -F\: '{print $2}')
        echo "# D_DEST: ${D_DEST}"
        DO_HOP=1
    fi
    if [ "X${DCONT}" == "X" ];then
        echo "Sorry, no container named ${USER}_${TARGET} found..."
        return 1
    fi
    SSH_PORT=$(d_getport 22 ${DCONT})
    if [ "X${SSH_PORT}" == "X" ];then
        echo "Sorry, the container ${USER}_${TARGET} does not expose port 22..."
        return 1
    fi
}
function qssh {
    qssh_base $*
    shift
    # if we hop, then we have to take the hop
    if [ ${DO_HOP} -eq 1 ];then
        ssh -A -oStrictHostKeyChecking=no -oLogLevel=quiet -oUserKnownHostsFile=/dev/null ${HOP_HOST} -t ssh -p ${SSH_PORT} root@${DOCKER_TARGET} $*
    else
        ssh -oStrictHostKeyChecking=no -oLogLevel=quiet -oUserKnownHostsFile=/dev/null -p ${SSH_PORT} root@${DHOST} $*
    fi
}
function qscp_to {
    qssh_base $*
    shift
    # if we hop, then we have to take the hop
    if [ ${DO_HOP} -eq 1 ];then
        scp -oStrictHostKeyChecking=no $1 ${HOP_HOST}:
        ssh -A -oStrictHostKeyChecking=no ${HOP_HOST} -t scp -oUserKnownHostsFile=/dev/null -P ${SSH_PORT} $1 root@${DOCKER_TARGET}:$2
    else
        scp -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -P ${SSH_PORT} $1 root@${DHOST}:$2
    fi
}
function qscp_from {
    qssh_base $*
    shift
    # if we hop, then we have to take the hop
    if [ ${DO_HOP} -eq 1 ];then
        ssh -A -oStrictHostKeyChecking=no ${HOP_HOST} -t scp -oUserKnownHostsFile=/dev/null -P ${SSH_PORT} $1 root@${DOCKER_TARGET}:$2
        scp -oStrictHostKeyChecking=no ${HOP_HOST}:$1 .
    else
        scp -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -P ${SSH_PORT} root@${DHOST}:$1 $2
    fi
}



function list_stop {
    for cont in $*;do
        stop_cont ${cont}
    done
}
function list_status {
    for cont in $*;do
        status_cont ${cont}
    done
}
function list_start {
    for cont in $*;do
        start_cont ${cont}
    done
}
function start_qtbase {
    ### starts the containers needed for qnibterminal
    list_start ${CONT_LIST_BASE}
}
function stop_qtbase {
    ### starts the containers needed for qnibterminal
    list_stop ${CONT_LIST_BASE}
}
function status_cont {
    IP=$(d_getip ${USER}_${1})
    if [ "X${IP}" == "X" ];then
        return 0
    fi
    PORTS=""
    for line in $(docker inspect -f '{{ .NetworkSettings.Ports }}' ${USER}_${1}|sed -e 's/\ H/_H/g' |sed -e 's/^/"/'|sed -e "s/\]\ /\"\ \"/g"|sed -e 's/$/\"/');do
        SPORT=$(echo $line|awk -F'] ' '{print $1}'|egrep -o "[0-9]+.*HostPort\:[0-9]+"|awk -F\/ '{print $1}')
        DPORT=$(echo $line|awk -F'] ' '{print $1}'|egrep -o "[0-9]+.*HostPort\:[0-9]+"|sed -e 's#/tcp##'|awk -F\: '{print $NF}')
        if [ "X${PORTS}" != "X" ];then
            PORTS="${PORTS} "
        fi
        PORTS="${PORTS}${SPORT}:${DPORT}"
    done
    STAT_STR=""
    STAT_STR="[\e[32mO\e[0m\e[42mE\e[0m\e[34mS\e[91mF\e[93m?\e[0m] "
    for line in $(qssh ${1} supervisorctl status|awk '{print $1"_"$2}');do
        PROC=$(echo $line|awk -F_ '{print $1}')
        STAT=$(echo $line|awk -F_ '{print $2}')
        case $STAT in
            RUNNING)
                STAT_STR=" ${STAT_STR}\e[32m${PROC}\e[0m "
            ;;
            EXITED)
                STAT_STR=" ${STAT_STR}\e[42m${PROC}\e[0m "
            ;;
            STOPPED)
                STAT_STR=" ${STAT_STR}\e[34m${PROC}\e[0m " 
            ;;
            FATAL|BACKOFF)
                STAT_STR=" ${STAT_STR}\e[91m${PROC}\e[0m "
            ;;
            STARTING)
                STAT_STR=" ${STAT_STR}\e[5m\e[32m${PROC}\e[0m "
            ;;
            *)
                STAT_STR=" ${STAT_STR}\e[93m${PROC}\e[0m "
            ;;
        esac
    done
    printf "%-20s %-20s %-40s ${STAT_STR}\n" "${USER}_${1}" "${IP}" "${PORTS}"
}
function status_qtbase {
    list_status ${CONT_LIST_BASE}
}
function start_qtinfo {
    ### starts the containers needed for qnibterminal
    list_start ${CONT_LIST_INFO}
}
function stop_qtinfo {
    ### starts the containers needed for qnibterminal
    list_stop ${CONT_LIST_INFO}
}
function start_qtcomp {
    ### starts the containers needed for qnibterminal
    list_start ${CONT_LIST_COMPUTE}
}
function stop_qtcomp {
    ### starts the containers needed for qnibterminal
    list_stop ${CONT_LIST_COMPUTE}
}
function start_qt {
    start_qtbase
    start_qtinfo
}
function stop_qt {
    stop_qtinfo
    stop_qtbase
}
function drun_pure {
    docker run -ti --rm \
         ${1} /bin/bash
}

function dexec {
    docker exec -ti ${1} /bin/bash
}

function drun {
    MOUNTS="-v /dev/null:/dev/null -v /dev/urandom:/dev/urandom"
    MOUNTS="${MOUNTS} -v /dev/random:/dev/random -v /dev/zero:/dev/zero"
    if [ "X${SYNC_DIR}" != "X" ];then
        MOUNTS=" ${MOUNTS} -v ${SYNC_DIR}:/project/"
    fi
    docker run -ti --rm --privileged ${MOUNTS} ${1} /bin/bash
}

## Aliases
alias add_repo='img_name=$(grep FROM Dockerfile |egrep -o "qnib.*");sed -i -e "s#FROM.*#FROM n36l:5000/${img_name}#" Dockerfile'
alias rm_repo='img_name=$(grep FROM Dockerfile |egrep -o "qnib.*");sed -i -e "s#FROM.*#FROM ${img_name}#" Dockerfile'
