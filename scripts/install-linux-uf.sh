#!/usr/bin/env bash
# Install the Splunk Universal Forwarder on Ubuntu 24.04 and forward syslog + auth.log.
#
# Usage (on the Ubuntu UF Server):
#   chmod +x install-linux-uf.sh
#   SPLUNK_SERVER=172.31.40.91 ./install-linux-uf.sh
#
# SPLUNK_SERVER must be the Splunk Server's PRIVATE IP.
# If the download URL returns 404, copy the current wget link for the Universal Forwarder
# Linux .deb from splunk.com and set UF_URL. Make sure it contains "universalforwarder".

set -euo pipefail

: "${SPLUNK_SERVER:?Set SPLUNK_SERVER to the Splunk Server private IP, e.g. SPLUNK_SERVER=172.31.40.91}"
UF_VERSION="${UF_VERSION:-10.6.1.1}"
UF_BUILD="${UF_BUILD:-b2ae2962645c}"
DEB="splunkforwarder-${UF_VERSION}-${UF_BUILD}-linux-amd64.deb"
UF_URL="${UF_URL:-https://download.splunk.com/products/universalforwarder/releases/${UF_VERSION}/linux/${DEB}}"
UF_HOME=/opt/splunkforwarder
ADMIN_USER="${ADMIN_USER:-admin}"

read -r -s -p "Choose an admin password for this forwarder (8+ characters): " ADMIN_PASS; echo
if [ "${#ADMIN_PASS}" -lt 8 ]; then echo "Password must be at least 8 characters." >&2; exit 1; fi

echo "==> Updating packages"
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

echo "==> Downloading Universal Forwarder ${UF_VERSION}"
wget -q --show-progress -O "/tmp/${DEB}" "${UF_URL}"

echo "==> Installing"
sudo dpkg -i "/tmp/${DEB}"
rm -f "/tmp/${DEB}"

echo "==> Writing admin seed, outputs.conf and inputs.conf"
sudo tee "${UF_HOME}/etc/system/local/user-seed.conf" >/dev/null <<EOF
[user_info]
USERNAME = ${ADMIN_USER}
PASSWORD = ${ADMIN_PASS}
EOF

sudo tee "${UF_HOME}/etc/system/local/outputs.conf" >/dev/null <<EOF
[tcpout]
defaultGroup = default-autolb-group

[tcpout:default-autolb-group]
server = ${SPLUNK_SERVER}:9997
EOF

sudo tee "${UF_HOME}/etc/system/local/inputs.conf" >/dev/null <<'EOF'
[monitor:///var/log/syslog]
disabled = false

[monitor:///var/log/auth.log]
disabled = false
EOF

echo "==> Letting the forwarder user read /var/log (adm group)"
# The UF runs as splunkfwd. On Ubuntu, syslog and auth.log are owned by syslog:adm, mode 640.
sudo usermod -aG adm splunkfwd
sudo chown -R splunkfwd:splunkfwd "${UF_HOME}"

echo "==> Starting the forwarder (also creates the systemd unit)"
sudo "${UF_HOME}/bin/splunk" start --accept-license --answer-yes --no-prompt

echo "==> Verifying"
sudo "${UF_HOME}/bin/splunk" list forward-server -auth "${ADMIN_USER}:${ADMIN_PASS}"
sudo "${UF_HOME}/bin/splunk" list monitor -auth "${ADMIN_USER}:${ADMIN_PASS}" | grep -E "/var/log/(syslog|auth.log)" || true

echo
echo "Look for '${SPLUNK_SERVER}:9997' under 'Active forwards'."
echo "Then search in Splunk:  index=main host=\"$(hostname)\""
