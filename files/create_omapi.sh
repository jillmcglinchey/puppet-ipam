#!/usr/bin/env bash

exec &>> $HOME/create_omapi_key.log
echo "**** Script to create omapi keys for IPAM cluster **********"
echo "**** Determining Key Variables *****************************"

# Variables
OMAPI_KEY_NAME=omapi_key
RNDC_KEY_NAME=dhcp_updater
DN=`hostname -d`
FQDN=`hostname -f`
PRIMARY=ipam1.$DN
SECONDARY=ipam2.$DN
VAGRANT_IPAM_SHARE="/etc/puppetlabs/puppet/data"

# Confirm Variables
echo "**** Displaying Variables                               ****"
echo "**** Domain Name:$DN                          ****"
echo "**** Fully Qualified Domain Name:$FQDN        ****"
echo "**** IPAM_PRIMARY:$PRIMARY                   ****"
echo "**** OMAPI_KEY_NAME: $OMAPI_KEY_NAME          ****"
echo "**** RNDC_KEY_NAME: $RNDC_KEY_NAME            ****"
echo "**** IPAM_SECONDARY:$SECONDARY               ****"

# Begin Waiting for bind.keys.d to CD into
echo "**** Waiting for creation of directory bind.keys.d      ****"
echo "**** which is created during first execution of puppet. ****"
until [ -d "$BIND_KEYS_DIR" ]
do 
  BIND_KEYS_DIR=`find / -name bind.keys.d`
  echo "#"
done
echo "**** "$BIND_KEYS_DIR" Found ***********************"
cd $BIND_KEYS_DIR

# Check if Secondary else Create RNDC/OMAPI Keys
if [[ $FQDN == $SECONDARY ]]; then
  until [ -e $OMAPI_TARBALL ]
  do
    OMAPI_TARBALL=`find / -name omapi_key.tgz`
    echo "!"
  done
  echo "!!!! OMAPI_TARBALL Found                              !!!!"
  echo "**** Extracting OMAPI Key Archive from ipam1          ****"
  tar -xvzf $VAGRANT_IPAM_SHARE/omapi_key.tgz
  exit
else

echo "**** Creating rndc.key *************************************"
rndc-confgen -a -r /dev/urandom -A HMAC-MD5 -b 512 -k ${RNDC_KEY_NAME} -c ${BIND_KEYS_DIR}/dhcpupdater.key

export RNDC_KEY_FILE=`find / -name dhcpupdater.key`
export RNDC_CONF_FILE=`find / -name rndc.conf`
echo "**** RNDC_KEY_FILE: $RNDC_KEY_FILE               ****"
export RNDC_SECRET_KEY=`cat ${RNDC_KEY_FILE} |awk '{ print $8 }'`
echo "**** RNDC_SECRET_KEY: $RNDC_SECRET_KEY           ****"

# Currently the Output of this is identical to the output generated by the rndc.key
#cat <<EOF > ${BIND_KEYS_DIR}/rndc.conf
#key "${RNDC_KEY_NAME}" {
#  algorithm hmac-md5;
#  secret "${RNDC_SECRET_KEY}";
#}
#EOF

# Detect rndc.conf
export RNDC_CONF_FILE=`find / -name rndc.conf`
echo "**** Existing RNDC_CONF_FILE $RNDC_CONF_FILE           ****"


echo "**** Creating OMAPI Key for ISC-DHCP-Server Mgmt       ****"
dnssec-keygen -r /dev/urandom -a HMAC-MD5 -b 512 -n HOST $OMAPI_KEY_NAME

echo "!!!! Creating OMAPI Secret FIle !!!!!!!!!!!!!!!!!!!!!!!!!!!"
export OMAPI_PRIVATE_KEY=`cat ${BIND_KEYS_DIR}/K${OMAPI_KEY_NAME}.+*.private |grep ^Key| cut -d ' ' -f2-`
export OMAPI_SECRET_KEY=`cat ${BIND_KEYS_DIR}/K${OMAPI_KEY_NAME}.+*.key |awk '{ print $8 }'`
echo 'secret "'$OMAPI_PRIVATE_KEY'";' > ${BIND_KEYS_DIR}/${OMAPI_KEY_NAME}.secret
echo "**** OMAPI_PRIVATE_KEY: ${OMAPI_PRIVATE_KEY} ****"
echo "**** OMAPI_SECRET_KEY: ${OMAPI_SECRET_KEY}      ****"
echo "!!!! Creating OMAPI Key FIle  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
cat <<EOF > ${BIND_KEYS_DIR}/omapi.key
key "${OMAPI_KEY_NAME}" {
  algorithm hmac-md5;
  secret "${OMAPI_SECRET_KEY}";
};
EOF
echo "**** Set Permissions on ${BIND_KEYS_DIR}/omapi.key ********"
chmod 775 ${BIND_KEYS_DIR}/omapi.key


echo "**** Creating groups/common.yaml with Key Data for IPAM2 Vagrant Host ****"
cat <<EOF > /etc/puppetlabs/code/modules/ipam/files/hiera/groups/common.yaml
---
# puppet-ipam/files/hiera/data/groups/common.yaml
# This file is dynamically generated during the Vagrant Up or Build -v operations
# While build -v automatically removes this during it's post cleanup operations
# it is necessary to run ./files/cleanup.sh from the project directory to remove 
# artifacts created and used during the vagrant run.

# Commented Out for Testing
#dns::server::params::rndc_key_file: "%{::dns::server::cfg_dir}/bind.keys.d/dhcpupdater.key"
#dhcp::dnsupdatekey: "%{::dns::server::cfg_dir}/bind.keys.d/dhcpupdater.key"
#dhcp::dnskeyname: "${RNDC_KEY_NAME}"
dns::server::params::rndc_key_file: "%{::dns::server::cfg_dir}/bind.keys.d/omapi.key"
dhcp::dnsupdatekey: "%{::dns::server::cfg_dir}/bind.keys.d/omapi.key"
dhcp::dnskeyname: "${OMAPI_KEY_NAME}"
dhcp::omapi_name: "${OMAPI_KEY_NAME}"
dhcp::omapi_key: "${OMAPI_SECRET_KEY}"
dhcp::omapi_port: 7911
EOF


cat <<EOF > ${BIND_KEYS_DIR}/ipam.env
IPAM_PRIMARY=$PRIMARY
IPAM_SECONDARY=$SECONDARY

RNDC_KEY_NAME=$RNDC_KEY_NAME
RNDC_KEY_FILE=$RNDC_KEY_FILE
RNDC_SECRET_KEY=$RNDC_SECRET_KEY

OMAPI_KEY_NAME=$OMAPI_KEY_NAME
OMAPI_SECRET_KEY=$OMAPI_SECRET_KEY
OMAPI_PRIVATE_KEY=$OMAPI_PRIVATE_KEY
OMAPI_TARBALL=$OMAPI_TARBALL
VAGRANT_IPAM_SHARE=$VAGRANT_IPAM_SHARE
EOF

echo "**** Creating Tarball of DHCP/DNS Key Data *****************"
tar -cvzf $VAGRANT_IPAM_SHARE/omapi_key.tgz ${RNDC_KEY_FILE} *.*

exit
fi
