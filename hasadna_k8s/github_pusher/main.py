import os
import time
import json
import base64
import dataclasses

import jwt
import requests
from benedict import benedict
from dotenv import load_dotenv


load_dotenv()
GITHUB_TOKEN = os.environ.get('GITHUB_TOKEN')
GITHUB_APP_ID = os.environ.get('GITHUB_APP_ID')
GITHUB_APP_INSTALLATION_ID = os.environ.get('GITHUB_APP_INSTALLATION_ID')
GITHUB_APP_PRIVATE_KEY_B64 = os.environ.get('GITHUB_APP_PRIVATE_KEY_B64')
GITHUB_APP_PRIVATE_KEY = base64.b64decode(GITHUB_APP_PRIVATE_KEY_B64).decode() if GITHUB_APP_PRIVATE_KEY_B64 else None
GITHUB_PUSHER_CONFIG_YAML_PATH = os.environ.get('GITHUB_PUSHER_CONFIG_YAML_PATH') or 'hasadna_k8s/github_pusher/config.example.yaml'
GITHUB_PUSHER_DEBUG = os.environ.get('GITHUB_PUSHER_DEBUG') == 'yes'


@dataclasses.dataclass(frozen=True)
class GithubPusherRepoBranchConfig:
    org: str
    name: str
    branch: str


@dataclasses.dataclass(frozen=True)
class GithubPusherFileConfig:
    image_keys: list[str]


@dataclasses.dataclass(frozen=True)
class GithubPusherCopyConfig:
    source: GithubPusherRepoBranchConfig
    target: GithubPusherRepoBranchConfig
    files: dict[str, GithubPusherFileConfig]


def parse_config(config):
    if config['type'] == 'copy':
        return GithubPusherCopyConfig(
            source=GithubPusherRepoBranchConfig(**config['source']),
            target=GithubPusherRepoBranchConfig(**config['target']),
            files={k: GithubPusherFileConfig(**v) for k, v in config['files'].items()}
        )
    else:
        raise Exception(f'Unknown config type: {config["type"]}')


def parse_configs(configs):
    configs = [parse_config(config) for config in configs]
    if GITHUB_PUSHER_DEBUG:
        for config in configs:
            print(config)
    return configs


def get_configs():
    with open(GITHUB_PUSHER_CONFIG_YAML_PATH) as f:
        data = benedict(f.read(), format='yaml', keypath_separator=None)
    return parse_configs(data['configs'])


def process_github_pusher_copy_config_files(pconfig: GithubPusherCopyConfig, files, requests_options, commit_message):
    print(f'Processing {pconfig.source.org}/{pconfig.source.name} {pconfig.source.branch} ({",".join(files)})')
    num_updates = 0
    for file, file_config in {k: v for k, v in pconfig.files.items() if k in files}.items():
        content = benedict(
            f'https://api.github.com/repos/{pconfig.source.org}/{pconfig.source.name}/contents/{file}?ref=refs/heads/{pconfig.source.branch}',
            requests_options=requests_options
        )['content']
        content = benedict(base64.b64decode(content).decode(), format='yaml')
        images = {image_key: content.get(image_key) for image_key in file_config.image_keys if content.get(image_key)}
        if images:
            target_file = benedict(
                f'https://api.github.com/repos/{pconfig.target.org}/{pconfig.target.name}/contents/{file}?ref=refs/heads/{pconfig.target.branch}',
                requests_options=requests_options
            )
            target_content = target_file['content']
            target_content = benedict(base64.b64decode(target_content).decode(), format='yaml')
            target_updates = {image_key: image for image_key, image in images.items() if target_content.get(image_key) != image}
            if target_updates:
                for image_key, image in target_updates.items():
                    num_updates += 1
                    target_content[image_key] = image
                print(f'Updating {file} in {pconfig.target.org}/{pconfig.target.name} {pconfig.target.branch} with {target_updates}')
                res = requests.put(
                    f'https://api.github.com/repos/{pconfig.target.org}/{pconfig.target.name}/contents/{file}',
                    json={
                        'message': commit_message,
                        'content': base64.b64encode(target_content.to_yaml().encode()).decode(),
                        'sha': target_file['sha'],
                        'branch': pconfig.target.branch,
                    },
                    **requests_options,
                )
                if res.status_code != 200:
                    raise Exception(f'Failed to update {file} in {pconfig.target.org}/{pconfig.target.name} {pconfig.target.branch}: {res.status_code} {res.text}')
    if num_updates == 0:
        print('No updates')


def get_github_token():
    if GITHUB_TOKEN:
        if GITHUB_PUSHER_DEBUG:
            print('Using GITHUB_TOKEN')
        return GITHUB_TOKEN
    else:
        if GITHUB_PUSHER_DEBUG:
            print('Using GITHUB_APP_*')
        assert GITHUB_APP_ID and GITHUB_APP_INSTALLATION_ID and GITHUB_APP_PRIVATE_KEY
        now = int(time.time())
        payload = {
            "iat": now,
            "exp": now + 600,
            "iss": GITHUB_APP_ID
        }
        encoded_jwt = jwt.encode(payload, GITHUB_APP_PRIVATE_KEY, algorithm="RS256")
        response = requests.post(
            f"https://api.github.com/app/installations/{GITHUB_APP_INSTALLATION_ID}/access_tokens",
            headers={"Authorization": f"Bearer {encoded_jwt}", "Accept": "application/vnd.github+json"}
        )
        response.raise_for_status()
        return response.json()["token"]


def process(repository_name, repository_organization, ref, files, commit_message):
    requests_options = {'headers': {'Authorization': f'token {get_github_token()}'}}
    configs = get_configs()
    print(f'process {repository_organization}/{repository_name} {ref} ({",".join(files)})')
    if ref.startswith('refs/heads/') and files:
        branch = ref.replace('refs/heads/', '')
        for config in configs:
            if (
                isinstance(config, GithubPusherCopyConfig)
                and repository_organization == config.source.org
                and repository_name == config.source.name
                and branch == config.source.branch
            ):
                process_github_pusher_copy_config_files(config, files, requests_options, commit_message)


def run(event):
    if GITHUB_PUSHER_DEBUG:
        print(json.dumps(event))
    x_github_event = event.get('X-GitHub-Event')
    assert x_github_event == 'push', f'Unexpected X-GitHub-Event: {x_github_event}'
    repository_name = event.get('repository', {}).get('name')
    repository_organization = event.get('repository', {}).get('organization')
    ref = event.get('ref')
    commits = event.get('commits')
    files = set()
    commit_hashes = set()
    for commit in commits:
        commit_hashes.add(commit.get('id'))
        files.update(commit.get('added', []))
        files.update(commit.get('modified', []))
        files.update(commit.get('removed', []))
    commit_message = '\n'.join([
        'hasadna-k8s automated update',
        f'source repo: {repository_organization}/{repository_name}',
        f'source ref: {ref}',
        f'source commits: {commit_hashes}'
    ])
    process(repository_name, repository_organization, ref, files, commit_message)
