-- Индексы под FK и под отчеты

create index ix_client_address_address on chernov_food.client_address (address_id);
create index ix_product_restaurant on chernov_food.product (restaurant_id);
create index ix_product_category on chernov_food.product (product_category_id);

create index ix_order_courier on chernov_food."order" (courier_id);
create index ix_order_client_address on chernov_food."order" (client_id, address_id);
create index ix_order_address on chernov_food."order" (address_id);
create index ix_order_restaurant on chernov_food."order" (restaurant_id);

create index ix_order_delivered_courier on chernov_food."order" (courier_id, order_timestamp)
    where status = 'доставлен';
create index ix_order_delivered_restaurant on chernov_food."order" (restaurant_id, client_id)
    where status = 'доставлен';

create index ix_payment_order on chernov_food.payment (order_id);
create index ix_order_structure_product on chernov_food.order_structure (product_id);

create index ix_review_client on chernov_food.review (client_id);

create index ix_review_entity on chernov_food.review (entity_type, entity_id);

create index ix_courier_pay_courier on chernov_food.courier_pay (courier_id);