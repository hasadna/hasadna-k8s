FROM ghcr.io/orihoch/uumpa-argocd-plugin/plugin:a159a8fefd14343d3fd9addd4ec7e2b0542ba937
COPY global_uumpa_generators.yaml /opt/hasadna-argocd-plugin/
COPY setup.py /opt/hasadna-argocd-plugin/
COPY hasadna_argocd_plugin /opt/hasadna-argocd-plugin/hasadna_argocd_plugin
RUN pip install -e /opt/hasadna-argocd-plugin
ENV ARGOCD_ENV_UUMPA_ENV_CONFIG=argocd_plugin_env.yaml
ENV ARGOCD_UUMPA_GLOBAL_GENERATORS_CONFIG=/opt/hasadna-argocd-plugin/global_uumpa_generators.yaml
