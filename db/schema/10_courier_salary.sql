create or replace procedure chernov_food.courier_salary() as $$
declare
	month_start timestamp = date_trunc('month', now()::timestamp) - interval '1 month';
	month_end timestamp = date_trunc('month', now()::timestamp);
	pay_year int2 = extract(year from month_start);
	pay_month int2 = extract(month from month_start);
begin
	insert into chernov_food.courier_pay (year, month, courier_id, amount, coefficient_used)
	select pay_year, pay_month, c.courier_id,
		round(coalesce(sum(o.commission), 0) * coalesce(cp.coefficient_used, c.coefficient), 2),
		coalesce(cp.coefficient_used, c.coefficient)
	from chernov_food.courier c
	left join chernov_food."order" o on o.courier_id = c.courier_id and o.status = 'доставлен'
		and o.order_timestamp >= month_start and o.order_timestamp < month_end
	left join chernov_food.courier_pay cp on cp.courier_id = c.courier_id and cp.year = pay_year 
		and cp.month = pay_month
	group by c.courier_id, c.coefficient, cp.coefficient_used
	on conflict (year, month, courier_id) do update
	set amount = excluded.amount, coefficient_used = excluded.coefficient_used;

	update chernov_food.courier c
	set coefficient = case
						  when s.deliveries <= 150 then 0.1
						  when s.deliveries <= 250 then 0.2
						  when s.deliveries <= 500 then 0.3
						  else 0.5
					  end
	from (
		select c2.courier_id, count(o.order_id) as deliveries
		from chernov_food.courier c2
		left join chernov_food."order" o on o.courier_id = c2.courier_id and o.status = 'доставлен'
			and o.order_timestamp >= month_start and o.order_timestamp < month_end
		group by c2.courier_id) s
	where s.courier_id = c.courier_id and c.status <> 'уволен';
end;
$$ language plpgsql;
