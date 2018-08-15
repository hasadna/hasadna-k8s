#!/usr/bin/env python2
import sys, yaml, os, subprocess, json

with open('charts-config.yaml') as f:
    values = yaml.load(f)

commit_message = sys.argv[1]

# no patches detected
exit_code = 2

if commit_message:
    for chart_name, chart_values in values.items():
        chart_name = chart_values.get('chart-name', chart_name)
        if os.path.exists('charts-external/{}'.format(chart_name)):
            if chart_values.get('automatic-update'):
                auto_update_values = chart_values['automatic-update']
                if auto_update_values['commit-message'] in commit_message:
                    namespace_name = auto_update_values['namespace-name']
                    container_name = auto_update_values['container-name']
                    if auto_update_values.get('daemonset-name'):
                        object_type = 'daemonset'
                        object_name = auto_update_values['daemonset-name']
                    else:
                        object_type = 'deployment'
                        object_name = auto_update_values['deployment-name']
                    image_prop = auto_update_values.get('image-prop', 'image')
                    image = subprocess.check_output('./read_env_yaml.sh {} {}'.format(chart_name, image_prop), shell=True)
                    image = json.loads(image)
                    patch_params = '{}/{}'.format(object_type, object_name)
                    patch_params += ' "{}={}"'.format(container_name, image)
                    print('patching {}'.format(patch_params))
                    if '--dry-run' in sys.argv:
                        if os.system('kubectl set image -n {} --dry-run -o yaml {}'.format(namespace_name,
                                                                                           patch_params)) == 0:
                            print('dry run successful for {}'.format(chart_name))
                            exit_code = 0
                        else:
                            print('failed patch dry run for {}'.format(chart_name))
                            exit_code = 1
                    elif os.system('kubectl set image -n {} {}'.format(namespace_name,
                                                                       patch_params)) == 0:
                        print('successfully patched {}'.format(chart_name))
                        exit_code = 0
                    else:
                        print('failed to patch {}'.format(chart_name))
                        exit_code = 1

exit(exit_code)
