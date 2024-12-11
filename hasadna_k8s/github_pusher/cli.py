import json
import click


@click.group()
def main():
    pass


@main.command()
@click.argument('EVENT_JSON')
def run(event_json):
    from . import main
    main.run(json.loads(event_json))
    print("OK")


@main.command()
@click.argument('REPOSITORY_ORGANIZATION')
@click.argument('REPOSITORY_NAME')
@click.argument('REF')
@click.argument('FILES')
def process(files, **kwargs):
    from . import main
    kwargs['files'] = [f.strip() for f in files.split(',') if f.strip()]
    main.process(**kwargs)
    print("OK")
