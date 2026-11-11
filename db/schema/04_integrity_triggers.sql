create or replace function chernov_food.check_order_structure_restaurant() returns trigger as $$
begin
	if not exists (
		select 1
		from chernov_food.product p
		join chernov_food."order" o on o.restaurant_id = p.restaurant_id
		where p.product_id = new.product_id and o.order_id = new.order_id) then
		raise exception 'блюдо % не из ресторана заказа %', new.product_id, new.order_id;
	end if;
	return new;
end;
$$ language plpgsql;

create trigger trg_order_structure_same_restaurant
before insert or update of order_id, product_id on chernov_food.order_structure
for each row execute function chernov_food.check_order_structure_restaurant();


create or replace function chernov_food.check_review_entity() returns trigger as $$
begin
	if new.entity_type = 'блюдо' then
		if not exists (
			select 1
			from chernov_food.order_structure os
			where os.order_id = new.order_id and os.product_id = new.entity_id) then
			raise exception 'блюда % нет в заказе %', new.entity_id, new.order_id;
		end if;
	elsif new.entity_type = 'ресторан' then
		if not exists (
			select 1
			from chernov_food."order" o
			where o.order_id = new.order_id and o.restaurant_id = new.entity_id) then
			raise exception 'ресторан % не является рестораном заказа %', new.entity_id, new.order_id;
		end if;
	elsif new.entity_type = 'заказ' then
		if new.entity_id <> new.order_id then
			raise exception 'отзыв на заказ должен ссылаться на сам заказ %', new.order_id;
		end if;
	end if;
	return new;
end;
$$ language plpgsql;

create trigger trg_review_entity_check
before insert or update of entity_id, entity_type, order_id on chernov_food.review
for each row execute function chernov_food.check_review_entity();
