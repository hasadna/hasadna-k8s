import os
import json
import click


@click.group()
def main():
    pass


@main.command()
@click.argument('EVENT_JSON')
@click.option('--file', is_flag=True)
@click.option('--env', is_flag=True)
def run(event_json, file, env):
    from . import main
    if file:
        print(f'Reading event from file: {event_json}')
        with open(event_json) as f:
            event_json = f.read()
    elif env:
        print(f'Reading event from env: {event_json}')
        event_json = os.environ[event_json]
    else:
        print('Reading event from argument')
    main.run(json.loads(event_json))
    print("OK")


@main.command()
@click.argument('REPOSITORY_ORGANIZATION')
@click.argument('REPOSITORY_NAME')
@click.argument('REF')
@click.argument('FILES')
@click.argument('COMMIT_CONTEXT')
def process(files, **kwargs):
    from . import main
    kwargs['files'] = [f.strip() for f in files.split(',') if f.strip()]
    main.process(**kwargs)
    print("OK")
