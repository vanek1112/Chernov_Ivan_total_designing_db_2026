create or replace procedure chernov_food.insert_test_data(value int) as $$
declare
	client_ids uuid[] = array(select exts.uuid_generate_v4() from generate_series(1, value));
	courier_ids uuid[] = array(select exts.uuid_generate_v4() from generate_series(1, value));
	category_ids uuid[] = array(select exts.uuid_generate_v4() from generate_series(1, value));
	restaurant_ids uuid[] = array(select exts.uuid_generate_v4() from generate_series(1, value));
	address_ids uuid[] = array(select exts.uuid_generate_v4() from generate_series(1, value * 5));
	product_ids uuid[] = array(select exts.uuid_generate_v4() from generate_series(1, value * 5));
	order_ids uuid[] = array(select exts.uuid_generate_v4() from generate_series(1, value * 5));
	start_ts timestamp = date_trunc('month', now()::timestamp  - interval '5 months');
	end_ts timestamp = now()::timestamp;
	alphabet text = 'абвгдеёжзийклмнопрстуфхцчшщъыьэюя';
	code_base int = floor(random() * 1000000)::int;
	phone_base bigint = floor(random() * 9000000000)::bigint;
	month_start timestamp;
	pay_year int2;
	pay_month int2;
begin
	-- клиенты
	insert into chernov_food.client (client_id, login, "password", phone_number)
	select client_ids[g.i],
		left(substr(alphabet, g.n / 35937 % 33 + 1, 1) || substr(alphabet, g.n / 1089 % 33 + 1, 1) || substr(alphabet, g.n / 33 % 33 + 1, 1) 
			|| substr(alphabet, g.n % 33 + 1, 1) || substring(repeat(alphabet, 5), 1 + floor(random() * 33)::int), 16 + floor(random() * 35)::int),
		md5(random()::text),
		'+7' || lpad(((phone_base + g.i::bigint * 7919) % 10000000000)::text, 10, '0')
	from (
		select i, (code_base + i) % 1185921 as n
		from generate_series(1, value) i) g;

	-- адреса
	insert into chernov_food.address (address_id, street, house_number, apartment_office)
	select address_ids[g.i],
		left(substr(alphabet, g.n / 35937 % 33 + 1, 1) || substr(alphabet, g.n / 1089 % 33 + 1, 1) || substr(alphabet, g.n / 33 % 33 + 1, 1) 
			|| substr(alphabet, g.n % 33 + 1, 1) || substring(repeat(alphabet, 5), 1 + floor(random() * 33)::int), 16 + floor(random() * 85)::int),
		substring(repeat(alphabet, 2), 1 + floor(random() * 33)::int, 1 + floor(random() * 10)::int),
		case 
			when random() < 0.3 then null
			else substring(repeat(alphabet, 2), 1 + floor(random() * 33)::int, 1 + floor(random() * 10)::int)
		end
	from (
		select i, (code_base + i) % 1185921 as n
		from generate_series(1, value * 5) i) g;

	insert into chernov_food.client_address (client_id, address_id)
	select client_ids[(i - 1) / 4 + 1], address_ids[value + i]
	from generate_series(1, value * 4) i;

	-- категории
	insert into chernov_food.product_category (product_category_id, product_category_name)
	select category_ids[g.i],
		left(substr(alphabet, g.n / 35937 % 33 + 1, 1) || substr(alphabet, g.n / 1089 % 33 + 1, 1) || substr(alphabet, g.n / 33 % 33 + 1, 1) 
			|| substr(alphabet, g.n % 33 + 1, 1) || substring(repeat(alphabet, 5), 1 + floor(random() * 33)::int), 16 + floor(random() * 85)::int)
	from (
		select i, (code_base + i) % 1185921 as n
		from generate_series(1, value) i) g;

	-- рестораны
	insert into chernov_food.restaurant (restaurant_id, restaurant_name, address_id, description, work_start, work_end, inn, kpp, ogrn, status)
	select restaurant_ids[i], substring(repeat(alphabet, 5), 1 + floor(random() * 33)::int, 1 + floor(random() * 100)::int),
		address_ids[i],
		case 
			when random() < 0.3 then null
			else substring(repeat(alphabet, 8), 1 + floor(random() * 33)::int, 1 + floor(random() * 200)::int)
		end,
		time '06:00' + floor(random() * 5)::int * interval '1 hour',
		time '18:00' + floor(random() * 6)::int * interval '1 hour',
		lpad(floor(random() * 10000000000)::bigint::text, 10, '0'),
		lpad(floor(random() * 1000000000)::bigint::text, 9, '0'),
		lpad(floor(random() * 10000000000000)::bigint::text, 13, '0'),
		case 
			when i = 1 then 'активен'
			else (array['активен', 'неактивен'])[1 + floor(random() * 2)::int] 
		end::chernov_food.restaurant_status
	from generate_series(1, value) i;

	-- курьеры
	insert into chernov_food.courier (courier_id, last_name, first_name, middle_name, phone_number, status, hire_date, dismissal_date, coefficient)
	select courier_ids[s.i], substring(repeat(alphabet, 4), 1 + floor(random() * 33)::int, 1 + floor(random() * 50)::int),
		substring(repeat(alphabet, 4), 1 + floor(random() * 33)::int, 1 + floor(random() * 50)::int),
		substring(repeat(alphabet, 4), 1 + floor(random() * 33)::int, 1 + floor(random() * 50)::int),
		'+7' || lpad(floor(random() * 10000000000)::bigint::text, 10, '0'),
		s.status::chernov_food.courier_status,
		start_ts::date - (30 + floor(random() * 1000)::int),
		case 
			when s.status = 'уволен'
			then end_ts::date + floor(random() * extract(day from current_date))::int
		end,
		0.1
	from (
		select i,
			case 
				when i = 1 then 'свободен'
				else (array['свободен', 'занят', 'на_доставке', 'уволен'])[1 + floor(random() * 4)::int] 
			end as status
		from generate_series(1, value) i) s;

	-- блюда
	insert into chernov_food.product (product_id, product_name, product_category_id, price, restaurant_id, photo_url, status, description)
	select product_ids[i], substring(repeat(alphabet, 5), 1 + floor(random() * 33)::int, 1 + floor(random() * 100)::int), category_ids[1 + floor(random() * value)::int],
		round((100 + random() * 2900)::numeric, 2), restaurant_ids[(i - 1) % value + 1],
		case 
			when random() < 0.5 then null 
			else 'https://cdn.foodexpress.ru/img/' || md5(random()::text) || '.jpg' 
		end,
		(array['доступно', 'нет_в_наличии', 'архив'])[1 + floor(random() * 3)::int]::chernov_food.product_status,
		substring(repeat(alphabet, 8), 1 + floor(random() * 33)::int, 1 + floor(random() * 200)::int)
	from generate_series(1, value * 5) i;

	-- заказы
	insert into chernov_food."order" (order_id, courier_id, client_id, address_id, restaurant_id, order_timestamp, delivery_timestamp, order_amount, status, pay_status, description)
	select order_ids[s.j], courier_ids[s.courier_idx], client_ids[s.client_idx], address_ids[value + (s.client_idx - 1) * 4 + s.addr_idx], restaurant_ids[s.restaurant_idx], s.created,
		case 
			when s.x_status < 0.6 then s.created + interval '20 minutes' + random() * interval '90 minutes' 
		end, 
		1000,
		(case 
			when s.x_status < 0.6 then 'доставлен'
			when s.x_status < 0.7 then 'создан'
			when s.x_status < 0.8 then 'готовится'
			when s.x_status < 0.9 then 'в_доставке'
			else 'отменен' 
		end)::chernov_food.order_status,
		(case 
			when s.x_pay < 0.7 then 'оплачен'
			when s.x_pay < 0.85 then 'ожидает'
			else 'ошибка' 
		end)::chernov_food.order_pay_status,
		case 
			when random() < 0.5 then null
			else substring(repeat(alphabet, 8), 1 + floor(random() * 33)::int, 1 + floor(random() * 200)::int)
		end
	from (
		select j,
			1 + floor(random() * value)::int as courier_idx,
			1 + floor(random() * value)::int as client_idx,
			1 + floor(random() * 4)::int as addr_idx,
			1 + floor(random() * value)::int as restaurant_idx,
			date_trunc('second', start_ts + random() * (end_ts - start_ts)) as created,
			random() as x_status,
			random() as x_pay
		from generate_series(1, value * 5) j) s;

	-- состав заказов
	insert into chernov_food.order_structure (order_id, product_id, quantity)
	select o.order_id, p.product_id, ceil(1000 / p.price) + (floor(random() * 3) * 0.5)::numeric
	from unnest(order_ids) as t(order_id)
	join chernov_food."order" o on o.order_id = t.order_id
	join chernov_food.product p on p.restaurant_id = o.restaurant_id
	where random() < 0.3;

	insert into chernov_food.order_structure (order_id, product_id, quantity)
	select distinct on (o.order_id) o.order_id, p.product_id, ceil(1000 / p.price)
	from unnest(order_ids) as t(order_id)
	join chernov_food."order" o on o.order_id = t.order_id
	join chernov_food.product p on p.restaurant_id = o.restaurant_id
	where not exists (
		select 1
		from chernov_food.order_structure os
		where os.order_id = o.order_id)
	order by o.order_id, random();

	-- сумма заказа
	update chernov_food."order" o
	set order_amount = s.amount
	from (
		select os.order_id, round(sum(os.quantity * p.price), 2) as amount
		from unnest(order_ids) as t(order_id)
		join chernov_food.order_structure os on os.order_id = t.order_id
		join chernov_food.product p on p.product_id = os.product_id
		group by os.order_id) s
	where o.order_id = s.order_id;

	-- платежи
	insert into chernov_food.payment (payment_id, order_id, payment_type, amount, transaction_id, payment_timestamp, status)
	select exts.uuid_generate_v4(), o.order_id, (array['карта', 'наличные', 'безнал'])[1 + floor(random() * 3)::int]::chernov_food.payment_type,
		o.total_amount, exts.uuid_generate_v4(), o.order_timestamp + random() * interval '30 minutes',
		(case o.pay_status
			when 'оплачен' then 'успех'
			when 'ошибка' then 'ошибка'
			else 'в_обработке' 
		end)::chernov_food.payment_status
	from unnest(order_ids) as t(order_id)
	join chernov_food."order" o on o.order_id = t.order_id;

	-- отзывы
	insert into chernov_food.review (review_id, review_timestamp, entity_id, entity_type, order_id, client_id, description, photo_url, rating)
	select exts.uuid_generate_v4(), o.order_timestamp + interval '3 hours' + random() * interval '2 days',
		case s.type_idx 
			when 1 then s.product_id
			when 2 then o.restaurant_id else o.order_id
		end,
		(array['блюдо', 'ресторан', 'заказ'])[s.type_idx]::chernov_food.review_entity_type,
		o.order_id,
		o.client_id,
		substring(repeat(alphabet, 8), 1 + floor(random() * 33)::int, 1 + floor(random() * 200)::int),
		case 
			when random() < 0.5 then null
			else 'https://cdn.foodexpress.ru/img/' || md5(random()::text) || '.jpg'
		end,
		1 + floor(random() * 5)::int
	from (
		select distinct on (os.order_id) os.order_id, os.product_id, 1 + floor(random() * 3)::int as type_idx
		from unnest(order_ids) as t(order_id)
		join chernov_food.order_structure os on os.order_id = t.order_id
		order by os.order_id, random()) s
	join chernov_food."order" o on o.order_id = s.order_id;

	-- зарплаты
	for k in 0..5 loop
		month_start = start_ts + k * interval '1 month';
		pay_year = extract(year from month_start);
		pay_month = extract(month from month_start);

		insert into chernov_food.courier_pay (year, month, courier_id, amount, coefficient_used)
		select pay_year, pay_month, c.courier_id,
			round(coalesce(sum(o.commission), 0) * c.coefficient, 2),
			c.coefficient
		from unnest(courier_ids) as t(courier_id)
		join chernov_food.courier c on c.courier_id = t.courier_id
		left join chernov_food."order" o on o.courier_id = c.courier_id	and o.status = 'доставлен'
			and o.order_timestamp >= month_start and o.order_timestamp < month_start + interval '1 month'
		group by c.courier_id, c.coefficient;

		update chernov_food.courier c
		set coefficient = case
							  when s.deliveries <= 150 then 0.1
							  when s.deliveries <= 250 then 0.2
							  when s.deliveries <= 500 then 0.3
							  else 0.5
						  end
		from (
			select t.courier_id, count(o.order_id) as deliveries
			from unnest(courier_ids) as t(courier_id)
			left join chernov_food."order" o on o.courier_id = t.courier_id and o.status = 'доставлен'
				and o.order_timestamp >= month_start and o.order_timestamp < month_start + interval '1 month'
			group by t.courier_id) s
		where s.courier_id = c.courier_id and c.status <> 'уволен';
	end loop;
end;
$$ language plpgsql;
