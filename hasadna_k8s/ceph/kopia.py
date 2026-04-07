import socket
import getpass
import subprocess


def maintenance(full=False):
    kopia_user = f'{getpass.getuser()}@{socket.gethostname()}'
    subprocess.check_call([
        'kopia', 'maintenance', 'set', f'--owner={kopia_user}',
    ])
    cmd = [
        'kopia', 'maintenance', 'run'
    ]
    if full:
        cmd.append('--full')
    subprocess.check_call(cmd)
