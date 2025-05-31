import os
import json
import base64

import requests


SLACK_WEBHOOK_URL_B64 = os.environ.get('SLACK_WEBHOOK_URL_B64')
ARGO_WORKFLOWS_TOKEN = os.environ.get('ARGO_WORKFLOWS_TOKEN')
ARGO_WORKFLOWS_URL = os.environ.get('ARGO_WORKFLOWS_URL')

STATUS = os.environ.get('STATUS')
FAILURES = os.environ.get('FAILURES')
NAME = os.environ.get('NAME')
NAMESPACE = os.environ.get('NAMESPACE')
DURATION = os.environ.get('DURATION')
CREATION_TIMESTAMP = os.environ.get('CREATION_TIMESTAMP')
LABELS = os.environ.get('LABELS')
ANNOTATIONS = os.environ.get('ANNOTATIONS')
PARAMETERS = os.environ.get('PARAMETERS')


def send_slack_notification():
    assert SLACK_WEBHOOK_URL_B64, "SLACK_WEBHOOK_URL_B64 environment variable is not set"
    url = base64.b64decode(SLACK_WEBHOOK_URL_B64).decode('utf-8')
    post_data = {
        "channel": "argo-workflows-notifications",
        "username": "argo",
        "text": f"Workflow {NAME} in namespace {NAMESPACE} has completed with status {STATUS}.",
        "attachments": [
            {
                "fields": [
                    {"title": "Failures", "value": FAILURES, "short": True},
                    {"title": "Duration", "value": DURATION, "short": True},
                    {"title": "Creation Timestamp", "value": CREATION_TIMESTAMP, "short": True},
                    {"title": "Labels", "value": LABELS, "short": False},
                    {"title": "Annotations", "value": ANNOTATIONS, "short": False},
                    {"title": "Parameters", "value": PARAMETERS, "short": False}
                ]
            }
        ]
    }
    res = requests.post(url, json=post_data)
    assert res.status_code == 200, f"{res.status_code} {res.text}"


def get_last_cron_workflow_status(name, creation_timstamp, namespace, cron_workflow):
    assert ARGO_WORKFLOWS_URL, "ARGO_WORKFLOWS_URL environment variable is not set"
    assert ARGO_WORKFLOWS_TOKEN, "ARGO_WORKFLOWS_TOKEN environment variable is not set"
    res = requests.get(
        f"{ARGO_WORKFLOWS_URL}/api/v1/workflows/{namespace}",
        headers={
            'Authorization': f"Bearer {ARGO_WORKFLOWS_TOKEN}",
        },
        params={
            'listOptions.labelSelector': f'workflows.argoproj.io/cron-workflow={cron_workflow}',
            'fields': 'items.metadata.name,items.metadata.creationTimestamp,items.metadata.labels',
        }
    )
    assert res.status_code == 200, f"{res.status_code} {res.text}"
    past_workflows = []
    for workflow in (res.json().get('items') or []):
        if (
            workflow['metadata']['name'] != name
            and workflow['metadata']['labels']['workflows.argoproj.io/completed'] == 'true'
            and workflow['metadata']['creationTimestamp'] < creation_timstamp
        ):
            past_workflows.append({
                'name': workflow['metadata']['name'],
                'phase': workflow['metadata']['labels'].get('workflows.argoproj.io/phase', 'Unknown'),
                'timestamp': workflow['metadata']['creationTimestamp'],
            })
    res = requests.get(
        f"{ARGO_WORKFLOWS_URL}/api/v1/archived-workflows",
        headers={
            'Authorization': f"Bearer {ARGO_WORKFLOWS_TOKEN}",
        },
        params={
            'namePrefix': f'{cron_workflow}-',
            'listOptions.fieldSelector': f'metadata.namespace={namespace}',
        }
    )
    for workflow in (res.json().get('items') or []):
        if (
            workflow['metadata']['name'] != name
            and workflow['metadata']['creationTimestamp'] < creation_timstamp
        ):
            past_workflows.append({
                'name': workflow['metadata']['name'],
                'phase': workflow['status'].get('phase', 'Unknown'),
                'timestamp': workflow['metadata']['creationTimestamp'],
            })
    if len(past_workflows) > 0:
        last_workflow = sorted(past_workflows, key=lambda w: w['timestamp'], reverse=True)[0]
        return last_workflow['phase'] == 'Succeeded'
    else:
        return None


def handle_cron_workflow(name, creation_timestamp, namespace, cron_workflow, is_success):
    last_is_success = get_last_cron_workflow_status(name, creation_timestamp, namespace, cron_workflow)
    if is_success != last_is_success:
        send_slack_notification()


def main():
    labels = json.loads(LABELS) if LABELS else {}
    name = NAME
    creation_timestamp = CREATION_TIMESTAMP
    namespace = NAMESPACE
    cron_workflow = labels.get("workflows.argoproj.io/cron-workflow")
    is_success = STATUS == 'Succeeded'
    if cron_workflow:
        handle_cron_workflow(name, creation_timestamp, namespace, cron_workflow, is_success)
    elif not is_success:
        send_slack_notification()
