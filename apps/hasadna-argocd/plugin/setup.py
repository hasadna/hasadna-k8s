from setuptools import setup, find_packages

setup(
    name='hasadna-argocd-plugin',
    packages=find_packages(exclude=['tests']),
    entry_points={
        'console_scripts': [
            'hasadna-argocd-plugin = hasadna_argocd_plugin.cli:main',
        ]
    },
)
