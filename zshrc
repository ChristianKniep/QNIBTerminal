export DHOST=${DHOST-localhost}
export QNIB_REG=${QNIB_REG}

# setup 2.0
export DOCKER_TARGET=""
export DOCKER_REG=${DOCKER_REG}
# \setup 2.0

function dgit_check {
   for x in ${QNIB_PROJECTS};do 
       if [ -d docker-${x} ];then
           pushd docker-${x}
           git status -s
           popd
       fi
   done
}

function dbranch {
    cur=$(git branch|grep "^*"|awk '{print $2}')
    for br in $(git branch|egrep -o "[0-9a-z\.\-]+$");do
        git checkout ${br}
        dbuild ${1}:${br}
    done
    git checkout ${cur}
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

function dgit_push {
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
         git push
         popd >/dev/null
      fi
   done
}

function dgit_pull {
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



function d_getcpus {
   if [ $# -eq 0 ];then
      CONTAINERS=${QNIB_CONTAINERS}
   else
      CONTAINERS=$*
   fi
   for comp in ${CONTAINERS};do d_getcpu ${comp};done
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

function drun_pure {
    docker run -ti --rm \
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

function dbuild {
    docker build --rm ${2} -t ${1} .
    if [ "X${DOCKER_REG}" != "X" ];then
        echo ">> docker tag -f ${1} ${DOCKER_REG}/${1}"
        docker tag -f ${1} ${DOCKER_REG}/${1}
        docker push ${DOCKER_REG}/${1}
    fi
}

function drun {
    MOUNTS="-v /dev/null:/dev/null -v /dev/urandom:/dev/urandom"
    MOUNTS="${MOUNTS} -v /dev/random:/dev/random -v /dev/zero:/dev/zero"
    if [ "X${SYNC_DIR}" != "X" ];then
        MOUNTS=" ${MOUNTS} -v ${SYNC_DIR}:/project/"
    fi
    docker run -ti --rm --privileged ${MOUNTS} ${1} /bin/bash
}

alias compose="docker-compose"
function cup {
    CFILE=""
    if [ "X${COMPOSE_FILE}" != "X" ];then
        CFILE="-f ${COMPOSE_FILE}"
    fi
    docker-compose ${CFILE} up -d $@
}
function ckill {
    # Kill docker-compose stack
    CFILE=""
    if [ "X${COMPOSE_FILE}" != "X" ];then
        CFILE="-f ${COMPOSE_FILE}"
    fi
    docker-compose ${CFILE} kill $@;docker-compose ${CFILE} rm --force
}
function crecreate {
    ckill $@;docker-compose up -d --no-recreate
}

# add registry
function add_reg {
    if [ -f Dockerfile ];then
       add_reg_to_dockerfile
    fi
    if [ -f docker-compose.yml ];then
       add_reg_to_compose
    fi
    if [ -f base.yml ];then
       add_reg_to_compose base.yml
    fi
}
function add_reg_to_dockerfile {
    IMG_NAME=$(grep ^FROM Dockerfile | awk '{print $2}')
    if [ $(echo ${IMG_NAME} | grep -o "/" | wc -l) -gt 2 ];then
        echo "Sure you wanna add the registry? Looks not right: ${IMG_NAME}"
    elif [ $(echo ${IMG_NAME} | grep -o "/" | wc -l) -eq 0 ];then
        echo "Image is an official one, so we skip it '${IMG_NAME}'"
    else
        if [ -z ${DOCKER_REG} ];then
            echo -n "The registry name? "
            read DOCKER_REG
            export DOCKER_REG=${DOCKER_REG}
        fi
        sed -i '' -e "s#FROM.*#FROM ${DOCKER_REG}/${IMG_NAME}#" ${1-Dockerfile}
   fi
}
function add_reg_to_compose {
   sed -i '' -e "s#image: \(.*\)#image: ${DOCKER_REG}/\1#" ${1-docker-compose.yml}
}

####  remove DOCKER_REG from files
function rm_reg_from_dockerfile {
    IMG_NAME=$(grep ^FROM Dockerfile|awk '{print $2}')
    if [ $(echo ${IMG_NAME} | grep -o "/" | wc -l) -eq 2 ];then
        NEW_NAME=$(echo ${IMG_NAME} | awk -F/ '{print $2"/"$3}') 
        sed -i '' -e "s#FROM.*#FROM ${NEW_NAME}#" Dockerfile
    else
        echo ${IMG_NAME}
    fi
}
function rm_reg_from_compose {
   sed -i '' -E 's#image\:.*/([a-z0-9]+/[a-z0-9\-\:]+)#image: \1#' ${1-docker-compose.yml}
}
function rm_reg {
    if [ -f Dockerfile ];then
       rm_reg_from_dockerfile
    fi
    if [ -f docker-compose.yml ];then
       rm_reg_from_compose
    fi
    if [ -f base.yml ];then
       rm_reg_from_compose base.yml
    fi
}


function get_default_dhost {
    touch ~/.docker_hosts
    if [ "X${1}" = "X"  -a  $(egrep -c ".*\s+DEFAULT$" ~/.docker_hosts) -eq 1 ];then
         echo $(egrep ".*\s+DEFAULT$" ~/.docker_hosts | cut -d' ' -f 2)
  	elif [ $(machine ls|grep -v ^NAME|wc -l) -eq 1 ];then
		echo $(machine ls|grep -v ^NAME)
    else
        echo $(machine ls|grep "*"|awk '{print $1}')
    fi 
       
}

function get_dckr_cfg {
    #### checks for ~/.docker_hosts file and fetches configuration for given alias
    # format:
    #    <alias> <host/ip>:port[:ca_cert_dir]
    # - if ca_cert_dir is set TLS is activated, otherwise it's not
    if [ -f ~/.docker_hosts ];then
        if [ $(egrep -c "^${1}\s+" ~/.docker_hosts) -eq 1 ];then
            echo $(egrep "^${1}\s+" ~/.docker_hosts | cut -d' ' -f 2)
            return 0
        elif [ $(egrep -c "^${1}\s+" ~/.docker_hosts) -gt 1 ];then
            echo "[ERROR] More then one match..."
            return 2
        elif [ "X${1}" = "X"  -a  $(egrep -c ".*\s+DEFAULT$" ~/.docker_hosts) -eq 1 ];then
            echo $(egrep ".*\s+DEFAULT$" ~/.docker_hosts | cut -d' ' -f 2)
            return 0
        else
            echo "no match"
            return 1
        fi
    else
        echo "Couldn't find '~/.docker_hosts'..."
        return 1
    fi
}

function set_dhost {
    DCKR_PORT=
    DCKR_CFG=$(get_dckr_cfg $1)
    EC=$?
    if [ ${EC} -eq 0 ];then
        DCKR_HOST=$(echo ${DCKR_CFG}|awk -F\: '{print $1}')
        DCKR_PORT=$(echo ${DCKR_CFG}|awk -F\: '{print $2}')
        DCKR_CA=$(echo ${DCKR_CFG}|awk -F\: '{print $3}')
    elif [ ${EC} -eq 2 ];then
        return 2
    elif [ "X${1}" != "X" ];then
        DCKR_HOST=${1}
    else
        INACT=$(docker-machine ls|grep -v "NAME"|grep -v "*"|awk '{print $1}'|xargs)
        ACT=$(docker-machine ls|grep "*"|awk '{print $1}')
        echo -n "Which docker host? [_${ACT}_ / $(echo ${INACT}|sed -e 's# # / #g') ]?"
        read docker_host
    fi
    unset DOCKER_CERT_PATH
    unset DOCKER_TLS_VERIFY
    if [ "X${DCKR_HOST}" = "X" ];then
        DCKR_HOST=${ACT}
    elif [ "${DCKR_HOST}" = "localhost" ];then
	    export DOCKER_HOST=unix:///var/run/docker.sock
 	    return
    elif [ "X${DCKR_PORT}" != "X" ];then
        # we got a port, so we are good
        export DOCKER_HOST=tcp://${DCKR_HOST}:${DCKR_PORT}
        if [ "X${DCKR_CA}" != "X" ];then
            export DOCKER_TLS_VERIFY=1
            export DOCKER_CERT_PATH=${DCKR_CA} 
        fi
    else
        if [ "X${DCKR_HOST}" = "X" ];then
            DCKR_HOST=${ACT}
        #else 
        #    machine active ${DCKR_HOST}
        fi
        eval "$(docker-machine env ${DCKR_HOST})"
        if [ "$(docker-machine ls|grep ^${DCKR_HOST}|awk '{print $3}')" = "none" ];then
            unset DOCKER_CERT_PATH
            unset DOCKER_TLS_VERIFY
        fi
    fi
}
export DOCKER_HOST="tcp://${DHOST}:${DPORT}"
set_dhost $(get_default_dhost)
