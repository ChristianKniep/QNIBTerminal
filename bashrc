export HOST_SHARE=${HOST_SHARE-/opt/}
export CPUS=4
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

function eval_cpuset {
   # returns cpuset.cpus for different types
   if [ -f /proc/cpuinfo ];then
      CPUS=$(grep -c ^processor /proc/cpuinfo)
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
   docker run ${RMODE} -h dns --name dns \
      --dns=127.0.0.1 \
      -v ${HOST_SHARE}/scratch:/scratch \
      --lxc-conf="lxc.cgroup.cpuset.cpus=${CPUSET}" \
      qnib/helixdns \
      ${RCMD}
}

function start_elk {
   #starts ELK container and links with DNS
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
   docker run ${RMODE} -h elk --name elk \
      --dns=$(d_getip dns) \
      -v ${HOST_SHARE}/scratch:/scratch \
      -p 81:80 -p 9200:9200 \
      --lxc-conf="lxc.cgroup.cpuset.cpus=${CPUSET}" \
      qnib/elk \
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
   docker run ${RMODE} -h graphite --name graphite \
      --dns=$(d_getip dns) \
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
   docker run ${RMODE} -h slurm --name slurm \
      --dns=$(d_getip dns) \
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
   RMODE="-t -i --rm=true"
   RCMD="/bin/bash"
   #--dns=$(d_getip dns) \
   docker run ${RMODE} \
      -v ${HOST_SHARE}/scratch:/scratch \
      -v ${HOST_SHARE}/chome:/chome \
      -v ${HOST_SHARE}/etc:/usr/local/etc \
      ${LXC_OPTS} \
      qnib/terminal \
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
   docker run ${RMODE} -h ${CONT_NAME} --name ${CONT_NAME} \
      --dns=$(d_getip dns) \
      -v ${HOST_SHARE}/scratch:/scratch \
      -v ${HOST_SHARE}/chome:/chome \
      -v ${HOST_SHARE}/etc:/usr/local/etc \
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
