#!/bin/bash

files="/etc/sysctl.conf /etc/default/isc-dhcp-server /etc/network/interfaces /etc/dhcp/dhcpd.conf"

subnet="192.168.111"

backup() {
  # Back up files
  mkdir -p backup

  for file in $files; do
    if ! [ -f "backup/${file##*/}.backup" ]; then
      echo "Backing up $file"
      cp -p "$file" "backup/${file##*/}.backup"
    fi
  done

  if ! [ -f "backup/iptables.rules" ]; then
    iptables-save > backup/iptables.rules
  fi
}

restore() {
  # Restore files

  for file in $files; do
    if [ -f "backup/${file##*/}.backup" ]; then
      echo "Restoring $file"
      cp -p "backup/${file##*/}.backup" "$file"
      rm "backup/${file##*/}.backup"
    fi
  done

  if [ -f "backup/iptables.rules" ]; then
    iptables-restore < backup/iptables.rules
    rm backup/iptables.rules
  fi

  rmdir backup/ 2> /dev/null # Delete directory, if empty
}

ask_interfaces() {
  interfaces=$(netstat -i | cut -f1 -d " " | tail -n +3);
  res=0;
  until [ $(echo "$interfaces" | grep -e "^$selected_interface$") ]; do
    echo "Which interface do you want to give access? Available interfaces are:"
    echo "$interfaces"
    read -p "Select one: " selected_interface
  done
  # return $selected_interface
}

get_default_interface() {
  line=$(route -n | egrep "^0.0.0.0 ");
  default_interface=${line##* } # Interface that usually has Internet access
}

command_exists() {
  command -v "$@" > /dev/null 2>&1
}





# Check if the script is running with superuser privileges
if [ $EUID -ne 0 ]; then
  echo "This script must be run as root"
  exit 1
fi

if [ "$1" = "on" ]; then
  backup;

  if ! cat /etc/sysctl.conf | grep -q -e "net.ipv4.ip_forward=1" ; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
  fi
  sysctl -p # Load /etc/sysctl.conf

  ask_interfaces;
  get_default_interface;

  iptables -t nat -A POSTROUTING -o $default_interface -j MASQUERADE
  iptables-save > /dev/null

  if ! command_exists dhcpd; then
    echo "Installing DHCP server..."
    apt-get install -y isc-dhcp-server > /dev/null
  fi

  ## Configure DHCP server ##
  # Edit /etc/default/isc-dhcp-server to specify the interfaces dhcpd should listen to.
  sed "s/@selected_interface/${selected_interface}/g" config_files/isc-dhcp-server > /etc/default/isc-dhcp-server

  # Edit /etc/dhcp/dhcpd.conf to specify the configuration.
  sed -e "s/@subnet/${subnet}/g" config_files/dhcpd.conf > /etc/dhcp/dhcpd.conf

  touch /var/lib/dhcp/dhcpd.leases

  # Assign a static ip to the interface that is used for dhcp.
  if_text=$(sed -e "s/@selected_interface/${selected_interface}/g" \
                -e "s/@subnet/${subnet}/g" config_files/interfaces)

  if ! cat /etc/network/interfaces | grep -q -e "$if_text" ; then
    echo -e "\n$if_text" >> /etc/network/interfaces
    touch /etc/network/interfaces.d/${selected_interface}
  fi

  ifdown $selected_interface
  ifup $selected_interface

  service isc-dhcp-server restart

elif [ "$1" = "off" ]; then
  restore;
  sysctl -p # Load /etc/sysctl.conf

  read -p "Do you want to remove DHCP server? [y/N]: " -n 1 -r  res # Just 1 character
  echo
  if [[ $res =~ ^[yY]$ ]]; then # See: http://stackoverflow.com/a/1885534
    echo "Removing DHCP server..."
    apt-get remove -y isc-dhcp-server  > /dev/null
    apt-get autoremove -y > /dev/null
  fi

  ask_interfaces
  get_default_interface

  iptables -t nat -D POSTROUTING -o $default_interface -j MASQUERADE

  ifdown ${selected_interface}
  ip addr flush ${selected_interface}
  ifup ${selected_interface}

elif [ "$1" = "restart" ]; then
  $0 off
  $0 on
elif [ "$1" = "check" ]; then
  echo "Checking..."
  check;
else
  echo "Usage: $0 < on | off | restart | check >"
  exit 1
fi

exit 0
