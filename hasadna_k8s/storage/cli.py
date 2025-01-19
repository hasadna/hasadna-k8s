import os
import json
import click


@click.group()
def main():
    pass


@main.command()
@click.argument('PATH')
@click.argument('LOG_PATH_PREFIXES', nargs=-1)
@click.option('--no-dry-run', is_flag=True)
def cleanup_old_logs(path, log_path_prefixes, no_dry_run):
        from .cleanup_old_logs import main
        main(path, dry_run=not no_dry_run, log_path_prefixes=log_path_prefixes)
        print("OK")
