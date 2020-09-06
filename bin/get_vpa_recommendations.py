#!/usr/bin/env python3

import subprocess
import json
import sys
from dataflows import Flow, dump_to_path, printer


def get_vpas():
    for item in json.loads(subprocess.check_output(["kubectl", "get", "vpa", "--all-namespaces", "-o", "json"]))["items"]:
        containerRecs = item['status']['recommendation'].get('containerRecommendations')
        if containerRecs:
            targetRef = json.loads(subprocess.check_output(["kubectl", "-n", item['metadata']['namespace'], "get", item['spec']['targetRef']['kind'], item['spec']['targetRef']['name'], '-o', 'json']))
            containers = {}
            for container in targetRef['spec']['template']['spec']['containers']:
                containers[container['name']] = container.get('resources', {})
            for containerRec in containerRecs:
                yield {
                    'namespace': item['metadata']['namespace'],
                    'name': item['metadata']['name'],
                    'container': containerRec['containerName'],
                    'spec': json.dumps(containers[containerRec['containerName']]),
                    'recommendation': json.dumps(containerRec['target']),
                    'errors': ''
                }
        else:
            yield {
                'namespace': item['metadata']['namespace'],
                'name': item['metadata']['name'],
                'container': '',
                'spec': '',
                'recommendation': '',
                'errors': json.dumps(item['status']['conditions'])
            }


Flow(
    get_vpas(),
    printer(num_rows=99999),
    dump_to_path(sys.argv[1])
).process()
