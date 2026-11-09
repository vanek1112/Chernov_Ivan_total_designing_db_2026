-- Правила, которые нельзя выразить декларативно


-- BR-7.3 блюдо в order_structure принадлежит ресторану заказа (FOOD-101)
create or replace function chernov_food.trg_order_structure_same_restaurant()
returns trigger
language plpgsql
as $$
declare
    v_order_restaurant uuid;
    v_product_restaurant uuid;
begin
    select o.restaurant_id
    into v_order_restaurant
    from chernov_food."order" o
    where o.order_id = new.order_id;

    select p.restaurant_id
    into v_product_restaurant
    from chernov_food.product p
    where p.product_id = new.product_id;

    if v_order_restaurant is null or v_product_restaurant is null then
        return new;
    end if;

    if v_order_restaurant <> v_product_restaurant then
        raise exception
            'BR-7.3: блюдо % принадлежит ресторану %, а заказ % оформлен в ресторане %',
            new.product_id, v_product_restaurant, new.order_id, v_order_restaurant
            using errcode = 'integrity_constraint_violation',
                  hint = 'В заказ можно добавлять только блюда ресторана этого заказа';
    end if;

    return new;
end;
$$;

create or replace trigger trg_order_structure_same_restaurant
    before insert or update of order_id, product_id
    on chernov_food.order_structure
    for each row
    execute function chernov_food.trg_order_structure_same_restaurant();


-- смена ресторана у заказа не должна ломать BR-7.3 и BR-9.2
create or replace function chernov_food.trg_order_restaurant_guard()
returns trigger
language plpgsql
as $$
begin
    if exists (select 1
               from chernov_food.order_structure os
               join chernov_food.product p on p.product_id = os.product_id
               where os.order_id = new.order_id
                  and p.restaurant_id <> new.restaurant_id) then
        raise exception
            'BR-7.3: нельзя сменить ресторан заказа %: в нем есть блюда другого ресторана',
            new.order_id
            using errcode = 'integrity_constraint_violation';
    end if;

    if exists (select 1
               from chernov_food.review r
               where r.order_id = new.order_id
                  and r.entity_type = 'ресторан'
                  and r.entity_id <> new.restaurant_id) then
        raise exception
            'BR-9.2: нельзя сменить ресторан заказа %: есть отзыв на прежний ресторан',
            new.order_id
            using errcode = 'integrity_constraint_violation';
    end if;

    return new;
end;
$$;

create or replace trigger trg_order_restaurant_guard
    before update of restaurant_id
    on chernov_food."order"
    for each row
    when (old.restaurant_id is distinct from new.restaurant_id)
    execute function chernov_food.trg_order_restaurant_guard();


-- перенос блюда в другой ресторан не должен ломать уже оформленные заказы
create or replace function chernov_food.trg_product_restaurant_guard()
returns trigger
language plpgsql
as $$
begin
    if exists (select 1
               from chernov_food.order_structure os
               join chernov_food."order" o on o.order_id = os.order_id
               where os.product_id = new.product_id
                  and o.restaurant_id <> new.restaurant_id) then
        raise exception
            'BR-7.3: блюдо % уже входит в заказы другого ресторана, смена ресторана запрещена',
            new.product_id
            using errcode = 'integrity_constraint_violation';
    end if;

    return new;
end;
$$;

create or replace trigger trg_product_restaurant_guard
    before update of restaurant_id
    on chernov_food.product
    for each row
    when (old.restaurant_id is distinct from new.restaurant_id)
    execute function chernov_food.trg_product_restaurant_guard();


-- BR-9.2: проверка полиморфной ссылки review.entity_id
create or replace function chernov_food.trg_review_entity_check()
returns trigger
language plpgsql
as $$
declare
    v_ok boolean := true;
begin
    if new.entity_type = 'блюдо' then
        select exists (select 1
                       from chernov_food.order_structure os
                       where os.order_id = new.order_id
                          and os.product_id = new.entity_id)
        into v_ok;
        if not v_ok then
            raise exception
                'BR-9.2: блюдо % не входит в состав заказа %, отзыв невозможен',
                new.entity_id, new.order_id
                using errcode = 'foreign_key_violation';
        end if;

    elsif new.entity_type = 'ресторан' then
        select exists (select 1
                       from chernov_food."order" o
                       where o.order_id = new.order_id
                          and o.restaurant_id = new.entity_id)
        into v_ok;
        if not v_ok then
            raise exception
                'BR-9.2: заказ % оформлен не в ресторане %, отзыв невозможен',
                new.order_id, new.entity_id
                using errcode = 'foreign_key_violation';
        end if;

    elsif new.entity_type = 'заказ' then
        if new.entity_id is distinct from new.order_id then
            raise exception
                'BR-9.2: для отзыва на заказ entity_id (%) должен совпадать с order_id (%)',
                new.entity_id, new.order_id
                using errcode = 'foreign_key_violation';
        end if;
    end if;

    return new;
end;
$$;

create or replace trigger trg_review_entity_check
    before insert or update of entity_id, entity_type, order_id
    on chernov_food.review
    for each row
    execute function chernov_food.trg_review_entity_check();

-- нельзя убрать из заказа блюдо, на которое уже есть отзыв, исходя из логики правила BR-9.2
create or replace function chernov_food.trg_order_structure_review_guard()
returns trigger
language plpgsql
as $$
begin
    if tg_op = 'UPDATE'
       and old.order_id = new.order_id
       and old.product_id = new.product_id then
        return new;
    end if;

    if exists (select 1
               from chernov_food.review r
               where r.order_id = old.order_id
                  and r.entity_type = 'блюдо'
                  and r.entity_id = old.product_id) then
        raise exception
            'BR-9.2: блюдо % нельзя убрать из заказа %: на него оставлен отзыв',
            old.product_id, old.order_id
            using errcode = 'integrity_constraint_violation';
    end if;

    if tg_op = 'DELETE' then
        return old;
    end if;
    return new;
end;
$$;

create or replace trigger trg_order_structure_review_guard
    before update of order_id, product_id or delete
    on chernov_food.order_structure
    for each row
    execute function chernov_food.trg_order_structure_review_guard();


-- BR-8.7: order.pay_status всегда выводится из попыток оплаты
create or replace function chernov_food.trg_payment_sync_order_pay_status()
returns trigger
language plpgsql
as $$
declare
    v_ids uuid[];
    v_id  uuid;
    v_new chernov_food.order_pay_status;
begin
    if tg_op = 'INSERT' then
        v_ids := array[new.order_id];
    elsif tg_op = 'DELETE' then
        v_ids := array[old.order_id];
    else
        v_ids := array[new.order_id];
        if old.order_id <> new.order_id then
            v_ids := v_ids || old.order_id;
        end if;
    end if;

    foreach v_id in array v_ids loop
        select (case
                    when bool_or(p.status = 'успех')       then 'оплачен'
                    when bool_or(p.status = 'в_обработке') then 'ожидает'
                    else 'ошибка'
                end)::chernov_food.order_pay_status
        into v_new
        from chernov_food.payment p
        where p.order_id = v_id
        having count(*) > 0;

        if not found then
            v_new := 'ожидает';
        end if;

        update chernov_food."order" o
        set pay_status = v_new
        where o.order_id = v_id and o.pay_status is distinct from v_new;
    end loop;

    return null;
end;
$$;

create or replace trigger trg_payment_sync_order_pay_status
    after insert or update of order_id, status or delete
    on chernov_food.payment
    for each row
    execute function chernov_food.trg_payment_sync_order_pay_status();