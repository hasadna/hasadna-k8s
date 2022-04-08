## IsraelProxy

Proxy server which exposes URLs which are only available from Israel externally

Relies on the fact that our Kubernetes nodes run on Israeli servers


## Differ

Check updates of remote static files

to run locally for development:

```
docker build -t differ charts-external/israelproxy/differ/ &&\
docker run -it \
           -v /tmp/differ:/data \
           -v `pwd`/charts-external/israelproxy/differ-config.yaml:/etc/differ/config.yaml \
           differ
```

Deploy:

```
docker tag differ uumpa/differ &&\
docker push uumpa/differ
```

Update with the docker hash
