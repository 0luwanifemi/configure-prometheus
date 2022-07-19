#!/bin/bash

echo "[+]creating prometheus user account"

sudo useradd --no-create-home prometheus
sudo mkdir /etc/prometheus
sudo mkdir /var/lib/prometheus

echo "[+]Downloading prometheus and extracting files"

wget https://github.com/prometheus/prometheus/releases/download/v2.19.0/prometheus-2.19.0.linux-amd64.tar.gz
tar xvfz prometheus-2.19.0.linux-amd64.tar.gz

echo "[+]copying relevant prometheus files"

sudo cp prometheus-2.19.0.linux-amd64/prometheus /usr/local/bin
sudo cp prometheus-2.19.0.linux-amd64/promtool /usr/local/bin/
sudo cp -r prometheus-2.19.0.linux-amd64/consoles /etc/prometheus
sudo cp -r prometheus-2.19.0.linux-amd64/console_libraries /etc/prometheus

sudo cp prometheus-2.19.0.linux-amd64/promtool /usr/local/bin/
rm -rf prometheus-2.19.0.linux-amd64.tar.gz prometheus-2.19.0.linux-amd64

echo "[+]Downloading and unpacking alert manager"


wget https://github.com/prometheus/alertmanager/releases/download/v0.21.0/alertmanager-0.21.0.linux-amd64.tar.gz
tar xvfz alertmanager-0.21.0.linux-amd64.tar.gz

echo "[+]copying relevant alert-manager files"

sudo cp alertmanager-0.21.0.linux-amd64/alertmanager /usr/local/bin
sudo cp alertmanager-0.21.0.linux-amd64/amtool /usr/local/bin/
sudo mkdir /var/lib/alertmanager

rm -rf alertmanager*

echo "[+]configuring prometheus"

sudo touch /etc/prometheus/prometheus.yml

cat <<< '

global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
 - /etc/prometheus/rules.yml

alerting:
  alertmanagers:
  - static_configs:
    - targets:
      - localhost:9093

scrape_configs:

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']	

  - job_name: 'udapeople'
    ec2_sd_configs:
      - region: us-east-1
        access_key: #your_acess_key
        secret_key: #your_secret_key
        port: 9100' | sudo tee -a /etc/prometheus/prometheus.yml

echo "[+]Configure prometheus.service"

sudo touch /etc/systemd/system/prometheus.service

cat <<< '
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target' | sudo tee -a /etc/systemd/system/prometheus.service

echo "[+] Changing prometheus files ownerships"

sudo chown prometheus:prometheus /etc/prometheus
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool
sudo chown -R prometheus:prometheus /etc/prometheus/consoles
sudo chown -R prometheus:prometheus /etc/prometheus/console_libraries
sudo chown -R prometheus:prometheus /var/lib/prometheus

echo "[+] Configuring alert manager"

sudo touch /etc/prometheus/alertmanager.yml

cat <<< '
route:
  group_by: [Alertname]
  receiver: email-me

receivers:
- name: email-me
  email_configs:
  - to: #email_for_alert
    from: #your_email
    smarthost: smtp.gmail.com:587
    auth_username: #your_email
    auth_identity: #your_email
    auth_password: #your_password' | sudo tee -a /etc/prometheus/alertmanager.yml

echo "[+] Configuring alert rules.yml"

sudo touch /etc/prometheus/rules.yml

sudo tee -a /etc/prometheus/rules.yml << END

groups:
  - name: All Instances
    rules:
    - alert: InstanceDown
      expr: up == 0
      for: 1m
    labels:
      severity: 'critical'
    annotations:
      title: 'Instance {{ $labels.instance }} down'
      summary: "Instance  is down"
      description: "{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 1 minute."
END

echo "[+] Configuring alertmanager.service"

sudo touch /etc/systemd/system/alertmanager.service

cat <<< '
[Unit]
Description=Alert Manager
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/alertmanager \
  --config.file=/etc/prometheus/alertmanager.yml \
  --storage.path=/var/lib/alertmanager

Restart=always

[Install]
WantedBy=multi-user.target' | sudo tee /etc/systemd/system/alertmanager.service

echo "[+] change new files ownserhip"

sudo chown -R prometheus:prometheus /etc/prometheus

echo "[+] Downloadong node exporter"
wget https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-amd64.tar.gz

echo "[+]extracting node exporter files"
tar xvfz node_exporter-1.3.1.linux-amd64.tar.gz

echo "[+] starting node exporter service"
./node_exporter-1.3.1.linux-amd64/node_exporter &

echo  "[+] Starting alert-manager"
sudo systemctl daemon-reload
sudo systemctl enable alertmanager
sudo systemctl start alertmanager

echo  "[+] Starting prometheus"

sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl restart prometheus
