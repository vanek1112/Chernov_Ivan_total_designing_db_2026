-- FOOD-106

create or replace function chernov_food.get_statistic()
returns table (
    restaurant_name   varchar,
    best_product_name varchar,
    total_amount      numeric,
    avg_amount        numeric,
    best_user         varchar
)
language sql
volatile
as $$
    with d as materialized (
        select o.order_id, o.restaurant_id, o.client_id, o.total_amount
        from chernov_food."order" o
        where o.status = 'доставлен'
    ),

    by_client as (
        select d.restaurant_id, c.login, count(*) as cnt, sum(d.total_amount) as amt
        from d
        join chernov_food.client c on c.client_id = d.client_id
        group by d.restaurant_id, c.client_id
    ),

    rc as (
        select bc.restaurant_id,
               sum(bc.amt)  as amt,
               sum(bc.cnt)  as cnt,
               (array_agg(bc.login order by bc.cnt desc, random()))[1] as best_user
        from by_client bc
        group by bc.restaurant_id
    ),

    by_product as (
        select d.restaurant_id, os.product_id, sum(os.quantity) as qty
        from d
        join chernov_food.order_structure os on os.order_id = d.order_id
        group by d.restaurant_id, os.product_id
    ),

    rp as (
        select bp.restaurant_id,
               (array_agg(bp.product_id order by bp.qty desc, random()))[1] as product_id
        from by_product bp
        group by bp.restaurant_id
    )
    select r.restaurant_name,
           p.product_name,
           rc.amt,
           rc.amt / rc.cnt,
           rc.best_user
    from rc
    join chernov_food.restaurant r on r.restaurant_id = rc.restaurant_id
    left join rp on rp.restaurant_id = rc.restaurant_id
    left join chernov_food.product p on p.product_id = rp.product_id
    order by r.restaurant_name;
$$;