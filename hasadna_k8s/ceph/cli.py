import os
import json
import click


@click.group()
def main():
    pass


@main.command()
@click.argument('namespace')
@click.argument('pvc_name')
def rbd_backup(namespace, pvc_name):
    from .rbd_backup import main
    main(namespace, pvc_name)
