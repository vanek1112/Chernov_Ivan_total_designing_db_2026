create or replace procedure chernov_food.add_product(
	p_name varchar,
	p_product_category_id uuid,
	p_price numeric,
	p_restaurant_id uuid,
	p_photo_url text default null,
	p_rating numeric default null,
	p_status chernov_food.product_status default 'доступно',
	p_description text default null
) as $$
begin
	insert into chernov_food.product (product_id, product_name, product_category_id, price, restaurant_id, photo_url, rating, status, description)
	values (exts.uuid_generate_v4(), p_name, p_product_category_id, p_price, p_restaurant_id, p_photo_url, p_rating, p_status, p_description);
end;
$$ language plpgsql;
