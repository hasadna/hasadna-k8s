import json
import datetime
import subprocess


def main(namespace, pvc_name):
    print(f'Creating RBD backup for PVC {pvc_name} in namespace {namespace}...')
    pvc = json.loads(subprocess.check_output([
        'kubectl', '-n', namespace, 'get', 'pvc', pvc_name, '-o', 'json'
    ]))
    volume_name = pvc['spec']['volumeName']
    print(f'Volume name: {volume_name}')
    pv = json.loads(subprocess.check_output(['kubectl', 'get', 'pv', volume_name, '-o', 'json']))
    pool = pv['spec']['csi']['volumeAttributes']['pool']
    image_name = pv['spec']['csi']['volumeAttributes']['imageName']
    print(f'Pool: {pool}, Image name: {image_name}')
    backup_datestr = datetime.datetime.now().strftime('%Y%m%d%H%M%S')
    backup_name = f'hasadna-k8s-rbd-backup-{backup_datestr}'
    print(f'Backup name: {backup_name}')
    subprocess.check_call(['rbd', 'snap', 'create', f'{pool}/{image_name}@{backup_name}'])
    subprocess.check_call(['rbd', 'snap', 'protect', f'{pool}/{image_name}@{backup_name}'])
    device = subprocess.check_output(['rbd-nbd', 'map', f'{pool}/{image_name}@{backup_name}']).decode().strip()
    print(f'Device: {device}')
    subprocess.check_call(['mkdir', '-p', f'/tmp{device}'])
    subprocess.check_call(['mount', '-t', 'ext4', '-o', 'ro,noload', device, f'/tmp{device}'])
    kopia_snapshot_source = f'ceph@{namespace}:{pvc_name}'
    print(f'Creating Kopia snapshot with source {kopia_snapshot_source}...')
    subprocess.check_call(['kopia', 'snapshot', 'create', f'/tmp{device}', '--override-source', kopia_snapshot_source])
    print("Kopia snapshot created successfully.")
    print('Unmounting and cleaning up...')
    subprocess.check_call(['umount', f'/tmp{device}'])
    subprocess.check_call(['rbd-nbd', 'unmap', device])
    subprocess.check_call(['rbd', 'snap', 'unprotect', f'{pool}/{image_name}@{backup_name}'])
    subprocess.check_call(['rbd', 'snap', 'rm', f'{pool}/{image_name}@{backup_name}'])
    print('Backup completed successfully.')
