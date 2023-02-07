#!/usr/bin/env python3
import json
import subprocess


ALLOWED_IPS="""
212.80.204.81
5.100.254.253
194.36.91.251
212.199.115.150
212.80.204.206
194.36.91.165
5.100.248.220
195.28.181.207
212.115.111.44
212.115.111.199
83.229.74.79
83.229.74.80
194.36.90.155
"""


def main():
    allowed_ips = [ip.strip() for ip in ALLOWED_IPS.split() if ip.strip()]
    node_ip_names = {}
    for node in json.loads(subprocess.check_output(['kubectl', 'get', 'node', '-o', 'json']))['items']:
        node_ip_names[node['metadata']['annotations']['rke.cattle.io/external-ip']] = node['metadata']['name']
    for ip in allowed_ips:
        node_name = node_ip_names.get(ip)
        if node_name:
            subprocess.check_call(['kubectl', 'label', 'node', node_name, 'open-bus-allowed-ip=true', '--overwrite'])


if __name__ == '__main__':
    main()
