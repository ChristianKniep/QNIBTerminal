export DNS_DOMAIN=${DNS_DOMAIN-qnib}
export DNS_HOST=${DNS_HOST-dns}
export HOST_SHARE=${HOST_SHARE-/speed/}
export CPUS=${CPUS-4}
export DHOST=${DHOST-localhost}
if [ ! -f /proc/cpuinfo ];then
   CPUS=${CPUS-4}
fi

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
   for IMG in fd20 terminal helixdns elk slurm compute;do
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
     DNS=" ${DNS} --dns-search=${DNS_DOMAIN}"
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
   DNS="--dns=$(d_getip dns)"
   if [ "X$(eval_docker_version)" == "X10" ];then
     DNS=" ${DNS} --dns-search=${DNS_DOMAIN}"
   fi
   CONT_NAME="elk"
   IMG_NAME="elk"
   WWW_PORT=81
   ES_PORT=9200
   if [ ${CONT_DEV} -eq 1 ];then
      echo "Starting dev tag"
      CONT_NAME="elk-dev"
      IMG_NAME="elk:dev"
      WWW_PORT=10081
      ES_PORT=19200
   fi
   docker run ${RMODE} -h ${CONT_NAME} --name ${CONT_NAME} \
      ${DNS} \
      -v ${HOST_SHARE}/scratch:/scratch \
      -p ${WWW_PORT}:80 -p ${ES_PORT}:9200 \
      --lxc-conf="lxc.cgroup.cpuset.cpus=${CPUSET}" \
      qnib/${IMG_NAME} \
      ${RCMD}
}

function start_graphite {
   #starts graphite container and links with DNS
   DETACHED=${1-0}
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
   DNS="--dns=$(d_getip dns)"
   if [ "X$(eval_docker_version)" == "X10" ];then
     DNS=" ${DNS} --dns-search=${DNS_DOMAIN}"
   fi
   docker run ${RMODE} -h graphite --name graphite \
      ${DNS} \
      -v ${HOST_SHARE}/scratch:/scratch \
      -v ${HOST_SHARE}/whisper:/var/lib/carbon/whisper \
      --lxc-conf="lxc.cgroup.cpuset.cpus=${CPUSET}" \
      -p 80:80 \
      qnib/graphite \
      ${RCMD}
}

function start_slurm {
   #starts slurm container and links with DNS
   DETACHED=${1-0}
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
   DNS="--dns=$(d_getip dns)"
   if [ "X$(eval_docker_version)" == "X10" ];then
     DNS=" ${DNS} --dns-search=${DNS_DOMAIN}"
   fi
   docker run ${RMODE} -h slurm --name slurm \
      ${DNS} \
      -v ${HOST_SHARE}/scratch:/scratch \
      -v ${HOST_SHARE}/chome:/chome \
      --lxc-conf="lxc.cgroup.cpuset.cpus=${CPUSET}" \
      qnib/slurm \
      ${RCMD}
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
   DNS="--dns=$(d_getip dns)"
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
   DNS="--dns=$(d_getip dns)"
   if [ "X$(eval_docker_version)" == "X10" ];then
     DNS=" ${DNS} --dns-search=${DNS_DOMAIN}"
   fi
   docker run ${RMODE} -h ${CONT_NAME} --name ${CONT_NAME} \
      ${DNS} \
      -v ${HOST_SHARE}/scratch:/scratch \
      --lxc-conf="lxc.cgroup.cpuset.cpus=${CPUSET}" \
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
