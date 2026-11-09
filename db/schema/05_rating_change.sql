-- FOOD-105

create or replace function chernov_food.rating_change()
returns trigger
language plpgsql
as $$
declare
    v_old_type chernov_food.review_entity_type;
    v_old_id   uuid;
    v_new_type chernov_food.review_entity_type;
    v_new_id   uuid;
    v_type     chernov_food.review_entity_type;
    v_id       uuid;
    i          int;
begin
    if tg_op in ('UPDATE', 'DELETE') then
        v_old_type := old.entity_type;
        v_old_id   := old.entity_id;
    end if;
    if tg_op in ('INSERT', 'UPDATE') then
        v_new_type := new.entity_type;
        v_new_id   := new.entity_id;
    end if;

    if tg_op = 'UPDATE'
       and v_old_type = v_new_type
       and v_old_id = v_new_id
       and old.rating is not distinct from new.rating then
        return null;
    end if;

    for i in 1..2 loop
        if i = 1 then
            v_type := v_old_type;
            v_id   := v_old_id;
        else
            v_type := v_new_type;
            v_id   := v_new_id;
            if tg_op = 'UPDATE'
               and v_type = v_old_type
               and v_id = v_old_id then
                exit;
            end if;
        end if;

        if v_type = 'блюдо' then
            update chernov_food.product p
               set rating = (select round(avg(r.rating), 2)
                               from chernov_food.review r
                              where r.entity_type = 'блюдо'
                                and r.entity_id = v_id)
             where p.product_id = v_id;

        elsif v_type = 'ресторан' then
            update chernov_food.restaurant s
               set rating = (select round(avg(r.rating), 2)
                               from chernov_food.review r
                              where r.entity_type = 'ресторан'
                                and r.entity_id = v_id)
             where s.restaurant_id = v_id;
        end if;
    end loop;

    return null;
end;
$$;

create or replace trigger trg_review_rating_change
    after insert or update of rating, entity_type, entity_id or delete
    on chernov_food.review
    for each row
    execute function chernov_food.rating_change();
