FROM alpine:3
RUN apk update && apk add --no-cache pgbouncer
RUN adduser -D -g pgbouncer pgbouncer
USER pgbouncer
ENTRYPOINT ["pgbouncer"]
