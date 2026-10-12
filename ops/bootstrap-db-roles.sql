SELECT format('CREATE ROLE forma_migrator LOGIN PASSWORD %L', :'migration_password')
WHERE NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'forma_migrator')
\gexec
ALTER ROLE forma_migrator LOGIN PASSWORD :'migration_password';

SELECT format('CREATE ROLE forma_runtime LOGIN PASSWORD %L', :'app_password')
WHERE NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'forma_runtime')
\gexec
ALTER ROLE forma_runtime LOGIN PASSWORD :'app_password';

ALTER DATABASE forma OWNER TO forma_migrator;
ALTER SCHEMA public OWNER TO forma_migrator;
-- Nothing is granted implicitly: no PUBLIC CONNECT/TEMP and no object creation
-- in public. The runtime role gets exactly the DML listed in
-- grant-runtime-access.sql and bounded statement/transaction time.
REVOKE ALL ON DATABASE forma FROM PUBLIC;
REVOKE CONNECT, TEMPORARY ON DATABASE postgres FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
ALTER ROLE forma_runtime CONNECTION LIMIT 40;
ALTER ROLE forma_runtime SET statement_timeout = '15s';
ALTER ROLE forma_runtime SET lock_timeout = '10s';
ALTER ROLE forma_runtime SET idle_in_transaction_session_timeout = '30s';
GRANT CONNECT ON DATABASE forma TO forma_runtime;
GRANT USAGE ON SCHEMA public TO forma_runtime;
