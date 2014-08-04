#!/bin/bash 

#    Copyright 2013 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

# This file contains the functions for working with Fuel CLI over ssh

# Include the script with handy functions
source config.sh
# source functions/common.sh 

## TODO: Should we check data in scripts or let Fuel do it for us?
## - If smth will changed in command line of Fuel, then using Fuel result is more rubust
## - Positional parameters, try to remove this dependency, then we should use param_name=param_vale

# we need auth by public key
sshfuelopt='-oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null -oRSAAuthentication=no -q'


exec_on_fuel_master() {
  # Execute command on fuel-master
  
  # we need to get error code in order to pass it to top functions
  code=0

  # function parameters
  user=$1
  host=$2
  cmd=$3

  # we will error too, if we need to hide them, then use  2>&1 and provide logic to process exeptions
  result=$(ssh -i ${KEY} $sshfuelopt ${user}@${host} "${cmd}")
  code=$?
    
  # When you are launching command in a sub-shell, there are issues with IFS (internal field separator)
  # and parsing output as a set of strings. So, we are saving original IFS, replacing it, iterating over lines,
  # and changing it back to normal
  #
  # http://blog.edwards-research.com/2010/01/quick-bash-trick-looping-through-output-lines/

  OIFS="${IFS}"
  NIFS=$'\n'
   
  IFS="${NIFS}"
   
  for LINE in ${result} ; do
    IFS="${OIFS}"
    echo "${LINE}"
    IFS="${NIFS}"
  done
  IFS="${OIFS}"
  
  return ${code}
}


get_list_fuel_release() {
  # Get list of all avaliable releases
  # fuel release

  exec_on_fuel_master ${vm_master_username} ${vm_master_ip} "fuel release"

  return $?
}


get_list_fuel_env() {
  # Get the list of created env
  # fuel env

  exec_on_fuel_master ${vm_master_username} ${vm_master_ip} "fuel env"

  return $?
}


create_fuel_env() {
  # Create default Fuel env
  # fuel env create --name MyEnv --rel 1
  name=$1  #name of env
  rel=$2   #release number
  mode=${3:-multinode}

  if [[ -z $1 || -z $2 || ! $2 =~ ^[0-9]+$ ]]; then
    echo "Please be sure, that you defined parameters: \$1=name, \$2=release (Number)"
    echo "You can check releases (get_list_fuel_release) and envs (get_list_fuel_env)"
    # return error
    return 1
  fi
  exec_on_fuel_master ${vm_master_username} ${vm_master_ip} "fuel env create --name ${name} --rel ${rel} --mode=${mode}"
  # return error code
  return $?
}


change_fuel_env_name() {
  # Change Env name
  # fuel --env 1 env set --name NewEmvName
  env=$1  #name of env
  name=$2 #New name

  if [[ -z $1 || -z $2 || ! $1 =~ ^[0-9]+$ ]]; then
    echo "Please be sure, that you defined parameters: \$1=environment (Number), \$2=new name"
    # return error
    return 1
  fi
  exec_on_fuel_master ${vm_master_username} ${vm_master_ip} "fuel --env ${env} env set --name \"${name}\" "
  # return error code
  return $?
}


change_fuel_env_mode() {
  # Change Env mode
  # fuel --env 1 env set --mode ha_compact
  env=$1  #name of env
  mode=$2 #New mode

  if [[ -z $1 || -z $2 || ! $1 =~ ^[0-9]+$ ]]; then
    echo "Please be sure, that you defined parameters: \$1=environment (Number), \$2=mode"
    # return error
    return 1
  fi
  exec_on_fuel_master ${vm_master_username} ${vm_master_ip} "fuel --env ${env} env set --mode \"${mode}\" "
  # return error code
  return $?
}


change_fuel_env_net() {
  # Change Env mode
  # fuel --env 1 env set --network-mode nova
  env=$1  #name of env
  nmode=$2 #New mode

  if [[ -z $1 || -z $2 || ! $1 =~ ^[0-9]+$ ]]; then
    echo "Please be sure, that you defined parameters: \$1=environment (Number), \$2=network-mode"
    # return error
    return 1
  fi
  exec_on_fuel_master ${vm_master_username} ${vm_master_ip} "fuel --env ${env} env set --network-mode \"${nmode}\" "
  # return error code
  return $?
}


delete_fuel_env() {
  # Delete fuel env
  # fuel --env 1 env delete
  env=$1

  if [[ -z $1 || ! $1 =~ ^[0-9]+$ ]]; then
    echo "Please provide environment number (should be number). Please check it with (get_list_fuel_env)"
    # return error
    return 1
  fi
  exec_on_fuel_master ${vm_master_username} ${vm_master_ip} "fuel --env $1 env delete"
  # return error code
  return $?
}

########### Working  with nodes

get_list_fuel_node() {
  # Get the list of all nodes (default) or for exact environment
  # fuel node list (deafault)
  # fuel --env-id 1 node list
  env=$1

  if [[ -z $1 ]]; then
    # print all nodes by default
    exec_on_fuel_master ${vm_master_username} ${vm_master_ip} "fuel node list"
    return $?
  fi

  if [[ $1 =~ ^[0-9]+$ ]]; then
    # get nodes for exact env
    # parameter is the number, let's try to get the information
    exec_on_fuel_master ${vm_master_username} ${vm_master_ip} "fuel --env-id ${env} node list"
    return $?
  else
    echo "Environment number should be integer. Please check which one with (get_list_fuel_env)"
    return 1
  fi
}


assign_role_to_node() {
  # Assign nodes to environment with specific roles
  # fuel node set --node 1 --role controller --env 1
  # fuel node set --node 2,3,4 --role compute,cinder --env 1
  node_list=$1
  role_list=$2
  env=$3

  if [ $# -ne 3 ];then
    echo "Please provide following list of parameters: "
    echo "node_list role_list env"
    return 1
  fi

  exec_on_fuel_master ${vm_master_username} ${vm_master_ip} "fuel node set --node ${node_list} --role ${role_list} --env ${env}"
  return $?
}


remove_node_from_env() {
  # Remove nodes from environment. Nodes can be removed by two approaches (by node, by env):
  # parameters: node=2,3,4  or env=1
  # fuel node remove --node 2,3
  # fuel node remove --env 1

  # define which parameter user passed
  param=$(echo $1 | cut -d'=' -f1)
  # and it's value
  value=$(echo $1 | cut -d'=' -f2)

  case "${param}" in
    node*)
      exec_on_fuel_master ${vm_master_username} ${vm_master_ip} "fuel node remove --node ${value}"
      return $?
      ;;
    env*)
      exec_on_fuel_master ${vm_master_username} ${vm_master_ip} "fuel node remove --env ${value} --all"
      return $?
      ;;
    *)
      echo "Please, pass the only ONE parameter to this function in format:"
      echo "node=x1,x2,x2 - for removing nodes x1,x2,x3 from environment(s)"
      echo "or"
      echo "env=x         - for removing all nodes from environment x"
      ;;
  esac
  return 1
}


##### Deployment section

provision_node(){
  # provision only some nodes (status changes to provisioning)
  # fuel node --node 1,2 --provision --env 1
  env=$1
  node=$2

  if [[ -z $1 || -z $2 || ! $1 =~ ^[0-9]+$ ]]; then
    echo "Please provide environment number (should be integer) and node(s) number. Please check it with (get_list_fuel_env)"
    echo "Usage: provision_node environment node(s)"
    # return error
    return 1
  fi
  exec_on_fuel_master ${vm_master_username} ${vm_master_ip} "fuel node --node ${node} --provision --env ${env}"
  # return error code
  return $?
}

##### Different staff
## TODO for staff: we need to make selection not on position of column, but by name

get_nodes_ready_for_deployment() {
  # Get the list of nodes, ready for deployment (nodes can be in offline mode)
  # currently we are not checking node facters
  # get id, status, cluster - which is enough to define node's "exact" status
  # TODO: check, may be don't need status and (id, cluster) is enough
  
  echo $(get_list_fuel_node | cut -d'|' -f1,2,4 | grep "discover"  | grep "None" | grep -o -E '^[0-9]+')
  return 0
}


get_env_id_by_name() {
  # Return environment id by name
  # the result of the function you can check using $?
  env_name=$1

  if [[ -z $1 ]];then
    echo "Please, provide environment name"
    exit 1
  fi

  ENV_ID=$(get_list_fuel_env | cut -d'|' -f1,3 | tail -n+3 | grep ${env_name} | cut -d'|' -f1)

  if [[ -z ${ENV_ID} ]]; then
    # Nothing found
    echo "Environment with name ${env_name} doesn't exist"
    return 1
  else
    echo ${ENV_ID}
    return 0
  fi
}


get_env_mode_by_name() {
  # Return environment id by name
  # the result of the function you can check using $?
  env_name=$1

  if [[ -z $1 ]];then
    echo "Please, provide environment name"
    exit 1
  fi
  # we also need to replace ha_compact to ha
  ENV_MODE=$(get_list_fuel_env | cut -d'|' -f3,4 | tail -n+3 | grep ${env_name} | cut -d'|' -f2 | sed 's/ha_compact/ha/g')

  if [[ -z ${ENV_MODE} ]]; then
    # Nothing found
    echo "Environment with name ${env_name} doesn't exist"
    return 1
  else
    echo ${ENV_MODE}
    return 0
  fi
}


check_deployment_roles() {
  # We need to check roles, that user want to deploy in defined environment
  # TODO: There are a lot of limitations, need to investigate more in future
  # espesially for HA mode

  # string for nodes role should be defined in format:
  # - role1,role2|role1,role3|role2|role3 , where nodes roles separated by "|"
  # - no space allowed and they will be removed automatically
  # - 

  deployment_mode=$1
  list_of_roles=$2

  if [ $# -ne 2 ];then
    echo "Please provide following list of parameters: "
    echo "1) deployment_mode: ('multinode', 'ha')"
    echo "2) list_of_roles: for ex.: \"compute,cinder|compute|zabbix-server|controller\" "
    return 1
  fi

# check mode 'multinode', 'ha'
if ! [[ "${deployment_mode}" =~ ^(multinode|ha)$ ]]; then
    echo "Incorrect deployment mode. Please use ('multinode' or 'ha')"
    exit 1
fi

# remove spaces in list of roles
list_of_roles=$(echo $2 | sed 's/\s\+//g')

# count the number of nodes, that user want to use in this deployment(count "|" + 1)
N_NODES_TO_DEPLOY=$(($(grep -o "|" <<< "${list_of_roles}" | wc -l )+1))

# one node is not allowed we need at least one controller and one compute
if [ ${N_NODES_TO_DEPLOY} -lt 2 ];then
  echo "You should have at least TWO nodes with roles: compute and controller"
  exit 1
fi

# get list of nodes ready for deployment
DISCOVERED_NODES=$(get_nodes_ready_for_deployment)
N_DISCOVERED_NODES=$(echo ${DISCOVERED_NODES} | wc -w)

# in case we have not enough free slave nodes - aborting
if [ ${N_DISCOVERED_NODES} -lt ${N_NODES_TO_DEPLOY} ]; then
  echo "Not enough free slave nodes for deployment (for this scenario)"
  echo "NEED: ${N_NODES_TO_DEPLOY}, HAVE: ${N_DISCOVERED_NODES}"
  exit 1
fi

# Let's check roles names for correctness
# get the list in forms "role role role" - replacing , and | by space
SANITY_ROLES=$(echo ${list_of_roles} | sed 's/,/ /g;s/|/ /g')
for r in ${SANITY_ROLES}; do
  if ! [[ "${r}" =~ ^(controller|compute|cinder|zabbix-server|ceph-osd)$ ]]; then
      echo "Incorrect ROLE: ${r}"
      echo "Please use: (controller|compute|cinder|zabbix-server|ceph-osd)"
      exit 1
  fi
done

# Let's check roles, also for different deployment modes
# number of controllers
N_CONTROLLERS=$(grep -o "controller" <<< "${list_of_roles}" | wc -l )
N_ZABBIX=$(grep -o "zabbix-server" <<< "${list_of_roles}" | wc -l )
N_COMPUTE=$(grep -o "compute" <<< "${list_of_roles}" | wc -l )

case "${deployment_mode}" in
  multinode)
    if [ ${N_CONTROLLERS} -ne 1 ]; then
      echo "One CONTROLLER should be in Multimode cluster mode"
    exit 1
    fi
    # check zabbix-server
    if [ ${N_ZABBIX} -gt 1 ]; then
      echo "None or ONE ZABBIX should be in Multimode cluster mode"
    exit 1
    fi
    # check compute
    if [ ${N_COMPUTE} -lt 1 ]; then
      echo "At least ONE COMPUTE should be in Multimode cluster mode"
    exit 1
    fi
  ;;
  ha)
    if [ ${N_CONTROLLERS} -lt 1 ]; then
      echo "At least ONE controller should be in HA cluster mode"
    exit 1
    fi    
  ;;
esac

# no controller and compute on the same node
OIFS="${IFS}"
NIFS=$'|'
IFS="${NIFS}"

for role in ${list_of_roles}; do
  IFS="${OIFS}"
  # compute and controller on the same node?
  if [[ ${role} == $(echo ${role} | awk '/compute/ && /controller/') ]]; then
    echo "Cannot assign compute and controller role to the same node"
    exit 1
  fi
  # compute and zabbix-server on the same node?
  if [[ ${role} == $(echo ${role} | awk '/compute/ && /zabbix-server/') ]]; then
    echo "Cannot assign compute and zabbix-server role to the same node"
    exit 1
  fi
  # zabbix-server and controller on the same node?
  if [[ ${role} == $(echo ${role} | awk '/controller/ && /zabbix-server/') ]]; then
    echo "Cannot assign controller and zabbix-server role to the same node"
    exit 1
  fi
  IFS="${NIFS}"
done

IFS="${OIFS}"

}


deploy_node() {
  # deploy node after provisioning
  # fuel node --deploy --node 1,2 --env 1
  # TODO: node should be in online
  echo "Not implemented"
}


deploy_env() {
  # deploy environment changes (provision+deploy)
  # fuel --env 1 deploy-changes
  env=$1

  if [[ -z $1 || ! $1 =~ ^[0-9]+$ ]]; then
    echo "Please provide environment number (should be integer). Please check it with (get_list_fuel_env)"
    # return error
    return 1
  fi
  exec_on_fuel_master ${vm_master_username} ${vm_master_ip} "fuel --env ${env} deploy-changes"
  # return error code
  return $?
}


deploy_openstack() {
  # Deploy OpenStack
  # we need Environment Name and list of nodes_roles
  ENV_NAME=$1
  ROLES=$2
  E_MODE=${3:-multinode}
  E_REL=${4:-1}

  if [ $# -lt 2 ];then
    echo "Usage: deploy_openstack NAME ROLES [MODE] [RELEASE]"
    echo -e "\t NAME - Name of the environment"
    echo -e "\t ROLES - The list of roles in environment: ex.\"compute,cinder|compute|zabbix-server|controller\""
    echo -e "\t MODE - (ha|multinode) default: multinode"
    echo -e "\t RELEASE - (1|2), where 1-CENTOS (default), 2-UBUNTU"
    return 1
  fi

  echo -e "Deploying: \tNAME=${ENV_NAME}"
  echo -e "\t\tROLES=${ROLES}"
  echo -e "\t\tMODE=${E_MODE}"
  echo -e "\t\tRELEASE=${E_REL}"

  # try to create new env
  if ( ! create_fuel_env "${ENV_NAME}" "${E_REL}" "${E_MODE}");then
    echo "Fail. Please see the error above"
    exit 1
  fi

  # Check if it was created and get its mode and id
  ENV_ID=$(get_env_id_by_name "${ENV_NAME}") || { echo ${ENV_ID}; exit 1; }
  ENV_MODE=$(get_env_mode_by_name "${ENV_NAME}") || { echo ${ENV_MODE}; exit 1; }
  
  # Let's check if provided roles are compatible with env mode
  echo -n "Checking environment..."
  check_deployment_roles "${ENV_MODE}" "${ROLES}"
  echo "[Ok]"

  # Everything is ok, let's assign roles to nodes
  echo
  echo "Assigning roles to nodes"
  FREE_DISCOVERED_NODES=$(get_nodes_ready_for_deployment)
  FIELD=1

  for node in ${FREE_DISCOVERED_NODES}; do
    role=$(echo ${ROLES} | cut -d'|' -f${FIELD} )
      assign_role_to_node "${node}" "${role}" "${ENV_ID}"
    (( FIELD++ ))
  done
  
  # Deploying, we can check if the slaves are online, but we also use error from fuel
  echo 
  echo "Deploying... please wait"
  echo 
  deploy_env "${ENV_ID}"
}
