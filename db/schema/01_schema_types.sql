create schema if not exists chernov_food;

create type chernov_food.restaurant_status as enum ('активен', 'неактивен');

create type chernov_food.product_status as enum ('доступно', 'нет_в_наличии', 'архив');

create type chernov_food.courier_status as enum ('свободен', 'занят', 'на_доставке', 'уволен');

create type chernov_food.order_status as enum ('создан', 'готовится', 'в_доставке', 'доставлен', 'отменен');

create type chernov_food.order_pay_status as enum ('ожидает', 'оплачен', 'ошибка');

create type chernov_food.payment_status as enum ('успех', 'ошибка', 'в_обработке');

create type chernov_food.payment_type as enum ('карта', 'наличные', 'безнал');

create type chernov_food.review_entity_type as enum ('блюдо', 'ресторан', 'заказ');