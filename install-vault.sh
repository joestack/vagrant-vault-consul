#!/bin/bash
set -x

echo "Running"

VAULT_VERSION=${VERSION}
#VAULT_ZIP=vault_${VAULT_VERSION}_linux_amd64.zip
#VAULT_URL=${URL:-https://releases.hashicorp.com/vault/${VAULT_VERSION}/${VAULT_ZIP}}
VAULT_DIR=/usr/bin
VAULT_PATH=${VAULT_DIR}/vault
VAULT_CONFIG_DIR=/etc/vault.d
VAULT_DATA_DIR=/opt/vault/data
VAULT_TLS_DIR=/opt/vault/tls
VAULT_ENV_VARS=${VAULT_CONFIG_DIR}/vault.conf
VAULT_PROFILE_SCRIPT=/etc/profile.d/vault.sh


# Detect package management system.
YUM=$(which yum 2>/dev/null)
APT_GET=$(which apt-get 2>/dev/null)

if [[ ! -z ${YUM} ]]; then
  echo "Downloading Vault ${VAULT_VERSION}"
  sudo yum -y install vault-${VAULT_VERSION}
elif [[ ! -z ${APT_GET} ]]; then
  echo "Downloading Vault ${VAULT_VERSION}"
  sudo apt-get update && sudo apt-get install vault=${VAULT_VERSION}
else
  echo "Prerequisites not installed due to OS detection failure"
  exit 1;
fi

echo "Start Vault in -dev mode"
sudo tee ${VAULT_ENV_VARS} > /dev/null <<ENVVARS
FLAGS=-dev -dev-ha -dev-transactional -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200
ENVVARS


cat <<EOF >${VAULT_CONFIG_DIR}/vault.hcl
# Full configuration options can be found at https://www.vaultproject.io/docs/configuration

ui = true

#mlock = true
#disable_mlock = true

#storage "file" {
#  path = "/opt/vault/data"
#}

storage "consul" {
  address = "127.0.0.1:8500"
  path    = "vault"
}

# HTTP listener
#listener "tcp" {
#  address = "127.0.0.1:8200"
#  tls_disable = 1
#}

# HTTPS listener
#listener "tcp" {
#  address       = "0.0.0.0:8200"
#  tls_cert_file = "/opt/vault/tls/tls.crt"
#  tls_key_file  = "/opt/vault/tls/tls.key"
#}

# Example AWS KMS auto unseal
#seal "awskms" {
#  region = "us-east-1"
#  kms_key_id = "REPLACE-ME"
#}

# Example HSM auto unseal
#seal "pkcs11" {
#  lib            = "/usr/vault/lib/libCryptoki2_64.so"
#  slot           = "0"
#  pin            = "AAAA-BBBB-CCCC-DDDD"
#  key_label      = "vault-hsm-key"
#  hmac_key_label = "vault-hsm-hmac-key"
#}
EOF

echo "Set Vault profile script"
sudo tee ${VAULT_PROFILE_SCRIPT} > /dev/null <<PROFILE
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root
PROFILE

echo "Granting mlock syscall to vault binary"
sudo setcap cap_ipc_lock=+ep ${VAULT_PATH}

echo "Complete"
