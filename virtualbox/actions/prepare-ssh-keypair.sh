#!/bin/bash 

#set -x

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

# This script works with ssh keys

# Include the script with handy functions to operate VMs and VirtualBox networking
source config.sh
source functions/product.sh

## TODO: Implement some part in functions

# Check if the directory for keypair exists and try to create it
if [ ! -d ${KEYPATH} ];then
  if ! mkdir -p ${KEYPATH} 2>/dev/null; then
    echo "Can't create directory ${KEYPATH}, please check the permissions. Aborting"
    exit 1
  fi
fi

# Check if we already have this keys, may be from the previous installation
if [ -f ${KEY} ]; then
  echo "Keypair is already exists. Using old one"
else
  echo -n "Generating new Keypair (${KEY})..."
  # Start { command; } in the same shell, because we need to exit. Don't forget ; at the end
  ssh-keygen -t rsa -N "" -f ${KEY} > /dev/null 2>&1 && echo "Done" || { echo "Error. Aborting"; exit 1; }
fi

# try to put ssh keys on the fuel master server
# TODO: should be fixed, because of logrotate. By default it will store 4 weeks
echo
echo -n "Checking, if ${vm_name_prefix}master is running..."
if ! is_product_vm_operational $vm_master_ip $vm_master_username $vm_master_password "$vm_master_prompt"; then
  echo "[Failed]"
  echo "Please check if the ${vm_name_prefix}master node is running. Aborting"
  #TODO: we put here ok, because we need to find more robust way that fuel master deployed
  #exit 1
fi
# Master fuel is running
echo "[Ok]"

# Remove old host key, because we will have error with key-host mismatch
ssh-keygen -f ~/.ssh/known_hosts -R "${vm_master_ip}" >/dev/null 2>&1

# Check wherethere public key is already installed, just testing connection, disabling password auth
# Some bug found with new key, please see https://bugs.launchpad.net/ubuntu/+source/openssh/+bug/201786
# This will fix the issue: export SSH_AUTH_SOCK=0
if (exec ssh -i "${KEY}" -o BatchMode=yes -oConnectTimeout=5 -oStrictHostKeyChecking=no \
  -oCheckHostIP=no -oUserKnownHostsFile=/dev/null ${vm_master_username}@${vm_master_ip} > /dev/null 2>&1 true); then
  echo "Your key is already deployd"
  exit 0;
fi

# No auth by public key, let's put it on server
echo -n "Putting pub key on the ${vm_name_prefix}master..."
if hash ssh-copy-id 2>/dev/null; then
  # try to put key with ssh-copy-id
  result=$(
        expect << ENDOFEXPECT
        spawn ssh-copy-id -i ${KEY} $ssh_options ${vm_master_username}@${vm_master_ip}
        expect "connect to host" exit
        expect "*?assword:*"
        send "$password\r"
        send -- "\r"
        expect eof
ENDOFEXPECT
  )
echo "[Ok]"
else
  # TODO: Need to implement pub_key deployment using ssh + cat, but the ssh-copy-id
  # should work as it's in the same package as ssh (openssh-client)
  echo "Not yes implemented"
fi

exit 0