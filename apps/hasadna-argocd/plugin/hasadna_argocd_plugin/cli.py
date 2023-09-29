import os
import sys

import uumpa_argocd_plugin.generate
import uumpa_argocd_plugin.config
import uumpa_argocd_plugin.init
import uumpa_argocd_plugin.env


def set_hasadna_uumpa_env_config(config):
    for k, v in config.items():
        os.environ[k] = v
        setattr(uumpa_argocd_plugin.config, k, v)


def generate(namespace_name, chart_path, *helm_args, only_generators=False):
    uumpa_argocd_plugin.env.update_env(chart_path)
    if os.environ.get('ARGOCD_ENV_HELM_ARGS'):
        helm_args = [
            os.environ['ARGOCD_ENV_HELM_ARGS'],
            *helm_args,
        ]
    uumpa_argocd_plugin.generate.generate_local(namespace_name, chart_path, *helm_args, only_generators=only_generators)


def main():
    set_hasadna_uumpa_env_config({
        # this is just for local development, in production this is set in the Dockerfile
        'ARGOCD_ENV_UUMPA_ENV_CONFIG': 'argocd_plugin_env.yaml',
        'ARGOCD_UUMPA_GLOBAL_GENERATORS_CONFIG': os.path.join(os.path.dirname(__file__), '..', 'global_uumpa_generators.yaml')
    })
    cmd, *args = sys.argv[1:]
    if cmd == 'init':
        uumpa_argocd_plugin.init.init_local(*args)
    elif cmd == 'generate':
        only_generators = '--only-generators' in args
        if only_generators:
            args.remove('--only-generators')
        generate(*args, only_generators=only_generators)
    else:
        raise ValueError(f'Unknown command: {cmd}')


if __name__ == '__main__':
    main()
