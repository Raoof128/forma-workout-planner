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
GRANT CONNECT ON DATABASE forma TO forma_runtime;
GRANT USAGE ON SCHEMA public TO forma_runtime;
