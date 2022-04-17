# Vault

Hashicorp Vault is used for secure centralized secrets storage

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
