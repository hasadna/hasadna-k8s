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
def pvc_backup_all(with_full_maintenance, **kwargs):
    from .pvc_backup import main_all
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
