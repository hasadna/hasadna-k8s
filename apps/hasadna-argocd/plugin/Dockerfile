FROM ghcr.io/orihoch/uumpa-argocd-plugin/plugin:f1f557b128efa63b3ed8234ad198e8ba6a41e2bd
COPY global_uumpa_generators.yaml /opt/hasadna-argocd-plugin/
COPY setup.py /opt/hasadna-argocd-plugin/
COPY hasadna_argocd_plugin /opt/hasadna-argocd-plugin/hasadna_argocd_plugin
RUN pip install -e /opt/hasadna-argocd-plugin
ENV ARGOCD_ENV_UUMPA_ENV_CONFIG=argocd_plugin_env.yaml
ENV ARGOCD_UUMPA_GLOBAL_GENERATORS_CONFIG=/opt/hasadna-argocd-plugin/global_uumpa_generators.yaml
