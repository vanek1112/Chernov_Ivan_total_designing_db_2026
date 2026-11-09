-- FOOD-102

create or replace procedure chernov_food.insert_test_data(value int)
language plpgsql
as $$
declare
    -- параметры генерации
    v_n            int  := value;
    v_addr_cnt     int;
    v_products_cnt int;
    v_orders_cnt   int;
    v_reviews_cnt  int;

    v_now          timestamp := localtimestamp(0);
    -- начало первого из 6 месяцев окна и начало следующего месяца
    v_first_month  date := (date_trunc('month', localtimestamp) - interval '5 months')::date;
    v_next_month   date := (date_trunc('month', localtimestamp) + interval '1 month')::date;


    -- значения enum
    v_cs           chernov_food.courier_status[]    := enum_range(null::chernov_food.courier_status);
    v_cs_active    chernov_food.courier_status[];
    v_rs           chernov_food.restaurant_status[] := enum_range(null::chernov_food.restaurant_status);
    v_ps           chernov_food.product_status[]    := enum_range(null::chernov_food.product_status);
    v_os           chernov_food.order_status[]      := enum_range(null::chernov_food.order_status);
    v_os_other     chernov_food.order_status[];
    v_pt           chernov_food.payment_type[]      := enum_range(null::chernov_food.payment_type);


    -- массивы идентификаторов и атрибутов
    v_category_ids    uuid[] := '{}';
    v_courier_ids     uuid[] := '{}';
    v_courier_hire    date[];
    v_courier_dismiss date[];
    v_address_ids     uuid[] := '{}';
    v_rest_addr       uuid[];
    v_client_addr     uuid[];
    v_rest_ids        uuid[];
    v_active_rest_ids uuid[];
    v_client_ids      uuid[] := '{}';
    v_product_ids     uuid[];
    v_order_ids       uuid[];

    v_new_ids      uuid[];
    v_attempt      int;
    v_phone_base   bigint;
    v_orders_json  jsonb;
    v_items_json   jsonb;


    -- справочники
    v_cat_names constant text[] := array['Супы','Горячие блюда','Закуски','Салаты','Пицца',
        'Суши и роллы','Бургеры','Десерты','Напитки','Гарниры','Выпечка','Паста','Гриль'];
    v_surnames constant text[] := array['Иванов','Петров','Сидоров','Смирнов','Кузнецов','Попов',
        'Васильев','Соколов','Михайлов','Новиков','Федоров','Морозов','Волков','Алексеев',
        'Лебедев','Семенов','Егоров','Павлов','Козлов','Степанов'];
    v_names constant text[] := array['Александр','Дмитрий','Максим','Сергей','Андрей','Алексей',
        'Артем','Илья','Кирилл','Михаил','Никита','Матвей','Роман','Егор','Арсений'];
    v_patr constant text[] := array['Александрович','Дмитриевич','Сергеевич','Андреевич',
        'Алексеевич','Иванович','Михайлович','Николаевич','Владимирович','Павлович'];
    v_streets constant text[] := array['ул. Ленина','ул. Пушкина','пр. Мира','ул. Гагарина',
        'ул. Советская','ул. Садовая','ул. Лесная','ул. Школьная','ул. Центральная','ул. Новая',
        'ул. Молодежная','ул. Заводская','пр. Победы','ул. Кирова','ул. Мичурина',
        'ул. Комсомольская','ул. Набережная','ул. Парковая','ул. Первомайская','ул. Октябрьская',
        'ул. Чехова','ул. Горького','ул. Строителей','ул. Речная','ул. Зеленая',
        'ул. Тургенева','ул. Королева','ул. Мира','ул. Дружбы','ул. Солнечная'];
    v_rest_names constant text[] := array['Теплый очаг','Золотой колос','Вкусный дом',
        'Пицца-экспресс','Суши-мастер','Грузинский дворик','Бургерная','Пельменная',
        'Семейная кухня','Шаурма на углу','Нева','Лаваш','Уютный уголок','Сытый волк',
        'Домашняя кухня'];
    v_rest_descr constant text[] := array['Домашняя кухня и быстрая доставка',
        'Авторские блюда от шеф-повара','Классические рецепты с любовью',
        'Свежие ингредиенты каждый день','Готовим быстро и вкусно'];
    v_dishes constant text[] := array['Борщ','Пельмени','Пицца Маргарита','Пицца Пепперони',
        'Ролл Филадельфия','Ролл Калифорния','Бургер классический','Чизбургер','Шаурма куриная',
        'Хинкали','Хачапури по-аджарски','Плов','Лагман','Салат Цезарь','Салат Греческий',
        'Суп-лапша','Солянка','Котлета по-киевски','Стейк из говядины','Паста Карбонара',
        'Паста Болоньезе','Картофель фри','Наггетсы','Блины с мясом','Сырники','Тирамису',
        'Чизкейк','Морс клюквенный','Компот','Лимонад','Том ям','Рамен','Вок с курицей',
        'Овощи гриль','Шашлык из свинины','Люля-кебаб','Окрошка','Уха','Голубцы',
        'Вареники с картошкой'];
    v_dish_descr constant text[] := array['Приготовлено из свежих продуктов',
        'Фирменный рецепт ресторана','Подается горячим','Порция на одного человека',
        'Острое, по желанию без специй','Любимое блюдо наших гостей','Рекомендация шефа'];
    v_order_descr constant text[] := array['без комментариев','позвонить за 10 минут',
        'оставить у двери','не звонить в домофон','пожалуйста, без лука'];
    v_review_txt constant text[] := array['Все понравилось, рекомендую',
        'Было вкусно, доставили вовремя','Нормально, но могло быть лучше','Остыло по дороге',
        'Очень вкусно, закажу еще','Порция маленькая','Отличное качество',
        'Не понравилось, ожидал большего'];
begin
    -- проверка параметра
    if value is null or value < 1 then
        raise exception 'insert_test_data: value должно быть целым числом >= 1 (получено: %)', value
            using errcode = 'invalid_parameter_value';
    end if;

    v_addr_cnt     := v_n * 5;
    v_products_cnt := v_n * 5;
    v_orders_cnt   := v_n * 5;
    v_reviews_cnt  := v_n * 5;
    v_cs_active    := array_remove(v_cs, 'уволен'::chernov_food.courier_status);
    v_os_other     := array_remove(array_remove(v_os, 'доставлен'::chernov_food.order_status),
                                   'отменен'::chernov_food.order_status);


    -- категории блюд
    v_attempt := 0;
    while coalesce(array_length(v_category_ids, 1), 0) < v_n loop
        v_attempt := v_attempt + 1;
        if v_attempt > 200 then
            raise exception 'insert_test_data: не удалось сгенерировать уникальные категории';
        end if;

        with ins as (
            insert into chernov_food.product_category (product_category_id, product_category_name)
            select exts.uuid_generate_v4(),
                   v_cat_names[1 + floor(random() * array_length(v_cat_names, 1))::int]
                       || ' ' || substr(md5(random()::text), 1, 8)
            from generate_series(1, v_n - coalesce(array_length(v_category_ids, 1), 0))
            on conflict do nothing
            returning product_category_id
        )
        select coalesce(array_agg(product_category_id), '{}'::uuid[]) into v_new_ids from ins;

        v_category_ids := v_category_ids || v_new_ids;
    end loop;


    -- курьеры
    v_phone_base := floor(random() * 10000000000)::bigint;

    with b as materialized (
        select g,
               v_surnames[1 + floor(random() * array_length(v_surnames, 1))::int] || ' ' ||
               v_names[1 + floor(random() * array_length(v_names, 1))::int] || ' ' ||
               v_patr[1 + floor(random() * array_length(v_patr, 1))::int]       as fio,
               '+7' || lpad(((v_phone_base + g::bigint * 7919) % 10000000000)::text, 10, '0') as phone,
               v_first_month + floor(random() * 90)::int                         as hire_date,
               case when g = 1
                    then v_cs_active[1 + floor(random() * array_length(v_cs_active, 1))::int]
                    else v_cs[1 + floor(random() * array_length(v_cs, 1))::int]
               end                                                               as status
        from generate_series(1, v_n) g
    ),
    ins as (
        insert into chernov_food.courier
               (courier_id, fio, phone_number, status, hire_date, dismissal_date, coefficient)
        select exts.uuid_generate_v4(), b.fio, b.phone, b.status, b.hire_date,
               case when b.status = 'уволен'
                    then b.hire_date + floor(random() * (current_date - b.hire_date + 1))::int
               end,
               0.1
        from b
        returning courier_id, hire_date, dismissal_date
    )
    select array_agg(courier_id    order by courier_id),
           array_agg(hire_date     order by courier_id),
           array_agg(dismissal_date order by courier_id)
    into v_courier_ids, v_courier_hire, v_courier_dismiss
    from ins;


    -- адреса
    v_attempt := 0;
    while coalesce(array_length(v_address_ids, 1), 0) < v_addr_cnt loop
        v_attempt := v_attempt + 1;
        if v_attempt > 200 then
            raise exception 'insert_test_data: не удалось сгенерировать уникальные адреса';
        end if;

        with ins as (
            insert into chernov_food.address (address_id, street, house_number, apartment_office)
            select exts.uuid_generate_v4(),
                   v_streets[1 + floor(random() * array_length(v_streets, 1))::int],
                   (1 + floor(random() * 300))::int::text ||
                       case when random() < 0.3
                            then '/' || (1 + floor(random() * 9))::int::text
                            else '' end,
                   case when random() < 0.2
                        then null
                        else 'кв. ' || (1 + floor(random() * 300))::int::text end
            from generate_series(1, v_addr_cnt - coalesce(array_length(v_address_ids, 1), 0))
            on conflict do nothing
            returning address_id
        )
        select coalesce(array_agg(address_id), '{}'::uuid[]) into v_new_ids from ins;

        v_address_ids := v_address_ids || v_new_ids;
    end loop;

    v_rest_addr   := v_address_ids[1 : v_n];
    v_client_addr := v_address_ids[v_n + 1 : v_addr_cnt];


    -- рестораны
    with b as materialized (
        select g,
               v_rest_names[1 + floor(random() * array_length(v_rest_names, 1))::int]
                   || ' ' || substr(md5(random()::text), 1, 5)                     as rname,
               time '06:00' + floor(random() * 5)::int * interval '1 hour'         as ws,
               case when g = 1
                    then 'активен'::chernov_food.restaurant_status
                    else v_rs[1 + floor(random() * array_length(v_rs, 1))::int]
               end                                                                 as status
        from generate_series(1, v_n) g
    ),
    ins as (
        insert into chernov_food.restaurant
               (restaurant_id, restaurant_name, address_id, description,
                work_start, work_end, company_details, rating, status)
        select exts.uuid_generate_v4(),
               b.rname,
               v_rest_addr[b.g],
               v_rest_descr[1 + floor(random() * array_length(v_rest_descr, 1))::int],
               b.ws,
               b.ws + (8 + floor(random() * 5))::int * interval '1 hour',
               'ООО «' || b.rname || '», ИНН ' ||
                   lpad(floor(random() * 10000000000)::bigint::text, 10, '0') ||
                   ', ОГРН ' || lpad(floor(random() * 10000000000000)::bigint::text, 13, '0'),
               null::numeric,
               b.status
        from b
        returning restaurant_id, status
    )
    select array_agg(restaurant_id),
           array_agg(restaurant_id) filter (where status = 'активен')
    into v_rest_ids, v_active_rest_ids
    from ins;


    -- клиенты
    v_attempt := 0;
    while coalesce(array_length(v_client_ids, 1), 0) < v_n loop
        v_attempt := v_attempt + 1;
        if v_attempt > 200 then
            raise exception 'insert_test_data: не удалось сгенерировать уникальных клиентов';
        end if;
        v_phone_base := floor(random() * 10000000000)::bigint;

        with ins as (
            insert into chernov_food.client (client_id, login, password, phone_number)
            select exts.uuid_generate_v4(),
                   'user_' || substr(md5(random()::text || clock_timestamp()::text || g::text), 1, 16),
                   md5(random()::text),
                   '+7' || lpad(((v_phone_base + g::bigint * 7919) % 10000000000)::text, 10, '0')
            from generate_series(1, v_n - coalesce(array_length(v_client_ids, 1), 0)) g
            on conflict do nothing
            returning client_id
        )
        select coalesce(array_agg(client_id), '{}'::uuid[]) into v_new_ids from ins;

        v_client_ids := v_client_ids || v_new_ids;
    end loop;


    -- пары клиент-адрес
    insert into chernov_food.client_address (client_id, address_id)
    select v_client_ids[((g - 1) / 4) + 1], v_client_addr[g]
    from generate_series(1, v_n * 4) g;


    -- блюда
    with ins as (
        insert into chernov_food.product
               (product_id, product_name, product_category_id, price,
                restaurant_id, photo_url, rating, status, description)
        select exts.uuid_generate_v4(),
               v_dishes[1 + floor(random() * array_length(v_dishes, 1))::int],
               v_category_ids[1 + floor(random() * array_length(v_category_ids, 1))::int],
               round((50 + random() * 1450)::numeric, 2),
               case when g <= v_n
                    then v_rest_ids[g]
                    else v_rest_ids[1 + floor(random() * array_length(v_rest_ids, 1))::int]
               end,
               case when random() < 0.6
                    then null
                    else 'https://img.example.com/product/' || md5(random()::text) || '.jpg'
               end,
               null::numeric,
               case when g <= v_n
                    then 'доступно'::chernov_food.product_status
                    else v_ps[1 + floor(random() * array_length(v_ps, 1))::int]
               end,
               v_dish_descr[1 + floor(random() * array_length(v_dish_descr, 1))::int]
        from generate_series(1, v_products_cnt) g
        returning product_id
    )
    select array_agg(product_id) into v_product_ids from ins;


    -- планирование заказов и их состава
    with o0 as materialized (
        select exts.uuid_generate_v4()                                         as order_id,
               1 + floor(random() * v_n)::int                                  as c_idx,
               1 + floor(random() * array_length(v_active_rest_ids, 1))::int   as r_idx,
               1 + floor(random() * array_length(v_courier_ids, 1))::int       as k_idx,
               1 + floor(random() * 4)::int                                    as a_off,
               1 + floor(random() * 5)::int                                    as k,
               random()                                                        as r_ts,
               random()                                                        as r_st,
               random()                                                        as r_dl,
               1 + floor(random() * array_length(v_order_descr, 1))::int       as d_idx,
               1 + floor(random() * array_length(v_os_other, 1))::int          as s_idx
        from generate_series(1, v_orders_cnt)
    ),
    o1 as materialized (
        select o0.*,
               v_client_ids[o0.c_idx]                                           as client_id,
               v_client_addr[(o0.c_idx - 1) * 4 + o0.a_off]                     as address_id,
               v_active_rest_ids[o0.r_idx]                                      as restaurant_id,
               v_courier_ids[o0.k_idx]                                          as courier_id,
               greatest(v_first_month::timestamp, v_courier_hire[o0.k_idx]::timestamp) as lo,
               least(v_now,
                     coalesce((v_courier_dismiss[o0.k_idx] + 1)::timestamp - interval '1 second',
                              v_now))                                           as hi
        from o0
    ),
    o2 as materialized (
        select o1.*,
               date_trunc('second',
                          o1.lo + (greatest(o1.hi, o1.lo) - o1.lo) * o1.r_ts)  as order_ts,
               case when o1.r_st < 0.60 then 'доставлен'::chernov_food.order_status
                    when o1.r_st < 0.65 then 'отменен'::chernov_food.order_status
                    else v_os_other[o1.s_idx]
               end                                                              as status
        from o1
    ),
    ord as materialized (
        select o2.*,
               case when o2.status = 'доставлен'
                    then date_trunc('second',
                             least(o2.order_ts + interval '20 minutes' + interval '100 minutes' * o2.r_dl,
                                   greatest(o2.hi, o2.order_ts)))
               end                                                              as delivery_ts,
               v_order_descr[o2.d_idx]                                          as description
        from o2
    ),
    items as materialized (
        select ord.order_id,
               p.product_id,
               p.price,
               ord.k,
               row_number() over (partition by ord.order_id order by random())  as rn,
               round(0.5 + (floor(random() * 6))::int * 0.5, 3)                 as qty
        from ord
        join chernov_food.product p on p.restaurant_id = ord.restaurant_id
        join unnest(v_product_ids) as pid(id) on pid.id = p.product_id
        where p.status = 'доступно'
    ),
    picked as materialized (
        select i.order_id, i.product_id, i.price, i.rn, i.qty,
               sum(i.price * i.qty) over (partition by i.order_id) as raw_total
        from items i
        where i.rn <= i.k
    ),
    fin as materialized (
        select pk.order_id, pk.product_id,
               case when pk.rn = 1 and pk.raw_total < 1000
                    then pk.qty + ceil((1000 - pk.raw_total) / pk.price)
                    else pk.qty
               end as qty,
               pk.price
        from picked pk
    ),
    am as materialized (
        select f.order_id, round(sum(f.price * f.qty), 2) as order_amount
        from fin f
        group by f.order_id
    )
    select (select jsonb_agg(jsonb_build_object(
                       'order_id',           ord.order_id,
                       'courier_id',         ord.courier_id,
                       'client_id',          ord.client_id,
                       'address_id',         ord.address_id,
                       'restaurant_id',      ord.restaurant_id,
                       'order_timestamp',    ord.order_ts,
                       'delivery_timestamp', ord.delivery_ts,
                       'order_amount',       am.order_amount,
                       'status',             ord.status,
                       'description',        ord.description))
            from ord join am on am.order_id = ord.order_id),
           (select jsonb_agg(jsonb_build_object(
                       'order_id',   f.order_id,
                       'product_id', f.product_id,
                       'quantity',   f.qty))
            from fin f)
      into v_orders_json, v_items_json;


    -- "order" и order_structure
    with ins as (
        insert into chernov_food."order"
               (order_id, courier_id, client_id, address_id, restaurant_id,
                order_timestamp, delivery_timestamp,
                order_amount, commission, total_amount,
                status, pay_status, description)
        select x.order_id, x.courier_id, x.client_id, x.address_id, x.restaurant_id,
               x.order_timestamp, x.delivery_timestamp,
               x.order_amount,
               round(x.order_amount * 0.10, 2),
               x.order_amount + round(x.order_amount * 0.10, 2),
               x.status,
               'оплачен'::chernov_food.order_pay_status,
               x.description
        from jsonb_to_recordset(v_orders_json) as x(
                   order_id uuid, courier_id uuid, client_id uuid, address_id uuid,
                   restaurant_id uuid, order_timestamp timestamp, delivery_timestamp timestamp,
                   order_amount numeric, status chernov_food.order_status, description text)
        returning order_id
    )
    select array_agg(order_id) into v_order_ids from ins;

    insert into chernov_food.order_structure (order_id, product_id, quantity)
    select x.order_id, x.product_id, x.quantity
    from jsonb_to_recordset(v_items_json) as x(order_id uuid, product_id uuid, quantity numeric);


    -- оплаты
    insert into chernov_food.payment
           (payment_id, order_id, payment_type, amount, transaction_id, payment_timestamp, status)
    select exts.uuid_generate_v4(),
           o.order_id,
           v_pt[1 + floor(random() * array_length(v_pt, 1))::int],
           o.total_amount,
           exts.uuid_generate_v4(),
           date_trunc('second', least(o.order_timestamp + random() * interval '10 minutes',
                                      v_now)),
           'успех'::chernov_food.payment_status
    from chernov_food."order" o
    join unnest(v_order_ids) as u(id) on u.id = o.order_id;


    -- отзывы
    insert into chernov_food.review
           (review_id, client_id, review_timestamp, entity_id, entity_type,
            order_id, description, photo_url, rating)
    select exts.uuid_generate_v4(),
           s.client_id,
           date_trunc('second',
                      least(coalesce(s.delivery_timestamp, s.order_timestamp)
                                + random() * interval '3 days',
                            v_now)),
           s.entity_id,
           s.entity_type,
           s.order_id,
           v_review_txt[1 + floor(random() * array_length(v_review_txt, 1))::int],
           case when random() < 0.7
                then null
                else 'https://img.example.com/review/' || md5(random()::text) || '.jpg'
           end,
           1 + floor(random() * 5)::int
    from (
          select o.order_id, o.client_id, o.status,
                 o.order_timestamp, o.delivery_timestamp,
                 sl.entity_type, sl.entity_id
          from chernov_food."order" o
          join unnest(v_order_ids) as u(id) on u.id = o.order_id
          cross join lateral (
                 select 'заказ'::chernov_food.review_entity_type as entity_type, o.order_id as entity_id
                 union all
                 select 'ресторан'::chernov_food.review_entity_type, o.restaurant_id
                 union all
                 select 'блюдо'::chernov_food.review_entity_type, os.product_id
                 from chernov_food.order_structure os
                 where os.order_id = o.order_id
                   ) sl
          order by (o.status <> 'доставлен'), random()
          limit v_reviews_cnt
    ) s;


    -- выплаты курьерам
    with months as (
        select (v_first_month + i * interval '1 month')::date as m_start
        from generate_series(0, 5) i
    ),
    cnt as (
        select o.courier_id,
               date_trunc('month', o.order_timestamp)::date as m_start,
               count(*)            as cnt,
               sum(o.commission)   as commission_sum
        from chernov_food."order" o
        join unnest(v_courier_ids) as u(id) on u.id = o.courier_id
        where o.status = 'доставлен'
        group by o.courier_id, date_trunc('month', o.order_timestamp)::date
    ),
    cr as (
        select t.courier_id, date_trunc('month', t.dismissal_date)::date as dism_month
        from unnest(v_courier_ids, v_courier_dismiss) as t(courier_id, dismissal_date)
    )
    insert into chernov_food.courier_pay (year, month, courier_id, amount, coefficient_used)
    select extract(year  from m.m_start)::int,
           extract(month from m.m_start)::int,
           cr.courier_id,
           round(coalesce(cur.commission_sum, 0) * k.coef, 2),
           k.coef
    from months m
    cross join cr
    left join cnt cur on cur.courier_id = cr.courier_id and cur.m_start = m.m_start
    left join cnt prv on prv.courier_id = cr.courier_id
       and prv.m_start = (least(m.m_start, coalesce(cr.dism_month, m.m_start)) - interval '1 month')::date
    cross join lateral (
           select (case when coalesce(prv.cnt, 0) > 500 then 0.5
                        when coalesce(prv.cnt, 0) > 250 then 0.3
                        when coalesce(prv.cnt, 0) > 150 then 0.2
                        else 0.1 end)::numeric(3,2) as coef
           ) k;


    -- коэффициенты
    with cnt as (
        select o.courier_id,
               date_trunc('month', o.order_timestamp)::date as m_start,
               count(*) as cnt
        from chernov_food."order" o
        join unnest(v_courier_ids) as u(id) on u.id = o.courier_id
        where o.status = 'доставлен'
        group by o.courier_id, date_trunc('month', o.order_timestamp)::date
    ),
    cr as (
        select t.courier_id, date_trunc('month', t.dismissal_date)::date as dism_month
        from unnest(v_courier_ids, v_courier_dismiss) as t(courier_id, dismissal_date)
    )
    update chernov_food.courier cu
    set coefficient = (case when coalesce(p.cnt, 0) > 500 then 0.5
                            when coalesce(p.cnt, 0) > 250 then 0.3
                            when coalesce(p.cnt, 0) > 150 then 0.2
                            else 0.1 end)
    from cr
    left join cnt p on p.courier_id = cr.courier_id
       and p.m_start = (least(v_next_month, coalesce(cr.dism_month, v_next_month)) - interval '1 month')::date
    where cu.courier_id = cr.courier_id;

    raise notice 'insert_test_data(%): client=%, courier=%, category=%, restaurant=%, address=%, product=%, order=%, payment=%, review=%',
        v_n, v_n, v_n, v_n, v_n, v_addr_cnt, v_products_cnt, v_orders_cnt, v_orders_cnt, v_reviews_cnt;
end;
$$;