#!/usr/bin/env python3

import subprocess
import json
import sys
from dataflows import Flow, dump_to_path, printer


def parse_memory(memory):
    if memory:
        try:
            memory = int(memory)
        except Exception:
            if memory.endswith('k'):
                memory = str(round(int(memory.replace('k', '')) / 1024)) + "Mi"
            elif memory.endswith('Gi'):
                memory = str(round(int(memory.replace('Gi', '')) * 1024)) + "Mi"
            elif not memory.endswith('Mi'):
                raise Exception("unhandled memory: {}".format(memory))
        else:
            memory = str(round(memory / 1024 / 1024)) + "Mi"
    return memory


def parse_cpu(cpu):
    if cpu:
        try:
            cpu = int(cpu)
        except Exception:
            if not cpu.endswith('m'):
                raise Exception("unhandled cpu: {}".format(cpu))
        else:
            cpu = str(round(cpu * 1000)) + "m"
    return cpu

def parse_resources_part(part):
    return {'memory': parse_memory(part.get('memory') or ''), 'cpu': parse_cpu(part.get('cpu') or '')}


def parse_container_resources(resources):
    return {'requests': parse_resources_part(resources.get('requests', {})),
            'limits': parse_resources_part(resources.get('limits', {}))}


def parse_container_rec(containerRec):
    return {
        'lowerBound': {
            'cpu': parse_cpu(containerRec['lowerBound']['cpu']),
            'memory': parse_memory(containerRec['lowerBound']['memory']),
        },
        'target': {
            'cpu': parse_cpu(containerRec['target']['cpu']),
            'memory': parse_memory(containerRec['target']['memory']),
        },
        'uncappedTarget': {
            'cpu': parse_cpu(containerRec['target']['cpu']),
            'memory': parse_memory(containerRec['target']['memory']),
        },
        'upperBound': {
            'cpu': parse_cpu(containerRec['upperBound']['cpu']),
            'memory': parse_memory(containerRec['upperBound']['memory']),
        }
    }

def get_vpas():
    for item in json.loads(subprocess.check_output(["kubectl", "get", "vpa", "--all-namespaces", "-o", "json"]))["items"]:
        containerRecs = item['status']['recommendation'].get('containerRecommendations')
        if containerRecs:
            targetRef = json.loads(subprocess.check_output(["kubectl", "-n", item['metadata']['namespace'], "get", item['spec']['targetRef']['kind'], item['spec']['targetRef']['name'], '-o', 'json']))
            containers = {}
            for container in targetRef['spec']['template']['spec']['containers']:
                containers[container['name']] = parse_container_resources(container.get('resources', {}))
            for containerRec in containerRecs:
                rec = parse_container_rec(containerRec)
                yield {
                    'namespace': item['metadata']['namespace'],
                    'name': item['metadata']['name'],
                    'container': containerRec['containerName'],
                    'requestsMemory': containers[containerRec['containerName']]['requests']['memory'],
                    # 'lowerBoundMemory': rec['lowerBound']['memory'],
                    'targetMemory': rec['target']['memory'],
                    # 'uncappedTargetMemory': rec['uncappedTarget']['memory'],
                    'upperBoundMemory': rec['upperBound']['memory'],
                    'limitsMemory': containers[containerRec['containerName']]['limits']['memory'],
                    'requestsCpu': containers[containerRec['containerName']]['requests']['cpu'],
                    # 'lowerBoundCpu': rec['lowerBound']['cpu'],
                    'targetCpu': rec['target']['cpu'],
                    # 'uncappedTargetCpu': rec['uncappedTarget']['cpu'],
                    'upperBoundCpu': rec['upperBound']['cpu'],
                    'limitsCpu': containers[containerRec['containerName']]['limits']['cpu'],
                    'errors': ''
                }
        else:
            yield {
                'namespace': item['metadata']['namespace'],
                'name': item['metadata']['name'],
                'requestsMemory': '',
                # 'lowerBoundMemory': '',
                'targetMemory': '',
                # 'uncappedTargetMemory': '',
                'upperBoundMemory': '',
                'limitsMemory': '',
                'requestsCpu': '',
                # 'lowerBoundCpu': '',
                'targetCpu': '',
                # 'uncappedTargetCpu': '',
                'upperBoundCpu': '',
                'limitsCpu': '',
                'errors': json.dumps(item['status']['conditions'])
            }


Flow(
    get_vpas(),
    printer(num_rows=99999),
    dump_to_path(sys.argv[1])
).process()
