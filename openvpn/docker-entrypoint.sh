#!/bin/bash

server_name=$VPNSERVER

if [ ! -f "/etc/openvpn/easy-rsa/pki/ca.crt" ]; then
  cd /etc/openvpn/easy-rsa
  # Init PKI dirs and build CA certs
  ./easyrsa init-pki
  ./easyrsa build-ca nopass
  ./easyrsa gen-req ${server_name} nopass
  ./easyrsa sign-req server ${server_name}
  ./easyrsa gen-dh

  cp /etc/openvpn/easy-rsa/pki/{ca.crt,issued/${server_name}.crt,private/${server_name}.key,dh.pem} "/etc/openvpn/server"

  if [[ -z $server_port ]]; then
    server_port="443"
  fi

fi

mkdir /dev/net
if [ ! -f /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200
fi

primary_nic=`ip route | grep default | cut -d ' ' -f 5`

# Iptable rules
iptables -I FORWARD -i tun0 -j ACCEPT
iptables -I FORWARD -o tun0 -j ACCEPT
iptables -I OUTPUT -o tun0 -j ACCEPT

iptables -A FORWARD -i tun0 -o $primary_nic -j ACCEPT
iptables -t nat -A POSTROUTING -o $primary_nic -j MASQUERADE
iptables -t nat -A POSTROUTING -s $VPN_NETWORK_SUBNET -o $primary_nic -j MASQUERADE
iptables -t nat -A POSTROUTING -s $VPN_NETWORK_SUBNET -o $primary_nic -j MASQUERADE

# ensure that we are using the port specifiedby HOST_SSL_PORT
sed -i "s/port 1194/port $HOST_SSL_PORT/g" /etc/openvpn/server.conf
sed -i "s/cert server\/server.crt/cert server\/$server_name.crt/g" /etc/openvpn/server.conf
sed -i "s/key server\/server.key/key server\/$server_name.key/g" /etc/openvpn/server.conf

# Need to feed key password
/usr/sbin/openvpn --cd /etc/openvpn/ --config /etc/openvpn/server.conf

tail -f /dev/null