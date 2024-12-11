# Github Pusher

Uses argo events and workflows to listen to webhooks from github and push changes to git to trigger deployment (via argocd).

## Adding a webhook

We already have an organization webhook for `hasadna` org so for repos under `hasadna` this is not needed.

You can either add an organization or a repository webhook, depending on the requirements, try not to add too many webhooks or organization with a lot of repos..

webhook configuration:

* Payload URL: `https://argo-events-github.k8s.hasadna.org.il/push`
* Content type: `application/json`
* Secret: get the secret from Vault path `Projects/iac/outputs/hasadna_argoevents` key `github_webhook_secret`
* SSL Verification: `Enable SSL verification`
* Which events: `Just the push event`

## Adding repos to the event source

The event source is defined at `apps/argoevents/templates/github-eventsource.yaml` and it listens to the webhook.

Add repository orgs / names you want to process under the `repositories` field.

## Modify the pusher config

The pusher configuration is defined at `apps/argoevents/templates/github-pusher-configmap.yaml`, you will need to modify the configuration depending 
on how you want to handle the event. Copy from the existing configuration and modify as needed or check the pusher code at `hasadna_k8s/github_pusher/`.
