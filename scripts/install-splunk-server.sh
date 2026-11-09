#!/usr/bin/env bash
# Install Splunk Enterprise on Ubuntu 24.04 and prepare it to receive forwarder data.
#
# Usage (on the Splunk Server, as the ubuntu user):
#   chmod +x install-splunk-server.sh
#   ./install-splunk-server.sh
#
# Optional overrides:
#   SPLUNK_VERSION=10.6.1.1 SPLUNK_BUILD=b2ae2962645c ./install-splunk-server.sh
#
# If the download URL returns 404, copy the current wget link for the Linux .deb
# from splunk.com (Splunk Enterprise > Linux > .deb > Copy wget link) and set SPLUNK_URL.

set -euo pipefail

SPLUNK_VERSION="${SPLUNK_VERSION:-10.6.1.1}"
SPLUNK_BUILD="${SPLUNK_BUILD:-b2ae2962645c}"
DEB="splunk-${SPLUNK_VERSION}-${SPLUNK_BUILD}-linux-amd64.deb"
SPLUNK_URL="${SPLUNK_URL:-https://download.splunk.com/products/splunk/releases/${SPLUNK_VERSION}/linux/${DEB}}"
SPLUNK_HOME=/opt/splunk
ADMIN_USER="${ADMIN_USER:-admin}"
RECEIVE_PORT=9997

read -r -s -p "Choose a Splunk admin password (8+ characters): " ADMIN_PASS; echo
if [ "${#ADMIN_PASS}" -lt 8 ]; then echo "Password must be at least 8 characters." >&2; exit 1; fi

echo "==> Updating packages"
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

echo "==> Downloading Splunk Enterprise ${SPLUNK_VERSION}"
wget -q --show-progress -O "/tmp/${DEB}" "${SPLUNK_URL}"

echo "==> Installing"
sudo dpkg -i "/tmp/${DEB}"
rm -f "/tmp/${DEB}"

echo "==> Seeding the admin account (removed by Splunk after first start)"
sudo tee "${SPLUNK_HOME}/etc/system/local/user-seed.conf" >/dev/null <<EOF
[user_info]
USERNAME = ${ADMIN_USER}
PASSWORD = ${ADMIN_PASS}
EOF
sudo chown -R splunk:splunk "${SPLUNK_HOME}"

echo "==> First start (accept license)"
sudo -u splunk "${SPLUNK_HOME}/bin/splunk" start --accept-license --answer-yes --no-prompt
sudo -u splunk "${SPLUNK_HOME}/bin/splunk" stop

echo "==> Enabling start on boot (systemd unit Splunkd)"
sudo "${SPLUNK_HOME}/bin/splunk" enable boot-start -user splunk -systemd-managed 1
sudo systemctl start Splunkd

echo "==> Receiving forwarder data on TCP ${RECEIVE_PORT}"
sudo -u splunk "${SPLUNK_HOME}/bin/splunk" enable listen "${RECEIVE_PORT}" -auth "${ADMIN_USER}:${ADMIN_PASS}"

echo "==> Creating the wineventlog index for Windows event logs"
sudo -u splunk "${SPLUNK_HOME}/bin/splunk" add index wineventlog -auth "${ADMIN_USER}:${ADMIN_PASS}" || true

PRIVATE_IP=$(hostname -I | awk '{print $1}')
echo
echo "Done."
echo "  Splunk Web:        http://<this instance's public IP>:8000"
echo "  Forwarders send to: ${PRIVATE_IP}:${RECEIVE_PORT}"
sudo systemctl --no-pager --lines=0 status Splunkd
