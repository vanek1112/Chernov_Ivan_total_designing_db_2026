create or replace function chernov_food.get_statistic() returns table (
	restaurant_name varchar,
	best_product_name varchar,
	total_amount numeric,
	avg_amount numeric,
	best_user varchar
) as $$
begin
	return query
		select r.restaurant_name, bp.product_name, rs.sum_amount, rs.avg_check, bc.login
		from (
			select o.restaurant_id, sum(o.total_amount) as sum_amount, round(avg(o.total_amount), 2) as avg_check
			from chernov_food."order" o
			where o.status = 'доставлен'
			group by o.restaurant_id) rs
		join chernov_food.restaurant r on r.restaurant_id = rs.restaurant_id
		left join (
			select distinct on (p.restaurant_id) p.restaurant_id, p.product_name
			from chernov_food."order" o
			join chernov_food.order_structure os on os.order_id = o.order_id
			join chernov_food.product p on p.product_id = os.product_id
			where o.status = 'доставлен'
			group by p.restaurant_id, p.product_id, p.product_name
			order by p.restaurant_id, sum(os.quantity) desc, random()) bp on bp.restaurant_id = rs.restaurant_id
		join (
			select distinct on (o.restaurant_id) o.restaurant_id, c.login
			from chernov_food."order" o
			join chernov_food.client c on c.client_id = o.client_id
			where o.status = 'доставлен'
			group by o.restaurant_id, c.client_id, c.login
			order by o.restaurant_id, count(*) desc, random()) bc on bc.restaurant_id = rs.restaurant_id;
end;
$$ language plpgsql;
