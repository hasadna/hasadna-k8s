#!/usr/bin/env python3
import time, requests, hashlib, os, json, sys, subprocess, traceback
from datetime import datetime
from ruamel import yaml

with open('/etc/differ/config.yaml') as f:
    config = yaml.safe_load(f)

INTERVAL_SECONDS = 60*20  # check all diffs every 20 minutes
DIFF_OBJS = config['diff-objs']
DATA_DIR = os.environ.get('DATA_DIR', '/tmp/differ-data')

while True:
    for obj in DIFF_OBJS:
        date = datetime.now().strftime('%Y-%m-%d-%H%M')
        data_dir = DATA_DIR + '/' + obj['id'] + '/'
        os.makedirs(data_dir + 'history', exist_ok=True)
        os.makedirs(data_dir + 'hashes', exist_ok=True)
        try:
            content = requests.get(obj['url']).content
            hash = hashlib.sha512(content).hexdigest()
            last_hash = None
            fn = data_dir + 'last_update.json'
            if os.path.exists(fn):
                with open(fn) as f:
                    last_hash = json.load(f)['hash']
            if not last_hash or last_hash != hash:
                print(date + ' updated: ' + obj['id'])
                data = {'hash': hash, 'date': date}
                with open(fn, 'w') as f:
                    json.dump(data, f)
                with open(data_dir + 'history/' + date + '.hash', 'w') as f:
                    f.write(hash)
                fn = data_dir + 'hashes/' + hash
                if not os.path.exists(fn):
                    with open(fn, 'wb') as f:
                        f.write(content)
                diff_fn = data_dir + 'last_update.diff'
                if os.path.exists(diff_fn):
                    os.unlink(diff_fn)
                if last_hash:
                    last_fn = data_dir + 'hashes/' + last_hash
                    if os.path.exists(last_fn):
                        subprocess.call('diff %s %s > %s' % (last_fn, fn, diff_fn), shell=True)
        except Exception:
            exc = traceback.format_exc()
            print(exc)
            error_fn = data_dir + 'last_error.json'
            with open(error_fn, 'w') as f:
                json.dump({'exc': exc, 'date': date}, f)
    print('.')
    sys.stdout.flush()
    time.sleep(INTERVAL_SECONDS)
