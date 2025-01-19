import importlib

import click

from .version import version


@click.group()
@click.version_option(message=version)
def main():
    pass


for submodule in [
    'github_pusher',
    'storage',
]:
    main.add_command(getattr(importlib.import_module(f'.{submodule}.cli', __package__), 'main'), name=submodule.replace('_', '-'))
