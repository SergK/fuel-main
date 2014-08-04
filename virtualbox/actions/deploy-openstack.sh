#!/bin/bash

#set -x

source config.sh
source functions/fuel.sh

# # fuel environment name
# ENV_NAME="MyEnv2"
# # Run slave on CentOS
# ENV_RELEASE=1 # centos
# # mode of environment
# MODE="multinode"
# # cluster configuration
# OS_CLUSTER="controller,cinder|compute|compute"



deploy_openstack ${ENV_NAME} ${OS_CLUSTER} ${MODE} ${ENV_RELEASE}