-- FOOD-104

drop procedure if exists chernov_food.add_product(
    varchar, uuid, numeric, uuid, text, numeric, chernov_food.product_status, text);

create procedure chernov_food.add_product(
    p_name                varchar,
    p_product_category_id uuid,
    p_price               numeric,
    p_restaurant_id       uuid,
    p_photo_url           text                       default null,
    p_rating              numeric                    default null,
    p_status              chernov_food.product_status default 'доступно',
    p_description         text                       default null
)
language plpgsql
as $$
declare
    v_id         uuid;
    v_constraint text;
begin
    if p_restaurant_id is null
       or not exists (select 1 from chernov_food.restaurant r
                      where r.restaurant_id = p_restaurant_id) then
        raise exception 'Ресторан % не существует', p_restaurant_id
            using errcode = '23503';
    end if;

    if p_product_category_id is null
       or not exists (select 1 from chernov_food.product_category c
                      where c.product_category_id = p_product_category_id) then
        raise exception 'Категория % не существует', p_product_category_id
            using errcode = '23503';
    end if;

    v_id := exts.uuid_generate_v4();

    insert into chernov_food.product (
        product_id, product_name, product_category_id, price,
        restaurant_id, photo_url, rating, status, description)
    values (
        v_id, p_name, p_product_category_id, p_price,
        p_restaurant_id, p_photo_url, p_rating, p_status, p_description);

    raise notice 'Блюдо добавлено, product_id = %', v_id;

exception
    when check_violation then
        get stacked diagnostics v_constraint = constraint_name;
        raise exception 'Нарушено ограничение %: проверьте цену (>= 0), рейтинг (0..5), название, описание, photo_url (http/https)',
            v_constraint
            using errcode = '23514';
    when not_null_violation then
        raise exception 'Не заполнено обязательное поле блюда (название, цена, описание): %', sqlerrm
            using errcode = '23502';
    when string_data_right_truncation then
        raise exception 'Значение слишком длинное: %', sqlerrm
            using errcode = '22001';
    when numeric_value_out_of_range then
        raise exception 'Число вне допустимого диапазона: %', sqlerrm
            using errcode = '22003';
end;
$$;