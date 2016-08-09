# Reverse AP

Reverse AP is a personal project to solve a common problem: giving Internet
access to a device without a WiFI network adapter in a wireless environment. We
can use a laptop as router and give connection to the device through the Ethernet
port. This is really useful for devices like Raspberry Pi or when you are
repairing an old desktop computer.


## Basics about Reverse AP

The main concepts under the shell script are the following:

- Edit configuration files `/etc/default/isc-dhcp-server`,
`/etc/network/interfaces` and `/etc/dhcp/dhcpd.conf` to suit needs and
particular configuration.
- Enable ip forwarding `/proc/sys/net/ipv4/ip_forward`.
- Run DHCP server `isc-dhcp-server`.
- Add iptables nat rule.

Files will be backed up.


## Install

Check the configuration templates in [config_files](config_files). Then, if you
want to install all these configurations, run in your shell:

```shell
sudo ./script.sh on
```

Your original files will be backed up in `./backup` directory.

To uninstall and get your original configuration, run:

```shell
sudo ./script.sh off
```

### Think before run
Be careful! I'm not trying to make a global script for all Linux distribution
families, I just want to share it so that you can suit the script for your needs.

### Future work: Dockerize DHCP server

It could be interesting to dockerize the DHCP server.

### Contribution

PRs and reporting issues are really welcome.

### License
The content of this repository is licensed under a MIT [LICENSE](LICENSE).
