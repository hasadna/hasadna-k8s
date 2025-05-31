import base64
from types import SimpleNamespace

import pytest


# Import the module once so that monkeypatch works with module attributes
from hasadna_k8s.workflows import global_exit_hook as geh


# ---------------------------------------------------------------------------
# send_slack_notification
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "status_code, expect_error",
    [
        (200, False),  # Success – no assertion should be raised
        (500, True),   # Error   – an assertion should be raised
    ],
)
def test_send_slack_notification(monkeypatch, status_code, expect_error):
    """Ensure send_slack_notification sends the expected payload and handles
    Slack response status codes correctly."""

    # Prepare basic test data
    webhook_url = "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
    b64_webhook = base64.b64encode(webhook_url.encode()).decode()

    # Patch module-level constants that were captured on import
    monkeypatch.setattr(geh, "SLACK_WEBHOOK_URL_B64", b64_webhook, raising=False)
    monkeypatch.setattr(geh, "NAME", "wf-123", raising=False)
    monkeypatch.setattr(geh, "NAMESPACE", "default", raising=False)
    monkeypatch.setattr(geh, "STATUS", "Succeeded", raising=False)
    monkeypatch.setattr(geh, "FAILURES", "0", raising=False)
    monkeypatch.setattr(geh, "DURATION", "1m", raising=False)
    monkeypatch.setattr(geh, "CREATION_TIMESTAMP", "2023-01-01T00:00:00Z", raising=False)
    monkeypatch.setattr(geh, "LABELS", "{}", raising=False)
    monkeypatch.setattr(geh, "ANNOTATIONS", "{}", raising=False)
    monkeypatch.setattr(geh, "PARAMETERS", "{}", raising=False)

    captured = {}

    def fake_post(url, json):
        # Record the call for inspection
        captured["url"] = url
        captured["json"] = json

        return SimpleNamespace(status_code=status_code, text="error")

    monkeypatch.setattr("hasadna_k8s.workflows.global_exit_hook.requests.post", fake_post)

    if expect_error:
        with pytest.raises(AssertionError):
            geh.send_slack_notification()
    else:
        geh.send_slack_notification()

        # Basic sanity checks that the right request was prepared.
        assert captured["url"] == webhook_url
        assert captured["json"]["channel"] == "argo-workflows-notifications"
        assert "Workflow wf-123" in captured["json"]["text"]


# ---------------------------------------------------------------------------
# get_last_cron_workflow_status
# ---------------------------------------------------------------------------


_GET_STATUS_KWARGS = dict(
    name="cron-example-5555555",
    creation_timstamp="2023-02-01T00:00:00Z",
    namespace="datacity",
    cron_workflow="cron-example",
)
_GET_STATUS_TESTS = [
    # label, archived_items, live_items, expected_result
    (
        "succeeded (archived)",  # A past succeeded workflow – should return True
        [
            {
                "metadata": {
                    "name": "cron-example-4444444",
                    "creationTimestamp": "2023-01-01T00:00:00Z",
                },
                "status": {"phase": "Succeeded"},
            }
        ],
        [],
        True,
    ),
    (
        "succeeded (live)",  # A past succeeded workflow – should return True
        [],
        [
            {
                "metadata": {
                    "name": "cron-example-4444444",
                    "creationTimestamp": "2023-01-01T00:00:00Z",
                    'labels': {
                        'workflows.argoproj.io/completed': 'true',
                        'workflows.argoproj.io/phase': "Succeeded"
                    }
                },
            }
        ],
        True,
    ),
    (
        "failed (archived)",  # A past failed workflow – should return False
        [
            {
                "metadata": {
                    "name": "cron-example-4444444",
                    "creationTimestamp": "2023-01-01T00:00:00Z",
                },
                "status": {"phase": "Failed"},
            }
        ],
        [],
        False,
    ),
    (
        "failed (live)",  # A past failed workflow – should return False
        [],
        [
            {
                "metadata": {
                    "name": "cron-example-4444444",
                    "creationTimestamp": "2023-01-01T00:00:00Z",
                    'labels': {
                        'workflows.argoproj.io/completed': 'true',
                        'workflows.argoproj.io/phase': "Failed"
                    }
                },
            }
        ],
        False,
    ),
    (
        "ignore current name",
        [
            {
                "metadata": {
                    "name": "cron-example-5555555",
                    "creationTimestamp": "2023-01-01T00:00:00Z",
                },
                "status": {"phase": "Failed"},
            }
        ],
        [
            {
                "metadata": {
                    "name": "cron-example-5555555",
                    "creationTimestamp": "2023-01-01T00:00:00Z",
                    'labels': {
                        'workflows.argoproj.io/completed': 'true',
                        'workflows.argoproj.io/phase': "Failed"
                    }
                },
            }
        ],
        None,
    ),
    (
        "none",  # No previous workflow – should return None
        [],
        [],
        None,
    ),
]


@pytest.mark.parametrize("_label, archived_items, live_items, expected", _GET_STATUS_TESTS)
def test_get_last_cron_workflow_status(monkeypatch, _label, archived_items, live_items, expected):
    """Verify that the function returns correct status based on previous workflow
    executions (live and archived)."""

    # Patch constants
    monkeypatch.setattr(geh, "ARGO_WORKFLOWS_URL", "https://argo.example.com", raising=False)
    monkeypatch.setattr(geh, "ARGO_WORKFLOWS_TOKEN", "token", raising=False)

    # Counter so we can distinguish between first and second call
    call_index = {"i": 0}

    def fake_get(url, headers=None, params=None):  # pylint: disable=unused-argument
        call_index["i"] += 1

        if call_index["i"] == 1:  # live workflows endpoint
            return SimpleNamespace(status_code=200, json=lambda: {"items": live_items})
        elif call_index["i"] == 2:  # archived workflows endpoint
            return SimpleNamespace(status_code=200, json=lambda: {"items": archived_items})
        else:
            raise RuntimeError("Unexpected extra call to requests.get")

    monkeypatch.setattr("hasadna_k8s.workflows.global_exit_hook.requests.get", fake_get)

    # Run
    result = geh.get_last_cron_workflow_status(**_GET_STATUS_KWARGS)

    assert result == expected


# ---------------------------------------------------------------------------
# handle_cron_workflow
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "is_success,last_is_success,should_notify",
    [
        (True, True, False),
        (True, False, True),
        (False, True, True),
        (False, False, False),
        (True, None, True),
        (False, None, True),
    ],
)
def test_handle_cron_workflow(monkeypatch, is_success, last_is_success, should_notify):
    """Check that notifications are sent only when the success state changed."""

    # Stub get_last_cron_workflow_status
    monkeypatch.setattr(
        geh,
        "get_last_cron_workflow_status",
        lambda *a, **kw: last_is_success,
    )

    called = {"notified": 0}

    def fake_notify():
        called["notified"] += 1

    monkeypatch.setattr(geh, "send_slack_notification", fake_notify)

    geh.handle_cron_workflow(
        name="wf",
        creation_timestamp="2023-02-01T00:00:00Z",
        namespace="default",
        cron_workflow="cron-example",
        is_success=is_success,
    )

    assert bool(called["notified"]) == should_notify


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "cron_workflow_label,status,last_success,expect_notify",
    [
        ("cron", "Succeeded", True, False),   # success and no change – no notify
        ("cron", "Failed", True, True),       # status changed – notify
        (None, "Failed", None, True),          # not a cron workflow & failed – notify
        (None, "Succeeded", None, False),      # not a cron workflow & succeeded – no notify
    ],
)
def test_main(monkeypatch, cron_workflow_label, status, last_success, expect_notify):
    """Integration-level test for main() relying on patched helpers."""

    # Patch module attributes (these were frozen at import time)
    labels = {}
    if cron_workflow_label:
        labels["workflows.argoproj.io/cron-workflow"] = cron_workflow_label

    import json
    monkeypatch.setattr(geh, "LABELS", json.dumps(labels) if labels else "{}", raising=False)
    monkeypatch.setattr(geh, "NAME", "wf", raising=False)
    monkeypatch.setattr(geh, "CREATION_TIMESTAMP", "2023-02-01T00:00:00Z", raising=False)
    monkeypatch.setattr(geh, "NAMESPACE", "default", raising=False)
    monkeypatch.setattr(geh, "STATUS", status, raising=False)

    # Patch the dependencies used by main()
    def fake_notify():
        # Use a simple attribute on the module as a sentinel
        setattr(geh, "_notified", True)

    monkeypatch.setattr(geh, "send_slack_notification", fake_notify)

    def fake_last_status(*_a, **_kw):
        return last_success

    monkeypatch.setattr(geh, "get_last_cron_workflow_status", fake_last_status)

    # Run
    # Clear sentinel flag
    if hasattr(geh, "_notified"):
        delattr(geh, "_notified")

    geh.main()

    assert hasattr(geh, "_notified") is expect_notify
