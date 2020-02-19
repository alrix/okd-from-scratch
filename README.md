Simple ansible playbooks, roles and scripts to prepare a basic Openshift cluster on your laptop. You can then run the openshift ansible playbooks against the provided inventory to deploy a fully operational HA Openshift Cluster.

The cluster comprises of: 

* 3 master nodes running openshift + glusterfs
* 1 load balancer running HA Proxy + nfs

Nodes are running centos 7 and Openshift 3.11

You will need to prepare 4 virtual machines up front. It requires a fairly beefy machine with at least 16G RAM. A shell script scripts/setup_vms.sh shows how to setup the VMs in KVM. 

Once the VMs are setup, run the ansible playbook as follows:

```
ansible-playbook -i inventory/hosts configure.yml
```

Once successfully run, clone the openshift-ansible playbooks from https://github.com/openshift/openshift-ansible. Check out the appropriate branch for the cluster version. Then you can run the usual openshift-ansible deployment using:

```
ansible-playbook -i <path to inventory/hosts> playbooks/prerequisites.yml
ansible-playbook -i <path to inventory/hosts> playbooks/deploy_cluster.yml
```







