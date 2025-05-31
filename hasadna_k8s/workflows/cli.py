import json

import click


@click.group()
def main():
    pass


@main.command()
def global_exit_hook():
    from .global_exit_hook import main
    main()
    print("OK")


@main.command()
@click.argument('name')
@click.argument('creation_timestamp')
@click.argument('namespace')
@click.argument('cron_workflow')
def get_last_cron_workflow_status(name, creation_timestamp, namespace, cron_workflow):
    from .global_exit_hook import get_last_cron_workflow_status
    status = get_last_cron_workflow_status(name, creation_timestamp, namespace, cron_workflow)
    print(json.dumps(status, indent=2))
