In order to successfully run Mirantis OpenStack under VirtualBox, you need to:

- download the official release (.iso) and place it under 'iso' directory
- run "./launch.sh deploy". it will automatically pick up the iso, and will spin up master node and slave nodes
- run "./launch.sh add-slave [number_of_slaves]". it will spin up additional slave nodes
- run "./launch.sh deploy-openstack". it will automatically generate ssh-keypair to work with fuel-master. Then OpenStack components will be
deployed on free (DISCOVERED nodes). Script will automatically check for compatibility between roles (currently full support for multinode mode) and free nodes availability. The roles and OpenStack environment can be described in config.sh

Example for OpenStack cluster description (please, see Fuel Docs for mode details):
	
	# Options for OpenStack env deployment
	# fuel environment name
	ENV_NAME="Test"
	# Run slave on CentOS
	ENV_RELEASE=1
	# mode of environment
	MODE="multinode"
	# cluster configuration
	OS_CLUSTER="controller,cinder|compute|compute"


If there are any errors, the script will report them and abort.

If you want to change settings (number of OpenStack nodes, CPU, RAM, HDD, OpenStack roles), please refer to "config.sh".
