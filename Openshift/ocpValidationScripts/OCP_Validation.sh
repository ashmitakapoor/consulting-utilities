#! /bin/bash

mkdir ocpvalidation
cd ocpvalidation

#check ansible.cfg for changes.
#iostats

########### Check subscriptions attached ###########
ansible -i $INVENTORY_FILE_PATH OSEv3 -a 'subscription-manager list --consumed' > subscription.log

########### CPU/Node ###########
ansible -i $INVENTORY_FILE_PATH OSEv3  -a 'lscpu' > lscpu.log

########### Meminfo ###########
ansible -i $INVENTORY_FILE_PATH OSEv3  -a 'cat /proc/meminfo' > meminfo.log

########### Storage utilization###########
ansible -i $INVENTORY_FILE_PATH OSEv3 -a 'df -h' > df.log

########### Storage on each node ###########
ansible -i $INVENTORY_FILE_PATH OSEv3 -a 'lsblk' > lsblk.log

########### NTP ###########
ansible -i $INVENTORY_FILE_PATH OSEv3 -a 'timedatectl' > timedatactl.log

########### Entropy ###########
ansible -i $INVENTORY_FILE_PATH OSEv3 -a 'cat /proc/sys/kernel/random/entropy_avail' > entropy.log

########### Verify Selinux is enforcing or not ###########
ansible -i $INVENTORY_FILE_PATH OSEv3 -a 'getenforce' > selinux.log

########### Verify /etc/hosts && /etc/resolv.conf entries ########### 
ansible -i $INVENTORY_FILE_PATH OSEv3 -a '/etc/hosts' > etc-hosts.log
ansible -i $INVENTORY_FILE_PATH OSEv3 -a '/etc/resolv' > etc-resolv.log

########### Dnsmasq is active ###########
ansible -i $INVENTORY_FILE_PATH OSEv3 -a 'systemctl is-active dnsmasq' > dnsmasq.log

########### Verify correct dns files are created ###########
ansible -i $INVENTORY_FILE_PATH OSEv3 -a 'cat /etc/dnsmasq.d/origin-upstream-dns.conf' > origin-dns.log

########### Firewalld is active ###########
ansible -i $INVENTORY_FILE_PATH OSEv3 -a 'systemctl is-active firewalld' > dnsmasq.log

########### Proxy configuration ###########
ansible -i $INVENTORY_FILE_PATH OSEv3 -a 'cat /etc/environment' > proxy.log

########### Docker config ###########
ansible -i $INVENTORY_FILE_PATH OSEv3 -a 'cat /etc/sysconfig/docker-storage' > docker-storage.log
ansible -i $INVENTORY_FILE_PATH OSEv3 -a 'cat /etc/sysconfig/docker-storage-setup' > docker-storage-setup.log
ansible -i $INVENTORY_FILE_PATH OSEv3 -m shell -a 'cat /etc/sysconfig/docker | grep OPTIONS' > docker-config.log

########### Node Status ###########
oc get nodes > nodestatus.log

##### Verify web-console installation #####


################################ ETCD ##############################
########### verify etcd install ###########
ansible -i $INVENTORY_FILE_PATH OSEv3 -a 'yum install etcd' > etcdinstalllog

############ Verify etcd cluster health ##########
source /etc/etcd/etcd.conf
etcdctl --cert-file=$ETCD_PEER_CERT_FILE --key-file=$ETCD_PEER_KEY_FILE --ca-file=/etc/etcd/ca.crt --endpoints=$ETCD_LISTEN_CLIENT_URLS cluster-health > etcdclusterhealth.log

############ Verify etcd member list ##########
etcdctl --cert-file=$ETCD_PEER_CERT_FILE --key-file=$ETCD_PEER_KEY_FILE --ca-file=/etc/etcd/ca.crt --endpoints=$ETCD_LISTEN_CLIENT_URLS member list > etcdmemberlist.log

############################## Router ##############################
oc -n default get deploymentconfigs/router > routerhealth.log

############################## Registry ##############################
oc -n default get deploymentconfigs/docker-registry > registryhealth.log
############ Verify Registry Storage ##########
oc get pvc -n default

############################## Metric ##############################
oc get pvc -n openshift-infra
oc project openshift-metrics-server

############Scale pod up/down to verify hpa############
oc autoscale dc/<> --min 1 --max 10 --cpu-percent=80

############ Network ##########
#Verify SkyDNS
dig *.tclservices.tatacapital.com 

dig +short docker-registry.default.svc.cluster.local
#should match
oc get svc/docker-registry -n default

#On any node
curl https://internal-master.example.com:443/version
curl -k https://master.example.com:443/healthz

oc get clusternetwork > clusternetwork.log
oc get hostsubnets > hostsubnets.log
oc get netnamespaces > netnamespaces.log

############ Components Health ##########
oc get componentstatuses > componentstatuses.log

############ Mem/CPU Statistics ##########
oc adm top nodes > nodeMem.log
oc adm top pods  > podMem.log
oc adm top images > imageMem.log
oc adm top imagestreams > imagestreamMem.log

############ Project Quota ##########
oc get quota -n <Projects>
#####Check whether pod limit has been set

############ Storage ##########
oc get storageclass > storageclass.log
oc get pv > pv.log
###Check storage given to apps

############ User ##########
oc get users > users.log


############ E2E OCP check##########
oc new-project validate
oc new-app cakephp-mysql-example
oc logs -f bc/cakephp-mysql-example
oc get pods
oc rsh pods <podname>
#internal registry is reachable from within the pod and outside the pod
curl -kv https://docker-registry.default.svc.cluster.local:5000/healthz
#Visit the application URL
oc delete project validate

############ All pod unhealthy ##########
oc get pods --all-namespaces | egrep -v 'Running | Completed' > podUnhealthy.log

############ Ansible based health check ##########
ansible-playbook -i $INVENTORY_FILE_PATH OSEv3 playbooks/openshift-checks/health.yml
# https://access.redhat.com/documentation/en-us/openshift_container_platform/3.11/html-single/cluster_administration/index#ansible-based-tooling-health-checks


################ Verify CICD setup #############
