#!/usr/bin/env python3
import re
import os
import sys
import base64
import urllib3
import subprocess

import requests
from kubernetes import client, config


regex_pattern = re.compile('~([^~]+)~')
regex_format = '~{}~'


urllib3.disable_warnings()
try:
    config.load_incluster_config()
except config.ConfigException:
    try:
        config.load_kube_config()
    except config.ConfigException:
        raise Exception("Could not configure kubernetes python client")
coreV1Api = client.CoreV1Api()


def init(chart_path):
    subprocess.check_call(['helm', 'dependency', 'build'], cwd=chart_path)


def parse_matches(matches):
    parsed_matches = {}
    for match in matches:
        if match.startswith('vault:'):
            match_parts = match.split(':')
            if len(match_parts) > 2:
                _, vault_path, *vault_key = match.split(':')
                vault_key = ':'.join(vault_key)
                if len(vault_path) and len(vault_key):
                    parsed_matches[match] = {
                        'type': 'vault',
                        'path': vault_path,
                        'key': vault_key
                    }
        elif match.startswith('iac:'):
            match_parts = match.split(':')
            if len(match_parts) > 1:
                _, *iac_key = match.split(':')
                iac_key = ':'.join(iac_key)
                if len(iac_key):
                    parsed_matches[match] = {
                        'type': 'iac',
                        'key': iac_key
                    }
    return parsed_matches


def get_vault_path_data(vault_addr, vault_token, path):
    path = os.path.join('kv', 'data', path)
    return requests.get(
        os.path.join(vault_addr, 'v1', path),
        headers={'X-Vault-Token': vault_token}
    ).json()['data']['data']


def get_iac_data():
    configmap = coreV1Api.read_namespaced_config_map('tf-outputs', 'argocd')
    return configmap.data


def get_vault_creds():
    secret = coreV1Api.read_namespaced_secret('argocd-vault-plugin-credentials', 'argocd')
    data = {k: base64.b64decode(v).decode() for k, v in secret.data.items()}
    role_id = data['AVP_ROLE_ID']
    secret_id = data['AVP_SECRET_ID']
    vault_addr = data['VAULT_ADDR']
    vault_token = requests.post(
        f'{vault_addr}/v1/auth/approle/login',
        json={'role_id': role_id, 'secret_id': secret_id}
    ).json()['auth']['client_token']
    return vault_addr, vault_token


def get_match_values(parsed_matches):
    vault_addr, vault_token = get_vault_creds()
    match_values = {}
    iac_data = None
    vault_paths_data = {}
    for match, parsed_match in parsed_matches.items():
        if parsed_match['type'] == 'iac':
            if iac_data is None:
                iac_data = get_iac_data()
            match_values[match] = iac_data.get(parsed_match['key'], '')
        elif parsed_match['type'] == 'vault':
            if parsed_match['path'] not in vault_paths_data:
                vault_paths_data[parsed_match['path']] = get_vault_path_data(vault_addr, vault_token, parsed_match['path'])
            match_values[match] = vault_paths_data[parsed_match['path']].get(parsed_match['key'], '')
    return match_values


def generate(chart_path, argocd_app_name, *helm_args):
    yamls = subprocess.check_output(
        ['helm', 'template', argocd_app_name, *helm_args, '.'],
        cwd=chart_path
    ).decode()
    parsed_matches = parse_matches(set(re.findall(regex_pattern, yamls)))
    match_values = get_match_values(parsed_matches)
    for match, value in match_values.items():
        yamls = yamls.replace(regex_format.format(match), value)
    print(yamls)


def main(operation, *args):
    if operation == 'init':
        init(*args)
    elif operation == 'generate':
        generate(*args)


if __name__ == "__main__":
    main(*sys.argv[1:])
