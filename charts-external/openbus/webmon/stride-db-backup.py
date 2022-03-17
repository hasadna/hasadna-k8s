def webmon():
    import os
    import datetime
    import subprocess

    bucket_name = os.environ['BUCKET_NAME']
    date, time, size, name = subprocess.check_output(['aws', 's3', 'ls', f's3://{bucket_name}/stride_db.sql.gz']).decode().strip().split(' ')
    assert name == 'stride_db.sql.gz'
    size_gb = int(size) / 1024 / 1024 / 1024
    dt = datetime.datetime.strptime('{} {}'.format(date, time), '%Y-%m-%d %H:%M:%S')
    data = {'dt': dt.strftime('%Y-%m-%d %H:%M:%S'), 'size_gb': size_gb}
    if datetime.datetime.now() - datetime.timedelta(days=3) > dt:
        return False, {**data, 'error': 'last update is too old'}
    elif size_gb < 1.5:
        return False, {**data, 'error': 'size is too small'}
    else:
        return True, data
