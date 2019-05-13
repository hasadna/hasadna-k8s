#!/usr/bin/env python2
import sys, yaml, os, subprocess, json


with open('charts-config.yaml') as f:
    values = yaml.load(f)

commit_message = sys.argv[1]


def _process_automatic_update(auto_update_values):
    if auto_update_values['commit-message'] in commit_message:
        print('Matching auto update values: {}'.format(auto_update_values))
        namespace_name = auto_update_values['namespace-name']
        container_name = auto_update_values['container-name']
        if auto_update_values.get('daemonset-name'):
            object_type = 'daemonset'
            object_name = auto_update_values['daemonset-name']
        else:
            object_type = 'deployment'
            object_name = auto_update_values['deployment-name']
        image_prop = auto_update_values.get('image-prop', 'image')
        print('image_prop={}'.format(image_prop))
        image = subprocess.check_output(
            './read_yaml.py values.auto-updated.yaml {} {}'.format(chart_name, image_prop),
            shell=True
        )
        if not image:
            image = subprocess.check_output(
                './read_env_yaml.sh {} {}'.format(chart_name, image_prop), shell=True
            )
        print('image={}'.format(image))
        image = json.loads(image)
        patch_params = '{}/{}'.format(object_type, object_name)
        patch_params += ' "{}={}"'.format(container_name, image)
        print('patching {}'.format(patch_params))
        if '--dry-run' in sys.argv:
            if os.system('kubectl set image -n {} --dry-run -o yaml {}'.format(namespace_name,
                                                                               patch_params)) == 0:
                print('dry run successful for {}'.format(chart_name))
                return True
            else:
                print('failed patch dry run for {}'.format(chart_name))
                return False
        elif os.system('kubectl set image -n {} {}'.format(namespace_name,
                                                           patch_params)) == 0:
            print('successfully patched {}'.format(chart_name))
            return True
        else:
            print('failed to patch {}'.format(chart_name))
            return False
    else:
        return None


num_failures = 0
num_success = 0

if commit_message:
    for chart_config_id, chart_values in values.items():
        chart_name = chart_values.get('chart-name', chart_config_id)
        if os.path.exists('charts-external/{}'.format(chart_name)):
            if chart_values.get('automatic-update'):
                auto_update_values = chart_values['automatic-update']
                res = _process_automatic_update(auto_update_values)
                if res is True:
                    num_success += 1
                elif res is False:
                    num_failures += 1
            elif chart_values.get('automatic-updates'):
                for auto_update_values in chart_values['automatic-updates']:
                    res = _process_automatic_update(auto_update_values)
                    if res is True:
                        num_success += 1
                    elif res is False:
                        num_failures += 1


if num_failures > 0:
    exit(1)
elif num_success > 0:
    exit(0)
else:
    exit(2)
