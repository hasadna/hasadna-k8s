FROM ghcr.io/orihoch/uumpa-argocd-plugin/plugin:b0d4612b2f82c7197ee9cdb16b892f0b15e1cdcc
COPY global_uumpa_generators.yaml /opt/hasadna-argocd-plugin/
COPY setup.py /opt/hasadna-argocd-plugin/
COPY hasadna_argocd_plugin /opt/hasadna-argocd-plugin/hasadna_argocd_plugin
RUN pip install -e /opt/hasadna-argocd-plugin
ENV ARGOCD_ENV_UUMPA_ENV_CONFIG=argocd_plugin_env.yaml
ENV ARGOCD_UUMPA_GLOBAL_GENERATORS_CONFIG=/opt/hasadna-argocd-plugin/global_uumpa_generators.yaml
