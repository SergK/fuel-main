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

#
# This script creates slaves node for the product, launches its installation,
# and waits for its completion
# 1) By default, script creates number of slaves, defined in config.sh
# 2) This script can be used to create predefined number (1:default) of slave VM(s)
#
#
# Example: ./slave-nodes-create-and-boot.sh 4 ( will create new more 4 slave VMs)
#
#

# Include the handy functions to operate VMs
source config.sh
source functions/vm.sh

# Detect (from cmd-line parameter) the number of the slaves VMs that should be created
if [ -z $1 ]; then
  # By default we create one slave VM
  nVMcount=1
else
  # Take (from parameters) the number of VMs that should be created.
  if ! [[ $1 =~ ^[0-9]+$ ]] ; then
    echo >&2 "The Number of VMs should be integer"; exit 1;
  fi
  nVMcount=$1
fi

# Check if the master-node exists
if ! is_vm_present ${vm_name_prefix}master; then
  echo >&2 "Please, make sure that the master node is installed. If not, please run deploy first"; exit 1;
fi

# Detect the list of installed SLAVE FUEL(!) VMs, master should exist
vmlist=$(get_vms_present | sed 's/ /\n/g' | grep ${vm_name_prefix}slave)

# check if we alrady have slave VMs.
if [ -z "${vmlist}" ]; then
  # no Fuel slave VMs, so this is the first time installation
  first_idx=1
  # use predefined cluster size
  last_idx=${cluster_size}
else
  # We've already have some slave VMs
  # defining new slave node (VM) index = numof(slave)+1
  first_idx=$(($(echo ${vmlist} | wc -w )+1))
  last_idx=$((${first_idx}+${nVMcount}-1))

  echo "The following list of Fuel slaves VMs found:"
  echo ${vmlist} | sed 's/ /\n/g' 
fi

# Create and start slave nodes
for idx in $(eval echo {$first_idx..$last_idx}); do
  name="${vm_name_prefix}slave-${idx}"
  vm_ram=${vm_slave_memory_mb[$idx]}
  [ -z $vm_ram ] && vm_ram=$vm_slave_memory_default
  echo
  vm_cpu=${vm_slave_cpu[$idx]}
  [ -z $vm_cpu ] && vm_cpu=$vm_slave_cpu_default
  echo
  create_vm $name "${host_nic_name[0]}" $vm_cpu $vm_ram $vm_slave_first_disk_mb

  # Add additional NICs to VM
  if [ ${#host_nic_name[*]} -gt 1 ]; then
    for nic in $(eval echo {1..$((${#host_nic_name[*]}-1))}); do
      add_hostonly_adapter_to_vm $name $((nic+1)) "${host_nic_name[${nic}]}"
    done
  fi
  # Add additional disks to VM
  echo
  add_disk_to_vm $name 1 $vm_slave_second_disk_mb
  add_disk_to_vm $name 2 $vm_slave_third_disk_mb

  enable_network_boot_for_vm $name
  start_vm $name
done

# Report success
echo
echo "Slave nodes have been created. They will boot over PXE and get discovered by the master node."
echo "To access master node, please point your browser to:"
echo "    http://${vm_master_ip}:8000/"

