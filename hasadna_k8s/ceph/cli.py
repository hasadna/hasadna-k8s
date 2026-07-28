import os
import json
import traceback
import subprocess

import click


@click.group()
def main():
    pass


@main.command()
@click.argument('namespace')
@click.argument('pvc_name')
@click.option('--with-weekly', is_flag=True)
def pvc_backup(**kwargs):
    from .pvc_backup import main
    main(**kwargs)


@main.command()
@click.option('--full', is_flag=True)
def maintenance(**kwargs):
    from .kopia import maintenance
    maintenance(**kwargs)


@main.command()
@click.option('--with-full-maintenance', is_flag=True)
@click.option('--with-weekly', is_flag=True)
@click.option('--with-weekly-on-saturday', is_flag=True)
@click.option('--persistent-state-dir')
def pvc_backup_all(with_full_maintenance, **kwargs):
    from .pvc_backup import main_all, CEPH_BACKUPS_HEARTBEAT_URL
    pvc_backup_failed = False
    try:
        main_all(**kwargs)
    except Exception as e:
        if with_full_maintenance:
            traceback.print_exc()
            pvc_backup_failed = True
        else:
            raise
    if with_full_maintenance:
        from .kopia import maintenance
        maintenance(full=True)
    assert not pvc_backup_failed
    persistent_state_dir = kwargs.get('persistent_state_dir')
    if persistent_state_dir:
        if not os.path.exists(os.path.join(persistent_state_dir, 'last_weekly_backup_log.txt.timestamp')):
            raise Exception("no last weekly backup log timestamp found")
        with open(os.path.join(persistent_state_dir, 'last_weekly_backup_log.txt.timestamp')) as f:
            last_weekly_backup_log_timestamp = datetime.datetime.fromisoformat(f.read().strip())
            days_since_last_weekly_backup = (datetime.datetime.now() - last_weekly_backup_log_timestamp).days
        if days_since_last_weekly_backup > 8:
            raise Exception(f"last weekly backup log timestamp is too old: {days_since_last_weekly_backup} days ago")
    if CEPH_BACKUPS_HEARTBEAT_URL:
        print(f'Sending heartbeat to {CEPH_BACKUPS_HEARTBEAT_URL}...')
        subprocess.check_call(['curl', CEPH_BACKUPS_HEARTBEAT_URL])
    else:
        raise Exception('CEPH_BACKUPS_HEARTBEAT_URL is not set, cannot send heartbeat.')
