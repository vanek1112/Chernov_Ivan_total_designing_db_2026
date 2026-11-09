-- FOOD-108

create or replace view chernov_food.how_much_money as
with recursive ord as (
    select date_trunc('month', o.order_timestamp)::date as m_start,
           sum(o.order_amount) as s_no,
           sum(o.total_amount) as s_with
    from chernov_food."order" o
    where o.status = 'доставлен'
    group by date_trunc('month', o.order_timestamp)::date
),
bounds as (
    select min(ord.m_start) as first_m,
           max(ord.m_start) as last_m
      from ord
),
months (m_start) as (
    select b.first_m
    from bounds b
    where b.first_m is not null
    union all
    select (m.m_start + interval '1 month')::date
    from months m
    cross join bounds b
    where m.m_start < b.last_m
),
pay as (
    select make_date(cp.year, cp.month, 1) as m_start,
           sum(cp.amount) as amt
    from chernov_food.courier_pay cp
    group by make_date(cp.year, cp.month, 1)
),
base as (
    select m.m_start,
           coalesce(o.s_no, 0)::numeric as s_no,
           coalesce(o.s_with, 0)::numeric as s_with,
           (coalesce(o.s_with, 0) - coalesce(o.s_no, 0))::numeric as commission,
           coalesce(p.amt, 0)::numeric as cpay
    from months m
    left join ord o on o.m_start = m.m_start
    left join pay p on p.m_start = m.m_start
)
select to_char(b.m_start, 'YYYY-MM') as year_month,
	   b.s_no as sum_no_commission,
   	   b.s_with as sum_with_commission,
       b.commission as commission,
       lag(b.commission) over w as prev_commission,
       b.commission - lag(b.commission) over w as commission_diff,
       b.cpay as courier_pay,
       b.commission - b.cpay as net_profit
from base b
window w as (order by b.m_start)
order by b.m_start;