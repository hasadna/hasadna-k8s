# Problems and Solutions

## PostgreSQL DB fails to start after unexpected restart

DB error log:

```
invalid resource manager ID ...
invalid primary checkpoint record ...
PANIC: could not locate a valid checkpoint record
```

To fix - change the DB container command to prevent DB from starting but allow to execute shell (e.g. set command to sleep 86400)

Execute shell on the container and run something like the following (depending on actual container configuration):

```
su postgres
pg_resetwal /var/lib/postgresql/data
```

This will reset the write ahead log and allow DB to start, some data might be lost if something was changed when the restart happened.
