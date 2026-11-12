do $$
begin
    if not exists (select 1 from pg_roles where rolname = 'inspector') then
        create role inspector login password 'NetoSQL2025';
    end if;
end
$$ language plpgsql;

do $$
begin
    execute 'grant connect on database ' || current_database() || ' to inspector';
end
$$ language plpgsql;

grant all privileges on schema chernov_food to inspector;
grant all privileges on all tables in schema chernov_food to inspector;
grant all privileges on all sequences in schema chernov_food to inspector;
grant execute on all routines in schema chernov_food to inspector;

alter default privileges in schema chernov_food grant all on tables to inspector;
alter default privileges in schema chernov_food grant all on sequences to inspector;
alter default privileges in schema chernov_food grant execute on routines to inspector;

grant usage on schema exts to inspector;
grant execute on all functions in schema exts to inspector;

grant usage on schema information_schema to inspector;
grant usage on schema pg_catalog to inspector;

alter role inspector set search_path = chernov_food, exts;

select has_schema_privilege('inspector', 'chernov_food', 'USAGE') as food_usage,
       has_schema_privilege('inspector', 'chernov_food', 'CREATE') as food_create,
       has_schema_privilege('inspector', 'exts', 'USAGE') as exts_usage,
       has_table_privilege ('inspector', 'chernov_food.how_much_money', 'SELECT') as view_select;
