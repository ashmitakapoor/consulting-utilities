#! /bin/bash

$1=INVENTORY_FILE_PATH
$2=ELASTICSEARCH_APP_POD
$3=ELASTICSEARCH_OPS_POD

mkdir ocpvalidation
cd ocpvalidation

########### Check ansible.cfg file for changes ######

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
oc get pvc -n default > registryPVC.log

############################## Metric ##############################
oc get pvc -n openshift-infra > metricsPVC.log

############ Network ##########
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

############ All pod unhealthy ##########
oc get pods --all-namespaces | egrep -v 'Running | Completed' > podUnhealthy.log

################ Verify EFK setup #############

########Elasticsearch health########
oc exec $ELASTICSEARCH_APP_POD -- curl -s --key /etc/elasticsearch/secret/admin-key --cert /etc/elasticsearch/secret/admin-cert --cacert /etc/elasticsearch/secret/admin-ca https://localhost:9200/_cat/health?v > esAppHealth.log
oc exec $ELASTICSEARCH_OPS_POD -- curl -s --key /etc/elasticsearch/secret/admin-key --cert /etc/elasticsearch/secret/admin-cert --cacert /etc/elasticsearch/secret/admin-ca https://localhost:9200/_cat/health?v > esOpsHealth.log
########Node Status########
oc exec $ELASTICSEARCH_APP_POD -- curl -s --key /etc/elasticsearch/secret/admin-key --cert /etc/elasticsearch/secret/admin-cert --cacert /etc/elasticsearch/secret/admin-ca https://localhost:9200/_cat/nodes?v > esNodeAppHealth.log
oc exec $ELASTICSEARCH_OPS_POD -- curl -s --key /etc/elasticsearch/secret/admin-key --cert /etc/elasticsearch/secret/admin-cert --cacert /etc/elasticsearch/secret/admin-ca https://localhost:9200/_cat/nodes?v > esNodeOpsHealth.log
########Index Health########
oc exec $ELASTICSEARCH_APP_POD -- curl -s --key /etc/elasticsearch/secret/admin-key --cert /etc/elasticsearch/secret/admin-cert --cacert /etc/elasticsearch/secret/admin-ca https://localhost:9200/_cat/indices?v > IndexAppHealth.log
oc exec $ELASTICSEARCH_OPS_POD -- curl -s --key /etc/elasticsearch/secret/admin-key --cert /etc/elasticsearch/secret/admin-cert --cacert /etc/elasticsearch/secret/admin-ca https://localhost:9200/_cat/indices?v > IndexOpsHealth.log
########Unassigned Shards afect health of the cluster########
oc exec $ELASTICSEARCH_APP_POD -- curl -s --key /etc/elasticsearch/secret/admin-key --cert /etc/elasticsearch/secret/admin-cert --cacert /etc/elasticsearch/secret/admin-ca https://localhost:9200/_cat/shards?h=index,shard,prirep,state,unassigned.reason | grep UNASSIGNED >unassignedShardApp.log
oc exec $ELASTICSEARCH_OPS_POD -- curl -s --key /etc/elasticsearch/secret/admin-key --cert /etc/elasticsearch/secret/admin-cert --cacert /etc/elasticsearch/secret/admin-ca https://localhost:9200/_cat/shards?h=index,shard,prirep,state,unassigned.reason | grep UNASSIGNED >unassignedShardOps.log
########ThreadPool########
oc exec $ELASTICSEARCH_APP_POD -- curl -s --key /etc/elasticsearch/secret/admin-key --cert /etc/elasticsearch/secret/admin-cert --cacert /etc/elasticsearch/secret/admin-ca https://localhost:9200/_cat/thread_pool?v\&h=host,bulk.completed,bulk.rejected,bulk.queue,bulk.active,bulk.queueSize
oc exec $ELASTICSEARCH_OPS_POD -- curl -s --key /etc/elasticsearch/secret/admin-key --cert /etc/elasticsearch/secret/admin-cert --cacert /etc/elasticsearch/secret/admin-ca https://localhost:9200/_cat/thread_pool?v\&h=host,bulk.completed,bulk.rejected,bulk.queue,bulk.active,bulk.queueSize
