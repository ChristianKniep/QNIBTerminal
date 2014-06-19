export QNIB_DNS_DOMAIN=${QNIB_DNS_DOMAIN-qnib}
export QNIB_DNS_HOST=${QNIB_DNS_HOST-dns}
export QNIB_HOST_SHARE=${QNIB_HOST_SHARE-/data/}
export QNIB_MAX_MEMORY=${QNIB_MAX_MEMORY-125M}
export QNIB_LAST_SERVICE_CPUID=${QNIB_LAST_SERVICE_CPUID-1}
export QNIB_PROJECTS="fd20 supervisor terminal etcd helixdns elk graphite-web"
export QNIB_PROJECTS="${QNIB_PROJECTS} grafana graphite-api slurm compute slurmctld haproxy carbon qnibng"

export QNIB_CONTAINERS="dns elk carbon graphite-web graphite-api grafana slurmctld compute0 haproxy"

function set_env {
   for item in $(env);do
      if [[ ${item} == QNIB_* ]];then
         key=$(echo ${item}| awk -F\= '{print $1}')
         if [ ${key} == "QNIB_PROJECTS" ];then
            continue
         fi
         if [ ${key} == "QNIB_CONTAINERS" ];then
            continue
         fi
         val=$(echo ${item}| sed -e "s/${key}\=//")
         echo -n "${key}? [${val}] "
         read new
         if [ "X${new}" != "X" ];then
            export ${key}="${new}"
         fi
      fi
   done
}

function ssh_compute0 {
   ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no  -l cluser -p 2222 $(d_getip haproxy)
}

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
   for x in ${QNIB_PROJECTS};do pushd docker-${x};git status -s;popd;done
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
   echo -n "Where arethe git-directories? [.] "
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
         echo "########## build> docker/${proj}"
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
      echo $(docker inspect -f '{{ .NetworkSettings.IPAddress }}' ${DCONT})
   fi
}

function d_getcpu {
   cpuid=$(docker inspect -f '{{ .HostConfig.LxcConf }}' ${1}|sed -e 's/\[map\[Key:lxc.cgroup.cpuset.cpus Value://'|sed -e 's/\]\]//')
   printf "%-20s %s\n" $1 ${cpuid}
}

function eval_cpuset {
   # returns cpuset.cpus for different types`
   if [ "X${1}" == "Xelk" ];then
      if [ ${QNIB_LAST_SERVICE_CPUID} -eq 2 ];then
         echo 0,1
         return 0
      fi
   fi
   if [[ "X${1}" == Xgraphite* ]];then
      if [ ${QNIB_LAST_SERVICE_CPUID} -eq 2 ];then
         echo 0,1
         return 0
      fi
   fi
   if [[ "X${1}" == Xcompute* ]] ; then
      comp_id=$(echo ${1} | sed 's/compute\([0-9]\+\)/\1/')
      echo "(${comp_id} / 16) + ${QNIB_LAST_SERVICE_CPUID}"|bc
      return 0
   fi
   echo 0
   return 0
}

function start_function {
   QNIB_IMG_PREFIX=${QNIB_IMG_PREFIX-qnib}
   IMG_NAME=${1}
   CON_NAME=${3-${IMG_NAME}}
   DETACHED=${2-0}
   OPTS="${OPTS}"
   if [ ${CON_NAME} == "carbon" ];then
      OPTS="${OPTS} -v ${QNIB_HOST_SHARE}/whisper:/var/lib/carbon/whisper"
   fi
   for port in ${FORWARD_PORTS};do
      OPTS="${OPTS} -p ${port}:${port}"
   done
   for link in ${CON_LINKED};do
      upper=$(echo ${link}|awk '{print toupper($0)}')
      OPTS="${OPTS} --link ${link}:${upper}"
   done
   for vol in ${CON_VOL};do
      OPTS="${OPTS} --volumes-from ${vol}"
   done
   CPUSET=$(eval_cpuset ${CON_NAME})
   #echo "eval_cpuset ${CON_NAME} = ${CPUSET}"
   if [ $? -ne 0 ];then
      return 1
   fi
   if [ "${CON_NAME}" != "dns" ];then
      DNS="--dns=$(d_getip ${QNIB_DNS_HOST})"
   else
      DNS="--dns=127.0.0.1"
   fi
   DNS="${DNS} --dns-search=${QNIB_DNS_DOMAIN}"
   OPTS="${OPTS} --privileged"
   OPTS="${OPTS} --lxc-conf=lxc.cgroup.cpuset.cpus=${CPUSET}"
   for MOUNT in ${MOUNTS};do
      OPTS="${OPTS} -v ${MOUNT}"
   done
   if [ ${DETACHED} -eq 0 ];then
      echo $(docker run -d -h ${CON_NAME} --name ${CON_NAME} \
         ${OPTS} \
         ${DNS} \
         -v /dev/null:/dev/null -v /dev/urandom:/dev/urandom \
         -v /dev/random:/dev/random -v /dev/full:/dev/full \
         -v /dev/zero:/dev/zero \
         -v ${QNIB_HOST_SHARE}/scratch:/scratch \
         ${QNIB_IMG_PREFIX}/${IMG_NAME}:latest)
      else
         docker run -t -i --rm -h ${CON_NAME} --name ${CON_NAME} \
            ${OPTS} \
            ${DNS} \
            -v /dev/null:/dev/null -v /dev/urandom:/dev/urandom \
            -v /dev/random:/dev/random -v /dev/full:/dev/full \
            -v /dev/zero:/dev/zero \
            -v ${QNIB_HOST_SHARE}/scratch:/scratch \
            ${QNIB_IMG_PREFIX}/${IMG_NAME}:latest \
            /bin/bash
      fi
}

function start_dns {
   #starts the first container of QNIBTerminal
   CON_VOL=""
   CON_LINKED=""
   DETACHED=${1-0}
   FORWARD_PORTS=""
   OPTS=""
   MOUNTS=""
   start_function helixdns ${DETACHED} dns

}
function start_elk {
   #starts the first container of QNIBTerminal
   CON_VOL=""
   CON_LINKED=""
   DETACHED=${1-0}
   FORWARD_PORTS=""
   OPTS="--privileged"
   MOUNTS=""
   start_function elk ${DETACHED}
}

function start_qnibng {
   CON_VOL=""
   CON_LINKED=""
   DETACHED=${1-0}
   FORWARD_PORTS=""
   OPTS="--privileged -v /dev/infiniband/:/dev/infiniband/"
   MOUNTS="${QNIB_HOST_SHARE}/whisper:/var/lib/carbon/whisper"
   start_function qnibng ${DETACHED}
}

function start_carbon {
   #starts the first container of QNIBTerminal
   CON_VOL=""
   CON_LINKED=""
   DETACHED=${1-0}
   FORWARD_PORTS=""
   OPTS="--privileged"
   MOUNTS="${QNIB_HOST_SHARE}/whisper:/var/lib/carbon/whisper"
   start_function carbon ${DETACHED}
}

function start_haproxy {
   CON_VOL=""
   CON_LINKED=""
   DETACHED=${1-0}
   FORWARD_PORTS="80 9200 2222"
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

function start_graphite_api {
   CON_VOL=""
   CON_LINKED=""
   DETACHED=${1-0}
   FORWARD_PORTS=""
   MOUNTS="${QNIB_HOST_SHARE}/whisper:/var/lib/carbon/whisper"
   OPTS=""
   start_function graphite-api ${DETACHED}
}

function start_graphite_web {
   CON_VOL=""
   CON_LINKED=""
   DETACHED=${1-0}
   FORWARD_PORTS=""
   MOUNTS="${QNIB_HOST_SHARE}/whisper:/var/lib/carbon/whisper"
   OPTS=""
   start_function graphite-web ${DETACHED}
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

function start_compute0 {
   start_comp compute0
}

function start_computes {
   for comp in $*;do echo -n "${comp}   "; start_comp ${comp};sleep 1;done
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
   FORWARD_PORTS=""
   start_function ${IMG_NAME} ${DETACHED} ${CON_NAME}
}

function start_container {
   #starts given image and links with DNS
   CON_VOL=""
   CON_LINKED=""
   DETACHED=${1-0}
   FORWARD_PORTS=""
   MOUNTS=""
   OPTS="-p 82:80"
   start_function ${1} 1
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
