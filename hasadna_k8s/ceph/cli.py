import os
import json
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
def pvc_backup_all():
    from .pvc_backup import main_all
    main_all()
