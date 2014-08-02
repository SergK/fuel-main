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

# This file contains the functions for connecting to Fuel VM and deploy clsuter

# Include the script with handy functions
source config.sh

## TODO: Should we check data in scripts or let Fuel do it for us?
## If smth will changed in command line, then using Fuel result is more rubust

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
  result=$(ssh $sshfuelopt ${user}@${host} "${cmd}")
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
  # Create Fuel env
  # fuel env create --name MyEnv --rel 1
  name=$1  #name of env
  rel=$2   #release number

  if [[ -z $1 || -z $2 ]]; then
    echo "Please be sure, that you defined parameters: \$1=name, \$2=release "
    echo "You can check releases (get_list_fuel_release) and envs (get_list_fuel_env)"
    # return error
    return 1
  else
    exec_on_fuel_master ${vm_master_username} ${vm_master_ip} "fuel env create --name ${name} --rel ${rel}"
    # return error code
    return $?
  fi
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
  else
    exec_on_fuel_master ${vm_master_username} ${vm_master_ip} "fuel --env ${env} env set --name \"${name}\" "
    # return error code
    return $?
  fi
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
  else
    exec_on_fuel_master ${vm_master_username} ${vm_master_ip} "fuel --env ${env} env set --mode \"${mode}\" "
    # return error code
    return $?
  fi
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
  else
    exec_on_fuel_master ${vm_master_username} ${vm_master_ip} "fuel --env ${env} env set --network-mode \"${nmode}\" "
    # return error code
    return $?
  fi
}


delete_fuel_env() {
  # Delete fuel env
  # fuel --env 1 env delete
  env=$1

  if [[ -z $1 || ! $1 =~ ^[0-9]+$ ]]; then
    echo "Please provide environment number (should be number). Please check it with (get_list_fuel_env)"
    # return error
    return 1
  else
    exec_on_fuel_master ${vm_master_username} ${vm_master_ip} "fuel --env $1 env delete"
    # return error code
    return $?
  fi
}


get_list_fuel_nodes() {
  # Get the list of nodes
  # fuel node list

  exec_on_fuel_master ${vm_master_username} ${vm_master_ip} "fuel node list"

  return $?
}
