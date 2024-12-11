import importlib

import click


@click.group()
def main():
    pass


for submodule in [
    'github_pusher',
]:
    main.add_command(getattr(importlib.import_module(f'.{submodule}.cli', __package__), 'main'), name=submodule.replace('_', '-'))
