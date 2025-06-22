import os
import tempfile
import subprocess
from benedict import benedict


def update_yaml(file_path, updates):
    assert os.path.exists(file_path)
    data = benedict.from_yaml(file_path)
    changed = False
    for update in [u.strip() for u in updates.split(',') if u.strip() and '=' in u]:
        key, value = update.split('=', 1)
        if data.get(key) != value:
            data[key] = value
            changed = True
            print(f'Updated {key} to {value} in {file_path}')
    if changed:
        data.to_yaml(filepath=file_path)
    return changed


def main(app, repo, deploy_key_env_var, values_file, apps_dir, updates, main_branch):
    with tempfile.TemporaryDirectory() as tmpdir:
        with open(os.path.join(tmpdir, 'deploykey'), 'w') as f:
            f.write(os.environ[deploy_key_env_var])
        os.chmod(os.path.join(tmpdir, 'deploykey'), 0o600)
        git_env = {
            **os.environ,
            'GIT_SSH_COMMAND': f"ssh -i {os.path.join(tmpdir, 'deploykey')} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
        }
        subprocess.check_call(['git', 'clone', '--depth=1', f'git@github.com:{repo}.git', os.path.join(tmpdir, 'repo')], env=git_env)
        if update_yaml(os.path.join(tmpdir, 'repo', apps_dir, app, values_file), updates):
            source = os.getenv('GITHUB_REPOSITORY') or 'unknown'
            source_name = source.replace('/', '-')
            subprocess.check_call(['git', 'config', '--global', 'user.name', source_name])
            subprocess.check_call(['git', 'config', '--global', 'user.email', f'{source_name}@localhost'])
            subprocess.check_call(['git', 'add', os.path.join(apps_dir, app, values_file)], cwd=os.path.join(tmpdir, 'repo'))
            subprocess.check_call(['git', 'commit', '-m', f'automatic update of {app} from {source}'], cwd=os.path.join(tmpdir, 'repo'))
            subprocess.check_call(['git', 'push', 'origin', main_branch], cwd=os.path.join(tmpdir, 'repo'), env=git_env)
            print(f'Updated {app} in {repo} and pushed to {main_branch}')
        else:
            print(f'No changes made to {app} in {repo}, skipping push')
