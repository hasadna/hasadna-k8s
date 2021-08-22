#!/usr/bin/env python2
import yaml, sys, subprocess, json

values_filename = sys.argv[1]
chart_name = sys.argv[2]
environment_name = sys.argv[3]

sys.stderr.write("pre_deploy_update_charts_config_values (values_filename={}, chart_name={}, environment_name={})\n".format(values_filename, chart_name, environment_name))

with open('charts-config.yaml') as charts_config_f:
    charts_config = yaml.load(charts_config_f)

with open(values_filename) as values_f:
    values = yaml.load(values_f)

environment_charts_config = charts_config.get(environment_name, {})
if environment_charts_config.get('chart-name') == chart_name:
    for automatic_update in environment_charts_config.get('automatic-updates', []):
        if not automatic_update.get('pre-deploy-update-chart-config-value'):
            continue
        image_prop = automatic_update.get('image-prop')
        if not image_prop:
            continue
        image = subprocess.check_output(
            './read_yaml.py values.auto-updated.yaml {} {}'.format(chart_name, image_prop),
            shell=True
        )
        if not image:
            image = subprocess.check_output(
                './read_env_yaml.sh {} {}'.format(chart_name, image_prop), shell=True
            )
        if not image:
            continue
        image = json.loads(image)
        if not image:
            continue
        sys.stderr.write('{}={}\n'.format(image_prop, image))
        values[image_prop] = image

print(yaml.safe_dump(values, default_flow_style=False))
