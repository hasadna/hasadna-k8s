import os
import json
import subprocess

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


@main.command()
@click.argument('SEARCH_TERM', required=False)
def find_volumes(search_term):
    for volume in json.loads(subprocess.check_output([
        "kubectl", "get", "pv", "-o", "json"
    ]))['items']:
        if not search_term or search_term in json.dumps(volume):
            if 'local' in volume['spec']:
                spec = f'local({volume["spec"]["local"]['path']})'
            elif 'csi' in volume['spec']:
                spec = ','.join([
                    volume['spec']['csi']['driver'],
                    volume['spec']['csi']['volumeHandle'],
                ])
                spec = f'csi({spec})'
            else:
                spec = 'unknown'
            print(
                volume['metadata']['name'],
                spec,
                f"{volume['spec']['claimRef']['namespace']}/{volume['spec']['claimRef']['name']}",
            )


