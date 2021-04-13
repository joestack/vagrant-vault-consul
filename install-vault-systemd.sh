#!/bin/bash
set -x

echo "Running"

# Detect package management system.
YUM=$(which yum 2>/dev/null)
APT_GET=$(which apt-get 2>/dev/null)

if [[ ! -z ${YUM} ]]; then
  SYSTEMD_DIR="/etc/systemd/system"
  echo "Installing systemd services for RHEL/CentOS"
elif [[ ! -z ${APT_GET} ]]; then
  SYSTEMD_DIR="/lib/systemd/system"
  echo "Installing systemd services for Debian/Ubuntu"
else
  echo "Service not installed due to OS detection failure"
  exit 1;
fi

cat <<EOF >${SYSTEMD_DIR}/vault.service
[Unit]
Description=Vault Agent
Requires=consul-online.target
After=consul-online.target

[Service]
Restart=on-failure
EnvironmentFile=/etc/vault.d/vault.conf
PermissionsStartOnly=true
ExecStartPre=/sbin/setcap 'cap_ipc_lock=+ep' /usr/bin/vault
ExecStart=/usr/bin/vault server -config /etc/vault.d \$FLAGS
ExecReload=/bin/kill -HUP \$MAINPID
KillSignal=SIGTERM
User=vault
Group=vault
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > ${SYSTEMD_DIR}/consul-online.service
[Unit]
Description=Consul Online
Requires=consul.service
After=consul.service

[Service]
Type=oneshot
ExecStart=/usr/bin/consul-online.sh
User=consul
Group=consul

[Install]
WantedBy=consul-online.target multi-user.target
EOF

cat <<EOF > ${SYSTEMD_DIR}/consul-online.target
[Unit]
Description=Consul Online
RefuseManualStart=true
EOF

cat <<EOF > ${SYSTEMD_DIR}/consul-online.sh

#!/bin/bash

set -e
set -o pipefail

CONSUL_HTTP_ADDR=${1:-"http://127.0.0.1:8500"}

# waitForConsulToBeAvailable loops until the local Consul agent returns a 200
# response at the /v1/operator/raft/configuration endpoint.
#
# Parameters:
#     None
function waitForConsulToBeAvailable() {
  local consul_http_addr=$1
  local consul_leader_http_code

  consul_leader_http_code=$(curl --silent --output /dev/null --write-out "%{http_code}" "${consul_http_addr}/v1/operator/raft/configuration") || consul_leader_http_code=""

  while [ "x${consul_leader_http_code}" != "x200" ] ; do
    echo "Waiting for Consul to get a leader..."
    sleep 5
    consul_leader_http_code=$(curl --silent --output /dev/null --write-out "%{http_code}" "${consul_http_addr}/v1/operator/raft/configuration") || consul_leader_http_code=""
  done
}

waitForConsulToBeAvailable "${CONSUL_HTTP_ADDR}"
EOF

# sudo chmod 0664 ${SYSTEMD_DIR}/{vault*,consul*}

sudo systemctl enable consul
sudo systemctl start consul

sudo systemctl enable vault
sudo systemctl start vault

echo "Complete"
