import os
import json
import traceback

import click


@click.group()
def main():
    pass


@main.command()
@click.argument('namespace')
@click.argument('pvc_name')
def pvc_backup(namespace, pvc_name):
    from .pvc_backup import main
    main(namespace, pvc_name)


@main.command()
@click.option('--full', is_flag=True)
def maintenance(**kwargs):
    from .kopia import maintenance
    maintenance(**kwargs)


@main.command()
@click.option('--with-full-maintenance', is_flag=True)
def pvc_backup_all(with_full_maintenance):
    from .pvc_backup import main_all
    pvc_backup_failed = False
    try:
        main_all()
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
