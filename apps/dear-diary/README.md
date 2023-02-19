# Dear Diary

## Setup Read-Only DB Access VIA Redash

Execute shell on db pod and run the following:

```bash
su postgres
psql
create role readonly;
GRANT CONNECT ON DATABASE postgres TO readonly;
grant usage on schema public to readonly ;
CREATE USER redash with password '*****'
grant readonly to redash;
grant select on parsing_calendar to readonly ;
grant select on parsing_event to readonly ;
```
