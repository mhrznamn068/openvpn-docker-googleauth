#!/bin/bash

SERVER_DIR="/etc/openvpn"
KEY_DIR="/home/vpnserver/clients"
BASE_CONFIG="/home/vpnserver/clients/base.conf"
MFA_LABEL=$VPNSERVER
MFA_USER="gauth"
MFA_DIR="/etc/openvpn/google-authenticator"

function generate_mfa() {
  user_id=$1

  if [ "$user_id" == "" ]; then
    echo "ERROR: No user id provided to generate MFA token"
    exit 1
  fi

  echo "INFO: Creating user ${user_id}"
  useradd -s /bin/nologin "$user_id"

  echo "> Please provide a password for the user"
  passwd "$user_id"

  echo "INFO: Generating MFA Token"
  su -c "google-authenticator -t -d -r3 -R30 -f -l \"${MFA_LABEL}\" -s $MFA_DIR/${user_id}" - $MFA_USER
}

function send_mail() {
  attachment=$1

  which mutt 2>&1 >/dev/null

  if [ $? -ne 0 ]; then
    echo "INFO: mail program not found, an email will not be sent to the user"
  else
    echo -en "Please, provide the e-mail of the user\n> "
    read email
    echo "INFO: Sending email"
    echo "Here is your OpenVPN client configuration" | mutt -s "Your OpenVPN configuration" -a "$attachment" -- "$email"
  fi
}

function main() {
  user_id=$1
  if [ ! -f "/etc/openvpn/easy-rsa/pki/issued/${user_id}.crt" ]; then
  cd /etc/openvpn/easy-rsa
  ./easyrsa gen-req ${user_id} nopass
  ./easyrsa sign-req client ${user_id}
  mkdir -p /home/vpnserver/clients/${user_id}/
  cp ./pki/{issued/${user_id}.crt,private/${user_id}.key} /home/vpnserver/clients/${user_id}/
   
  cat ${BASE_CONFIG} \
      <(echo -e '<ca>') \
      ${SERVER_DIR}/server/ca.crt \
      <(echo -e '</ca>\n<cert>') \
      ${KEY_DIR}/${user_id}/${user_id}.crt \
      <(echo -e '</cert>\n<key>') \
      ${KEY_DIR}/${user_id}/${user_id}.key \
      <(echo -e '</key>') > ${KEY_DIR}/${user_id}.ovpn
  sed -i "s/remote server_ip 1194/remote $HOST_ADDR $HOST_SSL_PORT/g" ${KEY_DIR}/${user_id}.ovpn
  rm -r ${KEY_DIR}/${user_id}/
  generate_mfa $user_id
fi
}

main $1