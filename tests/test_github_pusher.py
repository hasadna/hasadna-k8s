from collections import defaultdict

from benedict import benedict

from hasadna_k8s.github_pusher import main as github_pusher_main


GITHUB_PUSHER_COPY_CONFIG_KWARGS = dict(
    source=github_pusher_main.GithubPusherRepoBranchConfig(org='kolzchut', name='srm-devops', branch='main'),
    target=github_pusher_main.GithubPusherRepoBranchConfig(org='hasadna', name='srm-devops', branch='main'),
    files={
        "helm/site/values.auto-updated.yaml": github_pusher_main.GithubPusherFileConfig(image_keys=["site.image"]),
        "helm/site/values.auto-updated.production.yaml": github_pusher_main.GithubPusherFileConfig(image_keys=["site.image"]),
        "helm/etl/values.auto-updated.yaml": github_pusher_main.GithubPusherFileConfig(image_keys=['api.image', 'etl.image']),
        "helm/etl/values.auto-updated.production.yaml": github_pusher_main.GithubPusherFileConfig(image_keys=['api.image', 'etl.image']),
        "helm/etl/values.staging-envvars.yaml": github_pusher_main.GithubPusherFileConfig(keys=['etl.env']),
        "helm/etl/values.production-envvars.yaml": github_pusher_main.GithubPusherFileConfig(keys=['etl.env']),
    }
)


def test_run(monkeypatch):
    monkeypatch.setattr('hasadna_k8s.github_pusher.main.GITHUB_PUSHER_DEBUG', False)
    mock_process_call = {}

    def mock_process(*args):
        assert mock_process_call == {}
        mock_process_call['args'] = args

    monkeypatch.setattr('hasadna_k8s.github_pusher.main.process', mock_process)
    github_pusher_main.run({
        'X-GitHub-Event': 'push',
        'repository': {
            'name': 'test-repo',
            'organization': 'test-org'
        },
        'ref': 'refs/heads/main',
        'commits': [
            {
                'id': '1234567890abcdef',
                'added': ['file1.txt'],
                'modified': ['file2.txt'],
                'removed': ['file3.txt']
            }
        ]
    })
    assert mock_process_call == {
        'args': (
            'test-repo',
            'test-org',
            'refs/heads/main',
            {'file1.txt', 'file2.txt', 'file3.txt'},
            'hasadna-k8s automated update\nsource repo: test-org/test-repo\nsource ref: refs/heads/main\nsource commits: {\'1234567890abcdef\'}'
        )
    }


def test_process(monkeypatch):
    monkeypatch.setattr('hasadna_k8s.github_pusher.main.GITHUB_PUSHER_DEBUG', False)
    monkeypatch.setattr('hasadna_k8s.github_pusher.main.get_github_token', lambda: 'test-token')
    github_pusher_copy_config = github_pusher_main.GithubPusherCopyConfig(**GITHUB_PUSHER_COPY_CONFIG_KWARGS)
    monkeypatch.setattr('hasadna_k8s.github_pusher.main.get_configs', lambda: [github_pusher_copy_config])
    mock_process_github_pusher_copy_config_files_call = {}

    def mock_process_github_pusher_copy_config_files(*args):
        assert mock_process_github_pusher_copy_config_files_call == {}
        mock_process_github_pusher_copy_config_files_call['args'] = args

    monkeypatch.setattr('hasadna_k8s.github_pusher.main.process_github_pusher_copy_config_files', mock_process_github_pusher_copy_config_files)

    github_pusher_main.process(
        'srm-devops',
        'kolzchut',
        'refs/heads/main',
        {'file1.txt', 'file2.txt', 'file3.txt'},
        '...'
    )
    assert mock_process_github_pusher_copy_config_files_call == {
        'args': (
            github_pusher_copy_config,
            {'file1.txt', 'file2.txt', 'file3.txt'},
            {'headers': {'Authorization': 'token test-token'}},
            '...'
        )
    }


def test_process_github_pusher_copy_config_files(monkeypatch):
    stats = defaultdict(int)

    def mock_get_github_yaml_file_content(org, name, file, branch, *args):
        assert org == 'kolzchut' and name == 'srm-devops' and branch == 'main'
        stats[f'get_github_yaml_file_content_{file}'] += 1
        if file == 'helm/etl/values.auto-updated.yaml':
            return benedict({
                'api': {'image': 'aaa'},
                'etl': {'image': 'bbb'}
            })
        elif file == 'helm/site/values.auto-updated.production.yaml':
            return benedict({
                'site': {'image': 'ccc'}
            })
        elif file == 'helm/etl/values.production-envvars.yaml':
            return benedict({
                'etl': {
                    'env': [
                        {'name': 'foo', 'value': 'bar'},
                    ]
                }
            })
        else:
            raise Exception(f'Unknown file: {file}')

    def mock_get_github_file(org, name, file, branch, *args):
        assert org == 'hasadna' and name == 'srm-devops' and branch == 'main'
        stats[f'get_github_file_{file}'] += 1
        if file == 'helm/etl/values.auto-updated.yaml':
            content = {
                'api': {'image': 'aaa'},
                'etl': {'image': 'ddddddd'}
            }
        elif file == 'helm/site/values.auto-updated.production.yaml':
            content = {
                'site': {'image': 'ccc'}
            }
        elif file == 'helm/etl/values.production-envvars.yaml':
            content = {
                'etl': {
                    'env': None
                }
            }
        else:
            raise Exception(f'Unknown file: {file}')
        return {
            'content': benedict(content).to_base64(subformat="yaml"),
            'sha': '1234567890abcdef'
        }

    def mock_update_github_file(org, name, file, branch, requests_options, commit_message, content, sha):
        assert org == 'hasadna' and name == 'srm-devops' and branch == 'main'
        assert sha == '1234567890abcdef'
        stats[f'update_github_file_{file}'] += 1
        if file == 'helm/etl/values.auto-updated.yaml':
            assert content == benedict({
                'api': {'image': 'aaa'},
                'etl': {'image': 'bbb'}
            })
        elif file == 'helm/etl/values.production-envvars.yaml':
            assert content == benedict({
                'etl': {
                    'env': [
                        {'name': 'foo', 'value': 'bar'},
                    ]
                }
            })
        else:
            raise Exception(f'Unknown file: {file}')

    monkeypatch.setattr('hasadna_k8s.github_pusher.main.get_github_yaml_file_content', mock_get_github_yaml_file_content)
    monkeypatch.setattr('hasadna_k8s.github_pusher.main.get_github_file', mock_get_github_file)
    monkeypatch.setattr('hasadna_k8s.github_pusher.main.update_github_file', mock_update_github_file)
    github_pusher_main.process_github_pusher_copy_config_files(
        github_pusher_main.GithubPusherCopyConfig(**GITHUB_PUSHER_COPY_CONFIG_KWARGS),
        {
            'helm/etl/values.auto-updated.yaml',
            'helm/site/values.auto-updated.production.yaml',
            'file3.txt',
            'helm/etl/values.production-envvars.yaml',
        },
        {'headers': {'Authorization': 'token test-token'}},
        '...'
    )
    assert dict(stats) == {
        'get_github_yaml_file_content_helm/etl/values.auto-updated.yaml': 1,
        'get_github_yaml_file_content_helm/site/values.auto-updated.production.yaml': 1,
        'get_github_yaml_file_content_helm/etl/values.production-envvars.yaml': 1,
        'get_github_file_helm/etl/values.auto-updated.yaml': 1,
        'get_github_file_helm/site/values.auto-updated.production.yaml': 1,
        'get_github_file_helm/etl/values.production-envvars.yaml': 1,
        'update_github_file_helm/etl/values.auto-updated.yaml': 1,
        'update_github_file_helm/etl/values.production-envvars.yaml': 1,
    }
