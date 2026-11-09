-- FOOD-107

create or replace procedure chernov_food.courier_salary()
language plpgsql
as $$
declare
    v_month_start timestamp := date_trunc('month', localtimestamp);
    v_month_end   timestamp := date_trunc('month', localtimestamp) + interval '1 month';
    v_year        int       := extract(year  from localtimestamp)::int;
    v_month       int       := extract(month from localtimestamp)::int;
    v_updated     bigint;
begin
    with agg as materialized (
        select c.courier_id,
               c.status,
               c.coefficient,
               count(o.order_id) as cnt,
               coalesce(sum(o.commission), 0) as comm
        from chernov_food.courier c
        left join chernov_food."order" o on o.courier_id = c.courier_id and o.status = 'доставлен' 
				and o.order_timestamp >= v_month_start and o.order_timestamp <  v_month_end
        group by c.courier_id
    ),
    pay as (
        insert into chernov_food.courier_pay
               (year, month, courier_id, amount, coefficient_used)
        select v_year, v_month, a.courier_id,
               round(a.coefficient * a.comm, 2),
               a.coefficient
        from agg a
        on conflict (year, month, courier_id) do update
           set amount = excluded.amount, coefficient_used = excluded.coefficient_used
        returning courier_id
    )
    update chernov_food.courier cu
    set coefficient = case when a.cnt > 500 then 0.5
                           when a.cnt > 250 then 0.3
                           when a.cnt > 150 then 0.2
                           else 0.1 end
    from agg a
    where cu.courier_id = a.courier_id and a.status <> 'уволен';

    get diagnostics v_updated = row_count;
    raise notice 'courier_salary: период %-%, коэффициент обновлен у % курьеров', v_year, lpad(v_month::text, 2, '0'), v_updated;
end;
$$;