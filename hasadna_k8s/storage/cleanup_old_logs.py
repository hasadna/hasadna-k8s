import os
import shutil
import datetime


def delete_old_files(root_path, cutoff_date, dry_run=True):
    for root, dirs, files in os.walk(root_path, topdown=False):
        for name in files:
            file_path = os.path.join(root, name)
            try:
                mod_date = datetime.datetime.fromtimestamp(os.path.getmtime(file_path))
            except FileNotFoundError:
                mod_date = None
            if mod_date is not None and mod_date < cutoff_date:
                if dry_run:
                    print(f'remove: {file_path}')
                else:
                    try:
                        os.remove(file_path)
                    except:
                        print(f'WARNING: could not remove file {file_path}')
        if not os.listdir(root) and root != root_path:
            if dry_run:
                print(f'rmtree: {root}')
            else:
                try:
                    shutil.rmtree(root)
                except:
                    print(f'WARNING: could not remove directory {root}')


def find_log_paths_airflow_logs(root):
    if os.path.basename(root) == 'logs':
        parent = os.path.dirname(root)
        if os.path.exists(f'{parent}/airflow.cfg'):
            return True
    return False


def find_log_paths(root_path, log_path_prefixes):
    for root, dirs, files in os.walk(root_path):
        for log_path_prefix in log_path_prefixes:
            if log_path_prefix == 'airflow:logs':
                if find_log_paths_airflow_logs(root):
                    yield root
            else:
                if root.endswith(log_path_prefix):
                    yield root


def main(path, dry_run=True, log_path_prefixes=None):
    if not log_path_prefixes:
        log_path_prefixes = ['airflow-home/logs', 'ckan-dgp-logs/airflow-logs']  # example paths
    cutoff_date = datetime.datetime.now() - datetime.timedelta(days=30)
    print(f'Cleaning up logs older than {cutoff_date}')
    for logs_path in find_log_paths(path, log_path_prefixes):
        print(f'Cleaning up logs in {logs_path}')
        delete_old_files(logs_path, cutoff_date, dry_run=dry_run)
