# Multi-tenant Wordpress

This chart allows to deploy multiple Wordpress instances

## Install

Create namespace

```
kubectl create ns wordpress
```

Create DB secret

```
kubectl -n wordpress create secret generic db \
    --from-literal=MYSQL_ROOT_PASSWORD=
```

Create SMTP secret

```
kubectl -n wordpress create secret generic smtp \
    --from-literal=user= \
    --from-literal=password=
```

## Add a website

Create NFS path `/wordpress/SITE_NAME`

Create secret

```
kubectl -n wordpress create secret generic SITE_NAME \
    --from-literal=DB_PASSWORD=
```

Add the site to deployment and ingresses in environments/wordpress/values.yaml

Should use Cloudflare with full proxy and SSL via Cloudflare

Once site is running and ingress is setup, edit `wp-config.php` and set `$_SERVER['HTTPS'] = 'on';`

The main admin user should use a random and secure username / password

Each user should use it's own personal username / password

### Setup SMTP

Set email settings, the from address should be verified in our amazon SES account

```
SMTP_FROM="admin@site.com"
SMTP_FROM_NAME="Site Name"
```

Set SMTP secrets

```
SMTP_USER="$(kubectl -n wordpress get secret smtp -o json | jq -r .data.user | base64 -d)"
SMTP_PASSWORD="$(kubectl -n wordpress get secret smtp -o json | jq -r .data.password | base64 -d)"
```

Copy the base64 encoded wp settings to clipboard:

```
echo '
/* SMTP Settings */
add_action( "phpmailer_init", "mail_smtp" );
function mail_smtp( $phpmailer ) {
  $phpmailer->isSMTP();
  $phpmailer->Host = "email-smtp.eu-west-1.amazonaws.com";
  $phpmailer->SMTPAutoTLS = true;
  $phpmailer->SMTPAuth = true;
  $phpmailer->Port = "587";
  $phpmailer->Username = "'${SMTP_USER}'";
  $phpmailer->Password = "'${SMTP_PASSWORD}'";
  // Additional settings
  $phpmailer->SMTPSecure = "tls";
  $phpmailer->From = "'${SMTP_FROM}'";
  $phpmailer->FromName = "'${SMTP_FROM_NAME}'";
}
' | base64 -w0
```

Exec shell in wordpress container and add them:

```
echo 'the base64 encoded settings' | base64 -d >> wp-settings.php 
```
