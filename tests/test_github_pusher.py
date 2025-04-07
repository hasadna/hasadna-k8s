from hasadna_k8s.github_pusher import main as github_pusher_main


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
    github_pusher_copy_config = github_pusher_main.GithubPusherCopyConfig(
        source=github_pusher_main.GithubPusherRepoBranchConfig(org='kolzchut', name='srm-devops', branch='main'),
        target=github_pusher_main.GithubPusherRepoBranchConfig(org='hasadna', name='srm-devops', branch='main'),
        files={
            "helm/site/values.auto-updated.yaml": github_pusher_main.GithubPusherFileConfig(image_keys=["site.image"]),
            "helm/site/values.auto-updated.production.yaml": github_pusher_main.GithubPusherFileConfig(image_keys=["site.image"]),
            "helm/etl/values.auto-updated.yaml": github_pusher_main.GithubPusherFileConfig(image_keys=['api.image', 'etl.image']),
            "helm/etl/values.auto-updated.production.yaml": github_pusher_main.GithubPusherFileConfig(image_keys=['api.image', 'etl.image']),
        }
    )
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
            {
                'headers': {'Authorization': 'token test-token'}
            },
            '...'
        )
    }
