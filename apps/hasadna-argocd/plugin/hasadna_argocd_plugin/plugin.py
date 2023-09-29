import os
import sys
import json
import base64
import subprocess

import requests

from uumpa_argocd_plugin.plugins.vault import vault_init


def process_generator(generator, data):
    yield from []


def get_iac_data():
    p = subprocess.run(['kubectl', '-n', 'argocd', 'get', 'configmap', 'tf-outputs', '-o', 'jsonpath={.data}'], text=True, capture_output=True)
    if p.returncode == 0:
        return json.loads(p.stdout)
    else:
        print('WARNING: Failed to get iac data, all values will be empty, you need kubectl connected to the cluster', file=sys.stderr)
        return {}


def post_process_output_iac(source):
    result = []
    iac_data = None
    for i, part in enumerate(source.split('~iac:')):
        if i == 0:
            result.append(part)
        else:
            iac_key, *remainder = part.split('~')
            remainder = '~'.join(remainder)
            if iac_data is None:
                iac_data = get_iac_data()
            value = iac_data.get(iac_key, '')
            result.append(f'{value}{remainder}')
    return ''.join(result)


def get_vault_path_data(token, addr, data_path_prefix, vault_path):
    if not token or not addr or not data_path_prefix:
        return {}
    else:
        url = os.path.join(addr, data_path_prefix, vault_path)
        res = requests.get(url, headers={'X-Vault-Token': token})
        res.raise_for_status()
        return res.json()['data']['data']


def post_process_output_vault(source):
    data_path_prefix = 'v1/kv/data'
    token, addr = None, None
    if not os.environ.get('VAULT_ADDR'):
        print('WARNING: Missing VAULT_ADDR env var, all values will be empty', file=sys.stderr)
    elif os.environ.get('VAULT_TOKEN'):
        token = os.environ['VAULT_TOKEN']
        addr = os.environ['VAULT_ADDR']
    elif not os.environ.get('VAULT_ROLE_ID') or not os.environ.get('VAULT_SECRET_ID'):
        print('WARNING: Failed to login to Vault, all values will be empty, you need set required Vault env vars', file=sys.stderr)
    else:
        token, addr, _ = vault_init()
    result = []
    vault_paths_data = {}
    for i, part in enumerate(source.split('~vault:')):
        if i == 0:
            result.append(part)
        else:
            vault_path_key, *remainder = part.split('~')
            remainder = '~'.join(remainder)
            vault_path, vault_key = vault_path_key.split(':')
            if vault_path not in vault_paths_data:
                vault_paths_data[vault_path] = get_vault_path_data(token, addr, data_path_prefix, vault_path)
            value = vault_paths_data[vault_path].get(vault_key, '')
            value = base64.b64encode(value.encode()).decode()
            result.append(f'{value}{remainder}')
    return ''.join(result)


def post_process_output(output, data):
    output = post_process_output_iac(output)
    output = post_process_output_vault(output)
    return output
