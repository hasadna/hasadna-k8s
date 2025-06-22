import os
import json
import click


@click.group()
def main():
    pass


@main.command()
@click.option('--app', required=True)
@click.option('--repo', default='hasadna/hasadna-k8s')
@click.option('--main-branch', default='master')
@click.option('--deploy-key-env-var', default='HASADNA_K8S_DEPLOY_KEY')
@click.option('--values-file', default='values-hasadna-auto-updated.yaml')
@click.option('--apps-dir', default='apps')
@click.argument('updates')
def deploy(*args, **kwargs):
    from .deploy import main
    main(*args, **kwargs)


@main.command()
@click.argument('yaml_file')
@click.argument('updates')
def update_yaml(yaml_file, updates):
    from .deploy import update_yaml
    print(update_yaml(yaml_file, updates))
