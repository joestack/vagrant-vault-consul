#!/bin/bash
set -x

echo "Running"

# Detect package management system.
YUM=$(which yum 2>/dev/null)
APT_GET=$(which apt-get 2>/dev/null)

if [[ ! -z ${YUM} ]]; then
  SYSTEMD_DIR="/etc/systemd/system"
  echo "Installing consul systemd service for RHEL/CentOS"
elif [[ ! -z ${APT_GET} ]]; then
  SYSTEMD_DIR="/lib/systemd/system"
  echo "Installing consul systemd service for Debian/Ubuntu"
else
  echo "Service not installed due to OS detection failure"
  exit 1;
fi


cat <<EOF >${SYSTEMD_DIR}/consul.service
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/consul.hcl

[Service]
User=consul
Group=consul
EnvironmentFile=/etc/consul.d/consul.conf
ExecStart=/usr/bin/consul agent -config-dir=/etc/consul.d/ \$FLAGS
ExecReload=/bin/kill --signal HUP \$MAINPID
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable consul
sudo systemctl start consul

echo "Complete"
