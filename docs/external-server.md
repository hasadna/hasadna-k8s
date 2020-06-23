# external servers

This doc describes how we install and manage external servers, which are not hosted as part of the Kubernetes cluster.

These servers could be used for workloads which are not suitable for Kubernetes.

## Setting up Nginx + SSL

Install dependencies

```
sudo apt update -y && sudo apt install -y nginx certbot python-certbot-nginx
```

Create a DH key

```
sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
```

Set env var for the main SSL domain

```
DOMAIN=www.example.com
```

Create configuration files

```
sudo mkdir -p /var/lib/letsencrypt/.well-known &&\
sudo chgrp www-data /var/lib/letsencrypt &&\
sudo chmod g+s /var/lib/letsencrypt &&\
sudo rm /etc/nginx/sites-enabled/default &&\
echo '
proxy_set_header X-Forwarded-For $remote_addr;
proxy_set_header Host $http_host;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-Port $server_port;
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection $connection_upgrade;
proxy_read_timeout 900s;
' | sudo tee /etc/nginx/snippets/http2_proxy.conf &&\
echo '
location ^~ /.well-known/acme-challenge/ {
  allow all;
  root /var/lib/letsencrypt/;
  default_type "text/plain";
  try_files $uri =404;
}
' | sudo tee /etc/nginx/snippets/letsencrypt.conf &&\
echo '
ssl_dhparam /etc/ssl/certs/dhparam.pem;
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:50m;
ssl_session_tickets off;
ssl_protocols TLSv1.2 TLSv1.3;
# recommended cipher suite for modern browsers
ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH";
# cipher suite for backwards compatibility (IE6/windows XP)
# ssl_ciphers "ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS";
ssl_prefer_server_ciphers on;
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 30s;
add_header Strict-Transport-Security "max-age=15768000; includeSubdomains; preload";
add_header X-Frame-Options SAMEORIGIN;
add_header X-Content-Type-Options nosniff;
' | sudo tee /etc/nginx/snippets/ssl.conf &&\
echo '
map $http_upgrade $connection_upgrade {
    default Upgrade;
    ""      close;
}

server {
  listen 80;
  server_name _;
  include snippets/letsencrypt.conf;
  location / {
      return 200 "it works!";
      add_header Content-Type text/plain;
  }
}
' | sudo tee /etc/nginx/sites-enabled/default.conf &&\
echo "
ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
ssl_trusted_certificate /etc/letsencrypt/live/${DOMAIN}/chain.pem;
" | sudo tee /etc/nginx/snippets/letsencrypt_certs.conf
```

Ensure certbot reloads nginx on update

```
sudo sed -i 's/-q renew/-q renew --deploy-hook "service nginx reload"/' /lib/systemd/system/certbot.service
```

Restart nginx

```
sudo systemctl restart nginx
```

Register an SSL certificate

```
sudo certbot certonly --agree-tos --email me@example.com --webroot -w /var/lib/letsencrypt/ -d www.example.com
```

Create config file for the site, modify as needed

```
echo '
map $http_upgrade $connection_upgrade {
    default Upgrade;
    ""      close;
}
server {
  listen 80;
  listen    [::]:80;
  server_name "www.example.com";
  include snippets/letsencrypt.conf;
  return 301 https://$host$request_uri;
}
server {
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  server_name "www.example.com";
  include snippets/letsencrypt_certs.conf;
  include snippets/ssl.conf;
  include snippets/letsencrypt.conf;
  client_max_body_size 25m;
  location / {
    proxy_pass http://localhost:8080;
    include snippets/http2_proxy.conf;
  }
}
' | sudo tee /etc/nginx/sites-enabled/site.conf
```

Restart nginx

```
sudo systemctl restart nginx
```
