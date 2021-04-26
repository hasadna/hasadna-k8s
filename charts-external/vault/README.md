# Vault

Hashicorp Vault is used for secure centralized secrets storage

## Install

Connect to vault production environment

```
export KUBECONFIG=/path/to/kamatera/kubeconfig
source switch_environment.sh vault
```

Create namespace

```
kubectl create ns vault
```

Dry Run

```
./helm_upgrade_external_chart.sh vault --install --debug --dry-run
```

Deploy

```
./helm_upgrade_external_chart.sh vault --install
```

## Usage

### Add an admin user

* Login with the initial root token
* access -> auth methods -> userpass -> create user
* access -> entities -> create entity
  * same name as user
  * create
  * add alias
    * name: same nams as user
    * auth backend: userpass
* access -> groups -> admins -> edit group
  * member entity ids -> add the user
  * save
