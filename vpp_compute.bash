#!/bin/bash
set -e
tunnel_ip=$1

iptables -I INPUT -j ACCEPT
apt-get install -y git openjdk-8-jdk

mkdir -p /hugepages 
mount -t hugetlbfs hugetlbfs /hugepages

echo "soft memlock 8388608
hard memlock 8388608" >> '/etc/security/limits.conf'

echo "vm.nr_hugepages=10000
vm.max_map_count=22000
vm.hugetlb_shm_group=0
kernel.shmmax=20971520000">> '/etc/sysctl.conf'

echo "VHOST_NET_ENABLED=1
KVM_HUGEPAGES=1">> '/etc/default/qemu-kvm'

sed -i -e 's/hugetlbfs_mount=""/hugetlbfs_mount="\/hugepages"/g' /etc/libvirt/qemu.conf

echo 'owner "/hugepages/libvirt/qemu/**" rw,' >> '/etc/apparmor.d/abstractions/libvirt-qemu'

service qemu-kvm restart
service libvirt-bin restart
service libvirt-guests restart 
service nova-compute restart

sleep 7

####hugepages###
#sysctl -w vm.nr_hugepages=10000
#sysctl -w vm.max_map_count=22000
#sysctl -w vm.hugetlb_shm_group=0
#sysctl -w kernel.shmmax=20971520000
	
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

















 
