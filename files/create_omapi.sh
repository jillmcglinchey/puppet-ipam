#!/usr/bin/env bash


echo "**** Script to create omapi keys for IPAM cluster ****"

OMAPI_KEY_NAME=`hostname -f`
# OMAPI_KEYS_DIR=`find / -name bind.keys.d`

echo "**** Waiting for creation of directory bind.keys.d ****"

until [ -d "$OMAPI_KEYS_DIR" ]
do 
  OMAPI_KEYS_DIR=`find / -name bind.keys.d`
  echo -n "#"
done

echo "****"$OMAPI_KEYS_DIR" Found ****"

echo "**** Creating OMAPI Key ****"
cd $OMAPI_KEYS_DIR
dnssec-keygen -r /dev/urandom -a HMAC-MD5 -b 512 -n HOST $OMAPI_KEY_NAME

echo "**** Creating OMAPI Secret FIle  ****"
export OMAPI_SECRET=`cat $OMAPI_KEYS_DIR/K${OMAPI_KEY_NAME}.+*.private |grep ^Key| cut -d ' ' -f2-`
## cat $OMAPI_KEYS_DIR/Komapi_k.+*.private |grep ^Key| cut -d ' ' -f2-
echo 'secret "'$OMAPI_SECRET'";' > ${OMAPI_KEYS_DIR}/${OMAPI_KEY_NAME}.secret

echo "**** Creating OMAPI Key FIle  ****"

cat <<EOF > ${OMAPI_KEYS_DIR}/${OMAPI_KEY_NAME}.key
key "${OMAPI_KEY_NAME}" {
  algorithm hmac-md5;
  secret "${OMAPI_SECRET}";
}
EOF

exit
