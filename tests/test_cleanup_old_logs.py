import os
from glob import glob
from hasadna_k8s.storage.cleanup_old_logs import find_log_paths, main as cleanup_old_logs


def test_find_log_paths():
    base = os.path.dirname(__file__)
    assert list(find_log_paths(os.path.dirname(__file__), ["airflow-home/logs", "airflow:logs"])) == [
        f'{base}/old_logs_paths/foobar/logs',
        f'{base}/old_logs_paths/airflow-home/logs',
    ]


def test_cleanup_old_logs():
    base = os.path.dirname(__file__)
    for f in glob(f'{base}/old_logs_paths/**/.gitkeep', recursive=True):
        os.utime(f, None)
    for fn in [
        f'{base}/old_logs_paths/airflow-home/logs/old_log.log',
        f'{base}/old_logs_paths/foobar/logs/old_log.log',
        f'{base}/old_logs_paths/somethingelse/old_log.log',
    ]:
        with open(fn, 'w') as f:
            f.write('test log content')
        # Set modification time to 40 days ago
        old_time = os.path.getmtime(fn) - (40 * 24 * 60 * 60)
        os.utime(fn, (old_time, old_time))
    cleanup_old_logs(base, dry_run=False, log_path_prefixes=["airflow-home/logs", "airflow:logs"])
    for fn in [
        f'{base}/old_logs_paths/airflow-home/logs/old_log.log',
        f'{base}/old_logs_paths/foobar/logs/old_log.log',
    ]:
        assert not os.path.exists(fn)
    assert os.path.exists(f'{base}/old_logs_paths/somethingelse/old_log.log')
    os.remove(f'{base}/old_logs_paths/somethingelse/old_log.log')
