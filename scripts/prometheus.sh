#!/usr/bin/env bash
set -e

DISTRO_NAME=""
DISTRO_VERSION=""
OS_RELEASE="/etc/os-release"
TOKEN=$(echo -n $(date) | sha256sum | cut -d ' ' -f1)

if [[ -f $OS_RELEASE ]]; then
  source $OS_RELEASE
  if [[ $ID == "rocky" ]]; then
    DISTRO_NAME="rhel"
  elif [[ $ID == "centos" ]]; then
    DISTRO_NAME="rhel"
  elif [[ $ID == "almalinux" ]]; then
    DISTRO_NAME="rhel"
  elif [[ $ID == "debian" ]]; then
    DISTRO_NAME="debian"
  fi
    DISTRO_VERSION=$(echo "$VERSION_ID" | awk -F. '{print $1}')
fi

# Check if release file is recognized
if [[ -z $DISTRO_NAME ]]; then
  echo -e "\nDistro is not recognized. Supported releases: Rocky Linux 8-9, CentOS 8-9, AlmaLinux 8-9, Debian 12.\n"
  exit 1
fi

if [[ $DISTRO_NAME == "debian" ]]; then
  # Check if prometheus is installed
  if ! dpkg -l | grep -q prometheus; then
    echo -e "\nPackage prometheus is not installed. Please install and configure prometheus first!\n"
    exit 1
  fi
elif [[ $DISTRO_NAME == "rhel" ]]; then
  # Check if prometheus is installed
  if ! dnf list installed prometheus > /dev/null 2>&1; then
    echo -e "\nPackage prometheus is not installed. Please install and configure prometheus first!\n"
    exit 1
  fi
fi

# Install prometheus
echo -e "\nInstalling and configuring prometheus..."

if [[ $DISTRO_NAME == "debian" ]]; then
  apt-get update
  apt-get install -y prometheus golang-github-prometheus-client-golang-dev prometheus-node-exporter policycoreutils
elif [[ $DISTRO_NAME == "rhel" ]]; then
  dnf install -y epel-release
  dnf install -y golang-github-prometheus golang-github-prometheus-node-exporter
fi

wget -O /tmp/prometheus-libvirt-exporter.tar.gz https://cloud-apps.webvirt.cloud/prometheus-libvirt-exporter-$DISTRO_NAME$DISTRO_VERSION-amd64.tar.gz
tar -xvf /tmp/prometheus-libvirt-exporter.tar.gz -C /tmp
cp /tmp/prometheus-libvirt-exporter/prometheus-libvirt-exporter /usr/local/bin/
restorecon -v /usr/local/bin/prometheus-libvirt-exporter
cp /tmp/prometheus-libvirt-exporter/prometheus-libvirt-exporter.service /etc/systemd/system/prometheus-libvirt-exporter.service
cat << EOF >> /etc/prometheus/prometheus.yml

  - job_name: libvirt
    # Libvirt exporter
    static_configs:
      - targets: ['localhost:9177']
EOF
systemctl daemon-reload
systemctl enable --now prometheus-libvirt-exporter
systemctl enable --now prometheus-node-exporter
systemctl enable --now prometheus
echo -e "Installing and configuring prometheus... - Done!\n"

# Clean up
rm -rf /tmp/prometheus-libvirt-exporter*

exit 0
