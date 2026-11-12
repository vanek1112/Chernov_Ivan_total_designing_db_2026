create or replace function chernov_food.rating_change() returns trigger as $$
declare
	old_id uuid;
	new_id uuid;
begin
	if tg_op = 'INSERT' or tg_op = 'UPDATE' then
		new_id = new.entity_id;
	end if;
	if tg_op = 'DELETE' or tg_op = 'UPDATE' then
		old_id = old.entity_id;
	end if;

	update chernov_food.product p
	set rating = (
		select round(avg(r.rating), 2)
		from chernov_food.review r
		where r.entity_type = 'блюдо' and r.entity_id = p.product_id)
	where p.product_id in (old_id, new_id);

	update chernov_food.restaurant rs
	set rating = (
		select round(avg(r.rating), 2)
		from chernov_food.review r
		where r.entity_type = 'ресторан' and r.entity_id = rs.restaurant_id)
	where rs.restaurant_id in (old_id, new_id);

	return null;
end;
$$ language plpgsql;

create trigger trg_review_rating_change
after insert or delete or update of entity_id, entity_type, rating on chernov_food.review
for each row execute function chernov_food.rating_change();
