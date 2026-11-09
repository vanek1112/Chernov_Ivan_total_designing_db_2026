-- FOOD-101

create schema if not exists exts;

create extension if not exists "uuid-ossp" with schema exts;


create table chernov_food.client (
    client_id    uuid        not null default exts.uuid_generate_v4(),
    login        varchar(50) not null,
    password     varchar(32) not null,
    phone_number char(12)    not null,
    constraint pk_client             primary key (client_id),
    constraint uq_client_login       unique (login),
    constraint uq_client_phone       unique (phone_number),
    constraint ck_client_login_not_blank check (btrim(login) <> ''),
    constraint ck_client_password_md5    check (password ~ '^[0-9a-f]{32}$'),
    constraint ck_client_phone_format    check (phone_number ~ '^\+7[0-9]{10}$')
);


create table chernov_food.address (
    address_id       uuid         not null default exts.uuid_generate_v4(),
    street           varchar(100) not null,
    house_number     varchar(10)  not null,
    apartment_office varchar(10),
    constraint pk_address primary key (address_id),
    constraint uq_address_physical unique nulls not distinct (street, house_number, apartment_office),
    constraint ck_address_street_not_blank    check (btrim(street) <> ''),
    constraint ck_address_house_not_blank     check (btrim(house_number) <> ''),
    constraint ck_address_apartment_not_blank check (apartment_office is null or btrim(apartment_office) <> '')
);


create table chernov_food.client_address (
    client_id  uuid not null,
    address_id uuid not null,
    constraint pk_client_address        primary key (client_id, address_id),
    constraint fk_client_address_client  foreign key (client_id)
        references chernov_food.client (client_id)   on delete cascade,
    constraint fk_client_address_address foreign key (address_id)
        references chernov_food.address (address_id) on delete restrict
);


create table chernov_food.restaurant (
    restaurant_id   uuid         not null default exts.uuid_generate_v4(),
    restaurant_name varchar(100) not null,
    address_id      uuid         not null,
    description     text         not null,
    work_start      time         not null,
    work_end        time         not null,
    company_details text         not null,
    rating          numeric(3,2),
    status          chernov_food.restaurant_status not null default 'активен',
    constraint pk_restaurant         primary key (restaurant_id),
    constraint uq_restaurant_address unique (address_id),
    constraint fk_restaurant_address foreign key (address_id)
        references chernov_food.address (address_id) on delete restrict,
    constraint ck_restaurant_name_not_blank    check (btrim(restaurant_name) <> ''),
    constraint ck_restaurant_descr_not_blank   check (btrim(description) <> ''),
    constraint ck_restaurant_details_not_blank check (btrim(company_details) <> ''),
    constraint ck_restaurant_work_hours        check (work_end > work_start),
    constraint ck_restaurant_rating            check (rating between 0 and 5)
);


create table chernov_food.courier (
    courier_id     uuid         not null default exts.uuid_generate_v4(),
    fio            varchar(150) not null,
    phone_number   char(12)     not null,
    status         chernov_food.courier_status not null default 'свободен',
    hire_date      date         not null default current_date,
    dismissal_date date,
    coefficient    numeric(3,2) not null default 0.1,
    constraint pk_courier primary key (courier_id),
    constraint ck_courier_fio_not_blank        check (btrim(fio) <> ''),
    constraint ck_courier_phone_format         check (phone_number ~ '^\+7[0-9]{10}$'),
    constraint ck_courier_dismissal_required   check (status <> 'уволен' or dismissal_date is not null),
    constraint ck_courier_dismissal_after_hire check (dismissal_date is null or dismissal_date >= hire_date),
    constraint ck_courier_coefficient_range    check (coefficient between 0.1 and 0.5)
);


create table chernov_food.courier_pay (
    year             int          not null,
    month            int          not null,
    courier_id       uuid         not null,
    amount           numeric(12,2) not null,
    coefficient_used numeric(3,2)  not null,
    constraint pk_courier_pay primary key (year, month, courier_id),
    constraint fk_courier_pay_courier foreign key (courier_id)
        references chernov_food.courier (courier_id) on delete restrict,
    constraint ck_courier_pay_year   check (year between 2000 and 2100),
    constraint ck_courier_pay_month  check (month between 1 and 12),
    constraint ck_courier_pay_amount check (amount >= 0),
    constraint ck_courier_pay_coef   check (coefficient_used between 0.1 and 0.5)
);


create table chernov_food.product_category (
    product_category_id   uuid         not null default exts.uuid_generate_v4(),
    product_category_name varchar(100) not null,
    constraint pk_product_category      primary key (product_category_id),
    constraint uq_product_category_name unique (product_category_name),
    constraint ck_product_category_name_not_blank check (btrim(product_category_name) <> '')
);


create table chernov_food.product (
    product_id          uuid          not null default exts.uuid_generate_v4(),
    product_name        varchar(150)  not null,
    product_category_id uuid          not null,
    price               numeric(10,2) not null,
    restaurant_id       uuid          not null,
    photo_url           text,
    rating              numeric(3,2),
    status              chernov_food.product_status not null default 'доступно',
    description         text          not null,
    constraint pk_product primary key (product_id),
    constraint fk_product_category   foreign key (product_category_id)
        references chernov_food.product_category (product_category_id) on delete restrict,
    constraint fk_product_restaurant foreign key (restaurant_id)
        references chernov_food.restaurant (restaurant_id) on delete restrict,
    constraint ck_product_name_not_blank  check (btrim(product_name) <> ''),
    constraint ck_product_descr_not_blank check (btrim(description) <> ''),
    constraint ck_product_price           check (price >= 0),
    constraint ck_product_rating          check (rating between 0 and 5),
    constraint ck_product_photo_url       check (photo_url is null or photo_url ~ '^https?://\S+$')
);


create table chernov_food."order" (
    order_id           uuid          not null default exts.uuid_generate_v4(),
    courier_id         uuid          not null,
    client_id          uuid          not null,
    address_id         uuid          not null,
    restaurant_id      uuid          not null,
    order_timestamp    timestamp     not null default localtimestamp,
    delivery_timestamp timestamp,
    order_amount       numeric(12,2) not null,
    commission         numeric(12,2) not null,
    total_amount       numeric(12,2) not null,
    status             chernov_food.order_status     not null default 'создан',
    pay_status         chernov_food.order_pay_status not null default 'ожидает',
    description        text          not null default 'без комментариев',
    constraint pk_order primary key (order_id),
    constraint uq_order_id_client unique (order_id, client_id),
    constraint uq_order_id_total  unique (order_id, total_amount),
    constraint fk_order_courier    foreign key (courier_id)
        references chernov_food.courier (courier_id)       on delete restrict,
    constraint fk_order_client     foreign key (client_id)
        references chernov_food.client (client_id)         on delete restrict,
    constraint fk_order_address    foreign key (address_id)
        references chernov_food.address (address_id)       on delete restrict,
    constraint fk_order_restaurant foreign key (restaurant_id)
        references chernov_food.restaurant (restaurant_id) on delete restrict,
    constraint fk_order_client_address foreign key (client_id, address_id)
        references chernov_food.client_address (client_id, address_id) on delete restrict,
    constraint ck_order_commission      check (commission = round(order_amount * 0.10, 2)),
    constraint ck_order_total           check (total_amount = order_amount + commission),
    constraint ck_order_min_total       check (total_amount >= 1000),
    constraint ck_order_delivery_required check (status <> 'доставлен' or delivery_timestamp is not null),
    constraint ck_order_delivery_after_create check (delivery_timestamp is null or delivery_timestamp >= order_timestamp),
    constraint ck_order_description_not_blank check (btrim(description) <> '')
);


create table chernov_food.payment (
    payment_id        uuid          not null default exts.uuid_generate_v4(),
    order_id          uuid          not null,
    payment_type      chernov_food.payment_type   not null,
    amount            numeric(12,2) not null,
    transaction_id    uuid   		not null,
    payment_timestamp timestamp     not null default localtimestamp,
    status            chernov_food.payment_status not null default 'в_обработке',
    constraint pk_payment primary key (payment_id),
    constraint uq_payment_transaction unique (transaction_id),
    constraint fk_payment_order foreign key (order_id)
        references chernov_food."order" (order_id) on delete restrict,
    constraint fk_payment_order_amount foreign key (order_id, amount)
        references chernov_food."order" (order_id, total_amount) on delete restrict,
    constraint ck_payment_amount_positive check (amount > 0),
);


create unique index uq_payment_one_success
    on chernov_food.payment (order_id) where status = 'успех';


create table chernov_food.order_structure (
    order_id   uuid         not null,
    product_id uuid         not null,
    quantity   numeric(8,3) not null,
    constraint pk_order_structure primary key (order_id, product_id),
    constraint fk_order_structure_order   foreign key (order_id)
        references chernov_food."order" (order_id) on delete cascade,
    constraint fk_order_structure_product foreign key (product_id)
        references chernov_food.product (product_id) on delete restrict,
    constraint ck_order_structure_quantity check (quantity > 0)
);


create table chernov_food.review (
    review_id        uuid      not null default exts.uuid_generate_v4(),
    client_id        uuid      not null,
    review_timestamp timestamp not null default localtimestamp,
    entity_id        uuid      not null,
    entity_type      chernov_food.review_entity_type not null,
    order_id         uuid      not null,
    description      text      not null,
    photo_url        text,
    rating           numeric(3,2) not null,
    constraint pk_review primary key (review_id),
    constraint fk_review_client foreign key (client_id)
        references chernov_food.client (client_id) on delete restrict,
    constraint fk_review_order foreign key (order_id)
        references chernov_food."order" (order_id) on delete restrict,
    constraint fk_review_order_client foreign key (order_id, client_id)
        references chernov_food."order" (order_id, client_id) on delete restrict,
    constraint uq_review_once_per_entity unique (order_id, entity_type, entity_id),
    constraint ck_review_rating      check (rating between 1 and 5),
    constraint ck_review_descr_not_blank check (btrim(description) <> ''),
    constraint ck_review_photo_url   check (photo_url is null or photo_url ~ '^https?://\S+$')
);