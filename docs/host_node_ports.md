# host ports / node ports

Some workloads use host or node ports to expose services (usually databases)

We have to manually make sure there are no port collisions

Following commands list all taken host / node ports:

host ports:

```
kubectl get --all-namespaces pods -o 'go-template={{ range .items }}{{ range .spec.containers }}{{range .ports}}{{ if .hostPort }}{{ .hostPort }},{{ end }}{{ end }}{{ end }}{{ end }}'
```

node ports:

```
kubectl get --all-namespaces services -o 'go-template={{ range .items }}{{ range .spec.ports }}{{ if .nodePort }}{{ .nodePort }},{{ end }}{{ end }}{{ end }}'
```
