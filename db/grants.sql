-- FOOD-109

create role inspector login password 'NetoSQL2025';
grant connect on database postgres to inspector;

grant all privileges on schema chernov_food to inspector;
grant all privileges on all tables    in schema chernov_food to inspector;
grant all privileges on all sequences in schema chernov_food to inspector;
grant execute        on all routines  in schema chernov_food to inspector;

alter default privileges in schema chernov_food grant all     on tables    to inspector;
alter default privileges in schema chernov_food grant all     on sequences to inspector;
alter default privileges in schema chernov_food grant execute on routines  to inspector;

grant usage   on schema exts                  to inspector;
grant execute on all functions in schema exts to inspector;

grant usage on schema information_schema to inspector;
grant usage on schema pg_catalog         to inspector;

alter role inspector set search_path = chernov_food, exts;

select has_schema_privilege('inspector', 'chernov_food', 'USAGE') as food_usage,
       has_schema_privilege('inspector', 'chernov_food', 'CREATE') as food_create,
       has_schema_privilege('inspector', 'exts', 'USAGE') as exts_usage,
       has_table_privilege ('inspector', 'chernov_food.how_much_money', 'SELECT') as view_select;