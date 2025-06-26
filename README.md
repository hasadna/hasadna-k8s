# Hasadna Kubernetes Environment

Infrastructure as code for The Public Knowledge Workshop

See [docs/argocd.md](docs/argocd.md) for defining deployed apps and continuous deployment.

## Python CLI Local Developmentab

Prerequisites:


* Python 3.12
* [uv](https://docs.astral.sh/uv/)

```
uv sync
uv run hasadna-k8s
```

Running unit tests

```
uv pip install --requirement tests/requirements.txt
uv run pytest
```

## Deleted code

See this commit for some old deleted code which might be useful in the future https://github.com/hasadna/hasadna-k8s/tree/6cf0d6b0d88170dadc85f16790caa9087b051a14

