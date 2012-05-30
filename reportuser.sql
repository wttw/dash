-- -*-sql-*-
-- Create report user


CREATE USER reports;
BEGIN;

-- Returns a display name for a username/password pair if it's valid,
-- returns nothing if not
CREATE OR REPLACE FUNCTION validate_login(text, text) RETURNS text AS $$
  select name from users where username=$1 and authdata=$2 and authtype='md5pass';
$$ LANGUAGE SQL SECURITY DEFINER;

CREATE OR REPLACE FUNCTION fetch_path(text) RETURNS SETOF pg_settings AS $$
  select * from pg_settings where name like $1 and name in ('config_file', 'data_directory', 'hba_file')
$$ LANGUAGE SQL SECURITY DEFINER;

-- GRANT SELECT ON TABLE blah, blah, blah TO reports;

GRANT EXECUTE ON FUNCTION validate_login(text, text), fetch_path(text) TO reports;

-- GRANT TEMPORARY ON DATABASE whatever TO reports;
COMMIT;