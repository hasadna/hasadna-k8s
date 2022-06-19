# SSH Access

Direct SSH access to K8S servers / cluster nodes is done via an SSH access point server.

To get access, add your ssh key to the [authorized_keys](https://github.com/hasadna/hasadna-iac/blob/main/modules/hasadna/locals.tf).

Get the server public IP / port from Vault `Projects/iac/outputs/hasadna_ssh_access_point`

For easy access, you can add the following snippet to your `~/.ssh/config` file (replace IP / PORT)

```
Host hasadna-ssh-access-point
  HostName IP
  User root
  Port PORT
```

## Example usage

SSH to hasadna-nfs1

```
ssh -t hasadna-ssh-access-point ssh hasadna-nfs1
```

List cluster nodes

```
ssh -t hasadna-ssh-access-point rancher nodes
```

SSH to a node

```
ssh -t hasadna-ssh-access-point rancher ssh hasadna-master1
```
