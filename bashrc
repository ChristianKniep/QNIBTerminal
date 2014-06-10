export DNS_DOMAIN=${DNS_DOMAIN-qnib}
export DNS_HOST=${DNS_HOST-dns}
export HOST_SHARE=${HOST_SHARE-/speed/}
export CPUS=${CPUS-4}
export DHOST=${DHOST-localhost}
export MAX_MEMORY=${MAX_MEMORY-125M}
export NO_CGROUPS=${NO_CGROUPS-1}
export PROJECTS="fd20 supervisor terminal etcd helixdns elk graphite-web"
export PROJECTS="${PROJECTS} grafana graphite-api slurm compute slurmctld haproxy carbon"

export CONTAINERS="dns elk carbon graphite-web graphite-api grafana haproxy slurmctld"

if [ ! -f /proc/cpuinfo ];then
   CPUS=${CPUS-4}
fi

function start_qnibterminal {
   # starts the complete stack
   if [ "X${1}" != "X" ];then
      MY_CONT=$*
   else
      MY_CONT=${CONTAINERS}
   fi
   for cont in ${MY_CONT};do
      echo -n "#### Start ${cont}   "
      if [ ${cont} == "dns" ];then
         IMG_NAME="helixdns"
      else
         IMG_NAME=${cont}
      fi
      if [ $(docker ps|egrep -c " qnib/${IMG_NAME}\:") -ne 0 ];then
         echo "container already running..."
         continue
      fi
      CONT_ID=$(eval "start_$(echo ${cont}|sed -e 's/-/_/g')")
      EC=$?
      if [ $(docker ps|egrep -c " qnib/${IMG_NAME}\:") -ne 1 ];then
         echo "container was not started... :( EC: ${EC}"
         return 1
      fi
      echo "EC: $? ID: ${CONT_ID}"
      if [ ${EC} -ne 0 ];then
         return ${EC}
      fi
      if [ "X${QNIBT_DEBUG}" != "X" ];then
         echo "[press <enter> to continue]"
         read
      else
         sleep 5
      fi
   done
}
function dgit_check {
    GREP=${1-"docker-"}
    for x in $(ls|grep ${GREP});do pushd ${x};git status -s;popd;done
}

function dgit_clone {
   echo -n "Where to put the git-directories? [.] "
   read WORKDIR
   if [ "X${WORKDIR}" == "X" ];then
      WORKDIR="./"
   fi
   for proj in ${PROJECTS};do
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
      MY_PROJECTS=${PROJECTS}
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

function eval_cpuset {
   # returns cpuset.cpus for different types
   if [ ${DHOST} == "localhost" ];then
      if [ -f /proc/cpuinfo ];then
         CPUS=$(grep -c ^processor /proc/cpuinfo)
      fi
   fi
   CNT_CPU=${2-${CPUS}}
   if [ "X${1}" == "Xhelixdns" ];then
      echo 0
      return 0
   fi
   if [ "X${1}" == "Xelk" ];then
      if [ ${CNT_CPU} -ge 5 ];then
         echo 0,1
         return 0
      else
         echo 0
         return 0
      fi
   fi
   if [ "X${1}" == "Xslurm" ];then
      if [ ${CNT_CPU} -ge 5 ];then
         echo 0,1
         return 0
      else
         echo 0
         return 0
      fi
   fi
   if [ "X${1}" == "Xgraphite" ];then
      if [ ${CNT_CPU} -ge 5 ];then
         echo 2,3
         return 0
      else
         echo 1
         return 0
      fi
   fi
   if [[ "X${1}" == Xcompute* ]] ; then
      if [[ ${1} == compute[0-9] ]];then
         if [ ${CNT_CPU} -ge 5 ];then
            echo 4
            return 0
         else
            echo 2
            return 0
         fi
      fi
      if [[ ${1} == compute1[0-9] ]];then
         if [ ${CNT_CPU} -ge 5 ];then
            echo 5
            return 0
         else
            echo 3
            return 0
         fi
      fi
      if [[ ${1} == compute2[0-9] ]];then
         if [ ${CNT_CPU} -ge 6 ];then
            echo 6
            return 0
         fi
         if [ ${CNT_CPU} -ge 4 ];then
            echo 4
            return 0
         else
            echo "Not enough CPU corse"
            return 1
         fi
      fi
      COMP_NR=$(echo ${1}|sed -e 's/compute//')
      CPU_NR=$(echo "(${COMP_NR}/10) + 3"|bc)
      if [ ${CNT_CPU} -ge ${CPU_NR} ];then
         echo ${CPU_NR}
         return 0
      else
         echo "Not enough CPU corse 2.0 (CNT_CPU:${CNT_CPU} || desired CPU_NR:${CPU_NR})"
         return 1
      fi
   else
      echo 0
      return 0
   fi
}

function start_function {
   IMG_PREFIX=${IMG_PREFIX-qnib}
   IMG_NAME=${1}
   CON_NAME=${3-${IMG_NAME}}
   DETACHED=${2-0}
   OPTS="${OPTS}"
   if [ ${CON_NAME} == "carbon" ];then
      OPTS="${OPTS} -v ${HOST_SHARE}/whisper:/var/lib/carbon/whisper"
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
   if [ $? -ne 0 ];then
      return 1
   fi
   if [ "${CON_NAME}" != "dns" ];then
      DNS="--dns=$(d_getip ${DNS_HOST})"
   else
      DNS="--dns=127.0.0.1"
   fi
   DNS="${DNS} --dns-search=${DNS_DOMAIN}"
   OPTS="${OPTS} --privileged"
   if [ ${NO_CGROUPS} -ne 0 ];then
      OPTS="${OPTS} --lxc-conf=lxc.cgroup.cpuset.cpus=${CPUSET}"
   fi
   for MOUNT in ${MOUNTS};do
      OPTS="${OPTS} -v ${MOUNT}"
   done
   if [ ${DETACHED} -eq 0 ];then
      echo $(docker run -d -h ${CON_NAME} --name ${CON_NAME} \
         ${OPTS} \
         ${DNS} \
         -v ${HOST_SHARE}/scratch:/scratch \
         ${IMG_PREFIX}/${IMG_NAME}:latest)
      else
         docker run -t -i --rm -h ${CON_NAME} --name ${CON_NAME} \
            ${OPTS} \
            ${DNS} \
            -v ${HOST_SHARE}/scratch:/scratch \
            ${IMG_PREFIX}/${IMG_NAME}:latest \
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

function start_carbon {
   #starts the first container of QNIBTerminal
   CON_VOL=""
   CON_LINKED=""
   DETACHED=${1-0}
   FORWARD_PORTS=""
   OPTS="--privileged"
   MOUNTS="${HOST_SHARE}/whisper:/var/lib/carbon/whisper"
   start_function carbon ${DETACHED}
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

function start_graphite_api {
   CON_VOL=""
   CON_LINKED=""
   DETACHED=${1-0}
   FORWARD_PORTS=""
   MOUNTS="${HOST_SHARE}/whisper:/var/lib/carbon/whisper"
   OPTS=""
   start_function graphite-api ${DETACHED}
}

function start_graphite_web {
   CON_VOL="carbon"
   CON_LINKED="carbon"
   DETACHED=${1-0}
   FORWARD_PORTS=""
   MOUNTS="${HOST_SHARE}/whisper:/var/lib/carbon/whisper"
   OPTS=""
   start_function graphite-web ${DETACHED}
}

function start_slurmctld {
   CON_VOL=""
   CON_LINKED=""
   DETACHED=${1-0}
   FORWARD_PORTS=""
   MOUNTS="${HOST_SHARE}/chome:/chome"
   OPTS=""
   start_function slurmctld ${DETACHED}
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
      if [ $(docker ps|egrep -c "${CONT_NAME}\s+$") -eq 1 ];then
         echo "Container already started?!"
         return 1
      fi
   fi
   DETACHED=${2-0}
   OPTS="--memory=${MAX_MEMORY}"
   MOUNTS="${HOST_SHARE}/chome:/chome"
   FORWARD_PORTS=""
   start_function ${IMG_NAME} ${DETACHED} ${CON_NAME}
}

function start_container {
   #starts given image and links with DNS
   IMG_NAME=${1-X}
   if [ "X${IMG_NAME}" == "XX" ];then
      echo "No image name given"
      return 1
   fi
   LXC_CSET=${2-0}
   echo "Pin to CPU '${LXC_CSET}'..."
   LXC_OPTS=" --lxc-conf=lxc.cgroup.cpuset.cpus=${LXC_CSET}"
   RMODE="-t -i --rm=true"
   RCMD="/bin/bash"
   DNS="--dns=$(d_getip dns)"
   docker run ${RMODE} \
      -v ${HOST_SHARE}/scratch:/scratch \
      -v ${HOST_SHARE}/chome:/chome \
      ${LXC_OPTS} \
      ${IMG_NAME} \
      /bin/bash
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
