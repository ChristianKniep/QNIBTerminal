export DNS_DOMAIN=${DNS_DOMAIN-qnib}
export DNS_HOST=${DNS_HOST-dns}
export HOST_SHARE=${HOST_SHARE-/speed/}
export CPUS=${CPUS-4}
export DHOST=${DHOST-localhost}
export MAX_MEMORY=${MAX_MEMORY-125M}
export NO_CGROUPS=${NO_CGROUPS-1}
export PROJECTS="fd20 supervisor terminal etcd helixdns elk graphite-web"
export PROJECTS="${PROJECTS} grafana graphite-api slurm compute slurmctld haproxy carbon"


if [ ! -f /proc/cpuinfo ];then
   CPUS=${CPUS-4}
fi

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

function d_pullall {
   echo "#########  Starting download of QNIBTerminal images"
   echo "###### $(date)"
   for IMG in ${PROJECTS};do
      echo "### pulling qnib/${IMG}"
      docker pull qnib/${IMG}
   done
   echo "###### $(date)"
   echo "######### END"
}

function eval_docker_version {
   #checks client/server version
   DVER=$(docker version |egrep "(Client|Server) version:"|awk -F\: '{print $2}'|uniq|sed -e 's/ //g')
   if [[ "X${DVER}" == X0\.9\.* ]];then
      echo 9
      return 0
   fi
   if [[ "X${DVER}" == X0.10.* ]];then
      echo 10
      return 0
   fi
   if [[ "X${DVER}" == X0.11.* ]];then
      echo 11
      return 0
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
   if [ "X${1}" == "Xdns" ];then
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
   fi
}

function start_dns {
   #starts the first container of QNIBTerminal
   DETACHED=${1-0}
   if [ ${DETACHED} -eq 0 ];then
      RMODE="-d"
      RCMD=""
   else
      RMODE="-t -i --rm=true"
      RCMD="/bin/bash"
   fi
   CPUSET=$(eval_cpuset dns)
   if [ $? -ne 0 ];then
      return 1
   fi
   DNS="--dns=127.0.0.1"
   if [ "X$(eval_docker_version)" == "X10" ];then
     DNS="${DNS} --dns-search=${DNS_DOMAIN}"
   fi
   docker run ${RMODE} -h ${DNS_HOST} --name ${DNS_HOST} \
      ${DNS} \
      -v ${HOST_SHARE}/scratch:/scratch \
      --lxc-conf="lxc.cgroup.cpuset.cpus=${CPUSET}" \
      qnib/helixdns \
      ${RCMD}
}

function start_elk {
   #starts ELK container and links with DNS
   CONT_DEV=${CONT_DEV-0}
   DETACHED=${1-0}
   CONT_NAME="elk"
   IMG_NAME="elk"
   if [ ${DETACHED} -eq 0 ];then
      RMODE="-d"
      RCMD=""
   else
      RMODE="-t -i --rm=true"
      RCMD="/bin/bash"
   fi
   CPUSET=$(eval_cpuset elk)
   if [ $? -ne 0 ];then
      return 1
   fi
   DNS="--dns=$(d_getip ${DNS_HOST})"
   if [ "X$(eval_docker_version)" == "X10" ];then
     DNS=" ${DNS} --dns-search=${DNS_DOMAIN}"
   fi
   if [ ${CONT_DEV} -eq 1 ];then
      echo "Starting dev tag"
      CONT_NAME="elk-dev"
      IMG_NAME="elk:dev"
   fi
   docker run ${RMODE} -h ${CONT_NAME} --name ${CONT_NAME} \
      --privileged \
      ${DNS} \
      -v ${HOST_SHARE}/scratch:/scratch \
      --lxc-conf="lxc.cgroup.cpuset.cpus=${CPUSET}" \
      qnib/${IMG_NAME} \
      ${RCMD}
}

function start_carbon {
   DETACHED=${1-0}
   if [ ${DETACHED} -eq 0 ];then
      RMODE="-d"
      RCMD=""
   else
      RMODE="-t -i --rm=true"
      RCMD="/bin/bash"
   fi
   CPUSET=$(eval_cpuset carbon)
   if [ $? -ne 0 ];then
      return 1
   fi
   DNS="--dns=$(d_getip ${DNS_HOST})"
   if [ "X$(eval_docker_version)" == "X10" ];then
     DNS=" ${DNS} --dns-search=${DNS_DOMAIN}"
   fi
   OPTS="--privileged"
   if [ ${NO_CGROUPS} -ne 0 ];then
      OPTS="${OPTS} --lxc-conf=\"lxc.cgroup.cpuset.cpus=${CPUSET}\""
   fi
   docker run ${RMODE} -h carbon --name carbon \
      ${OPTS} \
      ${DNS} \
      -v ${HOST_SHARE}/scratch:/scratch \
      -v ${HOST_SHARE}/whisper:/var/lib/carbon/whisper \
      qnib/carbon \
      ${RCMD}
}

function start_function {
   IMG_PREFIX=${IMG_PREFIX-qnib}
   IMG_NAME=${1}
   CON_NAME=${3-${IMG_NAME}}
   DETACHED=${2-0}
   OPTS=""
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
   if [ ${DETACHED} -eq 0 ];then
      RMODE="-d"
      RCMD=""
   else
      RMODE="-t -i --rm=true"
      RCMD="/bin/bash"
   fi
   CPUSET=$(eval_cpuset ${CON_NAME})
   if [ $? -ne 0 ];then
      return 1
   fi
   DNS="--dns=$(d_getip ${DNS_HOST})"
   DNS="${DNS} --dns-search=${DNS_DOMAIN}"
   OPTS="${OPTS} --privileged"
   if [ ${NO_CGROUPS} -ne 0 ];then
      OPTS="${OPTS} --lxc-conf=\"lxc.cgroup.cpuset.cpus=${CPUSET}\""
   fi
   for MOUNT in ${MOUNTS};do
      OPTS="${OPTS} -v ${MOUNT}"
   done
   docker run ${RMODE} -h ${CON_NAME} --name ${CON_NAME} \
      ${OPTS} \
      ${DNS} \
      -v ${HOST_SHARE}/scratch:/scratch \
      ${IMG_PREFIX}/${IMG_NAME} \
      ${RCMD}
}

function start_haproxy {
   DETACHED=${1-0}
   FORWARD_PORTS="80 9200"
   start_function haproxy ${DETACHED}
}

function start_grafana {
   DETACHED=${1-0}
   FORWARD_PORTS=""
   start_function grafana ${DETACHED}
}

function start_graphite_api {
   DETACHED=${1-0}
   #CON_VOL="carbon"
   CON_LINKED="carbon"
   FORWARD_PORTS=""
   MOUNTS="${HOST_SHARE}/whisper:/var/lib/carbon/whisper"
   start_function graphite-api ${DETACHED}
}

function start_graphite_web {
   DETACHED=${1-0}
   CON_VOL="carbon"
   CON_LINKED="carbon"
   FORWARD_PORTS=""
   MOUNTS="${HOST_SHARE}/whisper:/var/lib/carbon/whisper"
   start_function graphite-web ${DETACHED}
}

function start_slurmctld {
   DETACHED=${1-0}
   MOUNTS="${HOST_SHARE}/chome:/chome"
   FORWARD_PORTS=""
   start_function slurmctld ${DETACHED}
}

function start_comp {
   #starts slurm container and links with DNS
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

function start_terminal {
   #starts terminal container and links with DNS
   LXC_CSET=${1-X}
   LXC_OPTS=""
   if [ "X${LXC_CSET}" != "XX" ];then
      LXC_OPTS="${LXC_OPTS} --lxc-conf=lxc.cgroup.cpuset.cpus=${LXC_CSET}"
   fi
   LXC_CSHARE=${2-X}
   if [ "X${LXC_CSHARE}" != "XX" ];then
      LXC_OPTS="${LXC_OPTS} --lxc-conf=lxc.cgroup.cpu.shares=${LXC_CSHARE}"
   fi
   RMODE="-t -i --rm=true"
   RCMD="/bin/bash"
   DNS="--dns=$(d_getip ${DNS_HOST})"
   if [ "X$(eval_docker_version)" == "X10" ];then
     DNS=" ${DNS} --dns-search=${DNS_DOMAIN}"
   fi
   docker run ${RMODE} \
      ${DNS} \
      -v ${HOST_SHARE}/scratch:/scratch \
      -v ${HOST_SHARE}/chome:/chome \
      ${LXC_OPTS} \
      qnib/terminal:latest \
      /bin/bash
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
   if [ "X$(eval_docker_version)" == "X10" ];then
     DNS=" ${DNS} --dns-search=${DNS_DOMAIN}"
   fi
   docker run ${RMODE} \
      -v ${HOST_SHARE}/scratch:/scratch \
      -v ${HOST_SHARE}/chome:/chome \
      ${LXC_OPTS} \
      ${IMG_NAME} \
      /bin/bash
}

function start_compute {
   #starts slurm container and links with DNS
   CONT_NAME=${1}
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
   if [ ${DETACHED} -eq 0 ];then
      RMODE="-d"
      RCMD=""
   else
      RMODE="-t -i --rm=true"
      RCMD="/bin/bash"
   fi
   CPUSET=$(eval_cpuset ${CONT_NAME})
   if [ $? -ne 0 ];then
      return 1
   fi
   CPU_SET=${3-${CPUSET}}
   DNS="--dns=$(d_getip ${DNS_HOST})"
   if [ "X$(eval_docker_version)" == "X10" ];then
     DNS=" ${DNS} --dns-search=${DNS_DOMAIN}"
   fi
   docker run ${RMODE} -h ${CONT_NAME} --name ${CONT_NAME} \
      ${DNS} \
      -v ${HOST_SHARE}/scratch:/scratch \
      --lxc-conf="lxc.cgroup.cpuset.cpus=${CPU_SET}" \
      --memory=${MAX_MEMORY} \
      qnib/compute \
      ${RCMD}
}

function restart_compute {
   #restarts compute container
   CONT_NAME=${1}
   if [[ "X${1}" != Xcompute* ]] ; then
      echo "1st argument must be 'compute\d+'"
      return 1
   else
      if [ $(docker ps|egrep -c "${CONT_NAME}\s+$") -eq 0 ];then
         echo "Container not running...?"
         return 1
      fi
   fi
   docker stop ${CONT_NAME}
   EC=$?
   if [ ${EC} -ne 0 ];then
      echo "Stop failed... "
      return 1
   fi
   sleep 1
   docker start ${CONT_NAME}
   EC=$?
   if [ ${EC} -ne 0 ];then
      echo "Start failed... "
      return 1
   fi
}

function d_garbage_collect {
   #removes exited container
   NOT=${1-0}
   if [ "X${NOT}" == "X0" ];then
      docker rm $(docker ps -a|grep Exit|awk '{print $1}'|xargs)
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
