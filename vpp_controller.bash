#!/bin/bash

tunnel_ip=$1

iptables -I INPUT -j ACCEPT
apt-get install -y git
apt-get install -y dkms

####hugepages###
sysctl -w vm.nr_hugepages=10000
sysctl -w vm.max_map_count=22000
sysctl -w vm.hugetlb_shm_group=0
sysctl -w kernel.shmmax=20971520000

####vpp-honeycomb####

wget https://nexus.fd.io/content/repositories/fd.io.stable.1704.ubuntu.xenial.main/io/fd/vpp/vpp-lib/17.04-release_amd64/vpp-lib-17.04-release_amd64-deb.deb
wget https://nexus.fd.io/content/repositories/fd.io.stable.1704.ubuntu.xenial.main/io/fd/vpp/vpp/17.04-release_amd64/vpp-17.04-release_amd64-deb.deb
wget https://nexus.fd.io/content/repositories/fd.io.stable.1704.ubuntu.xenial.main/io/fd/vpp/vpp-plugins/17.04-release_amd64/vpp-plugins-17.04-release_amd64-deb.deb
wget https://nexus.fd.io/content/repositories/fd.io.stable.1704.ubuntu.xenial.main/io/fd/vpp/vpp-dpdk-dkms/17.02-vpp2_amd64/vpp-dpdk-dkms-17.02-vpp2_amd64-deb.deb
wget https://nexus.fd.io/content/repositories/fd.io.stable.1704.ubuntu.xenial.main/io/fd/nsh_sfc/vpp-nsh-plugin/17.04_amd64/vpp-nsh-plugin-17.04_amd64-deb.deb
wget https://nexus.fd.io/content/repositories/fd.io.stable.1704.ubuntu.xenial.main/io/fd/hc2vpp/honeycomb/1.17.04-RELEASE_all/honeycomb-1.17.04-RELEASE_all-deb.deb

dpkg -i vpp-lib-17.04-release_amd64-deb.deb vpp-17.04-release_amd64-deb.deb vpp-plugins-17.04-release_amd64-deb.deb vpp-dpdk-dkms-17.02-vpp2_amd64-deb.deb vpp-nsh-plugin-17.04_amd64-deb.deb

echo "unix {
  nodaemon
  log /tmp/vpp.log
  full-coredump
}

api-trace {
  on
}

api-segment {
  gid vpp
}

dpdk {

  dev 0000:00:07.0

}" > '/etc/vpp/startup.conf'

service vpp restart

sleep 5

vppctl set interface state GigabitEthernet0/7/0 up
vppctl set interface ip addr GigabitEthernet0/7/0 $tunnel_ip

dpkg -i honeycomb-1.17.04-RELEASE_all-deb.deb 

sed -i 's/"127.0.0.1"/"0.0.0.0"/g' /opt/honeycomb/config/honeycomb.json

cat >> /opt/honeycomb/config/vppnsh.json << EOF
{
  "nsh-enabled": "true"
}
EOF

sed -i 's/"false"/"true"/' /opt/honeycomb/config/vppnsh.json

service honeycomb restart


service opendaylight stop
wget https://nexus.opendaylight.org/content/repositories/opendaylight.snapshot/org/opendaylight/integration/distribution-karaf/0.6.0-SNAPSHOT/distribution-karaf-0.6.0-20170513.205245-5260.tar.gz
tar -xzvf distribution-karaf-0.6.0-20170513.205245-5260.tar.gz
pushd distribution-karaf-0.6.0-SNAPSHOT/etc/
cp /opt/opendaylight/etc/jetty.xml .
popd

  #sed -i 's/^interface_driver =.*$/interface_driver = neutron.agent.linux.interface.NSDriver/' /etc/neutron/dhcp_agent.ini
  #sed -i 's/^interface_driver =.*$/interface_driver = neutron.agent.linux.interface.NSDriver/' /etc/neutron/l3_agent.ini

####apply_openstack_newton_patches#####
echo "port_binding_controller=pseudo-agentdb-binding" >> '/etc/neutron/plugins/ml2/ml2_conf.ini'
echo "ODL_HOSTCONF_URI=restconf/operational/neutron:neutron/hostconfigs" >> '/etc/neutron/plugins/ml2/ml2_conf.ini'
pushd /usr/lib/python2.7/dist-packages 

git apply ~/vpp_bash/Driver.patch

popd

rm -rf /usr/lib/python2.7/dist-packages/networking_odl*

git clone https://github.com/openstack/networking-odl.git

pushd networking-odl

git checkout stable/newton

python setup.py install

popd
	
service neutron-l3-agent restart
service neutron-dhcp-agent restart
service neutron-server restart

iptables -I INPUT -j ACCEPT



# The names of the honeycomb agents should be the same with the hostname of the host that they were running
# For the hugepages follow the steps here https://access.redhat.com/solutions/36741 
# Also we should delete all the existing networks of the neutron (neutron port-list output should be empty) ,delete the ovs bridges 
# http://superuser.openstack.org/articles/open-daylight-integration-with-openstack-a-tutorial/
# create the neutron networks again 
# Possible bug of vpp-odl it takes too long to create the first internal subnet
# Also to spin up a VM you should use a metatdata for the flavor related to hugepages like this:
# openstack flavor set m1.large --property hw:mem_page_size=large (maybe we should increase the RAM of the flavor to 1GB)
# We could execute ps -ef | grep qemu    to the compute node to see if the VM has acces to hugepages of the host """" mempath""""












 
