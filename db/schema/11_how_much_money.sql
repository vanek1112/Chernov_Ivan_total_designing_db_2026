create or replace view chernov_food.how_much_money as
	with recursive months as (
		select date_trunc('month', min(o.order_timestamp)) as month_start
		from chernov_food."order" o
		where o.status = 'доставлен'
		union all
		select m.month_start + interval '1 month'
		from months m
		where m.month_start < (
			select date_trunc('month', max(o2.order_timestamp))
			from chernov_food."order" o2
			where o2.status = 'доставлен')
	),
	month_data as (
		select m.month_start,
			coalesce(mo.sum_no_commission, 0) as sum_no_commission,
			coalesce(mo.sum_with_commission, 0) as sum_with_commission,
			coalesce(mo.commission, 0) as commission,
			coalesce(mp.courier_pay, 0) as courier_pay
		from months m
		left join (
			select date_trunc('month', o.order_timestamp) as month_start,
				sum(o.order_amount) as sum_no_commission,
				sum(o.total_amount) as sum_with_commission,
				sum(o.commission) as commission
			from chernov_food."order" o
			where o.status = 'доставлен'
			group by 1) mo on mo.month_start = m.month_start
		left join (
			select make_date(cp.year, cp.month, 1)::timestamp as month_start,
				sum(cp.amount) as courier_pay
			from chernov_food.courier_pay cp
			group by 1) mp on mp.month_start = m.month_start
		where m.month_start is not null
	)
	select to_char(d.month_start, 'YYYY-MM') as year_month,
		d.sum_no_commission,
		d.sum_with_commission,
		d.commission,
		p.commission as prev_commission,
		d.commission - p.commission as commission_diff,
		d.courier_pay,
		d.commission - d.courier_pay as net_profit
	from month_data d
	left join month_data p on p.month_start = d.month_start - interval '1 month'
	order by d.month_start;
