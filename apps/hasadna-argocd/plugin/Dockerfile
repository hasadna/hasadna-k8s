FROM ghcr.io/orihoch/uumpa-argocd-plugin/plugin:56fc6251c88f85b46a59e6b583a216f18acb4769
COPY global_uumpa_generators.yaml /opt/hasadna-argocd-plugin/
COPY setup.py /opt/hasadna-argocd-plugin/
COPY hasadna_argocd_plugin /opt/hasadna-argocd-plugin/hasadna_argocd_plugin
RUN pip install -e /opt/hasadna-argocd-plugin
ENV ARGOCD_ENV_UUMPA_ENV_CONFIG=argocd_plugin_env.yaml
ENV ARGOCD_UUMPA_GLOBAL_GENERATORS_CONFIG=/opt/hasadna-argocd-plugin/global_uumpa_generators.yaml
