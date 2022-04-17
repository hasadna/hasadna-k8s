## Datacity CKAN DGP secrets

Supported CKAN instances has a secret named `ckan-dgp-instances` under `datacity` namespace

You can edit this secret using Rancher to add CKAN instances

Each source CKAN instance should have the following value (replace NAME with the instance name in uppercase letters and underscores):

```
CKAN_INSTANCE_NAME_URL=
```

Target CKAN instances should also have an API key which give required permissions:

```
CKAN_INSTANCE_NAME_API_KEY=
```
