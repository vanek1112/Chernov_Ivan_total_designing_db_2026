# Обоснование ограничений схемы chernov_food

## Как заполнять (соглашения этого документа)

- Каждое ограничение `CHECK`, `UNIQUE`, `FOREIGN KEY` обосновано ссылкой на точный пункт `BR-N.M` из `docs/company-rules.md`.
- Формат обоснования: «<что ограничиваем> - потому что <BR-N.M> требует <что>».
- Тикет по умолчанию - FOOD-101 (схема). Если ограничение относится к другому тикету, это указано явно (FOOD-104, FOOD-105).
- `NOT NULL` описан только там, где бизнес явно требует обязательность. Очевидное (PK, FK) не дублируется.
- Каждый `NULL` описан как осознанное решение.
- Обоснований «здравым смыслом» без номера BR нет. Если ограничение выходит за рамки BR, оно помечено как «расширение» и вынесено в раздел «Нормализация / расширения».
- Общие основания для всей схемы: BR-11.1 (UUID), BR-11.3 (`NULL` только где разрешено), BR-11.4 (уникальность и непустота на уровне схемы), BR-11.5 (enum через `CREATE TYPE`), BR-11.6 (длины и точность на усмотрение, с обоснованием).

## Enum-типы

| Тип | Значения | BR |
|---|---|---|
| `restaurant_status` | `активен`, `неактивен` | BR-4.3, BR-11.5 |
| `product_status` | `доступно`, `нет_в_наличии`, `архив` | BR-5.5, BR-11.5 |
| `courier_status` | `свободен`, `занят`, `на_доставке`, `уволен` | BR-6.2, BR-11.5 |
| `order_status` | `создан`, `готовится`, `в_доставке`, `доставлен`, `отменен` | BR-7.6, BR-7.7, BR-11.5 |
| `order_pay_status` | `ожидает`, `оплачен`, `ошибка` | BR-7.8, BR-7.9, BR-8.7, BR-11.5 |
| `payment_status` | `успех`, `ошибка`, `в_обработке` | BR-8.2, BR-11.5 |
| `payment_type` | `карта`, `наличные`, `безнал` | BR-8.2, BR-8.6, BR-11.5 |
| `review_entity_type` | `блюдо`, `ресторан`, `заказ` | BR-9.1, BR-11.5 |

## Ловушки 1–4

### Ловушка 1. Атрибуты `payment` и тип оплаты

В ERD у таблицы `payment` есть только `payment_id` и `order_id`. Правило BR-8.2 требует хранить для каждой попытки оплаты тип, сумму, ID транзакции, дату и время, а также статус, поэтому я добавил колонки `payment_type`, `amount`, `transaction_id`, `payment_timestamp` и `status`.

Тип оплаты хранится именно в `payment`, а не в `order`. BR-8.6 прямо говорит, что тип относится к попытке, а не к заказу. Благодаря этому у одного заказа может быть несколько попыток с разными типами оплаты (BR-8.1).

Поле `order.pay_status` не самостоятельное, а сводка по попыткам (BR-7.8, BR-8.7). Его поддерживает триггер `trg_payment_sync_order_pay_status`, то есть если есть успешная попытка, статус заказа `оплачен`; если все попытки завершились ошибкой, статус `ошибка`; во всех остальных случаях `ожидает`.

Сумма каждой попытки должна совпадать с общей суммой заказа (BR-8.4). Это гарантирует составной внешний ключ `fk_payment_order_amount (order_id, amount) - "order"(order_id, total_amount)`.

В самих требованиях есть противоречие. BR-8.1 говорит, что «ровно одна из них - успешная», а BR-8.7 допускает статус заказа `ошибка`, когда «все попытки завершились ошибкой», то есть успешных нет вообще. Я выбрал условие «не более одной успешной попытки» и реализовал его частичным уникальным индексом `uq_payment_one_success`.

### Ловушка 2. Адрес доставки должен принадлежать клиенту заказа (BR-7.4)

Обычного внешнего ключа `order.address_id - address` недостаточно: он проверяет только, что такой адрес существует, но не что он принадлежит клиенту, оформившему заказ. Поэтому добавлен составной внешний ключ `fk_order_client_address (client_id, address_id) - client_address(client_id, address_id)`. Простой `fk_order_address` я оставил, потому что он есть в ERD и составному не противоречит.

### Ловушка 3. Все блюда заказа из ресторана этого заказа (BR-7.3)

Выразить это правило составным внешним ключом не получится без дублирования `restaurant_id` в `order_structure`. Такое дублирование нарушило бы вторую нормальную форму, потому что `restaurant_id` зависит только от `order_id`, а не от всего ключа `(order_id, product_id)`. Поэтому правило реализовано триггерами.

Основной триггер `trg_order_structure_same_restaurant` срабатывает при вставке и изменении позиций заказа и проверяет, что блюдо принадлежит тому же ресторану, что и заказ. Одной этой проверки мало: правило можно было бы обойти, изменив родительскую строку уже после добавления позиций. Для этого есть два защитных триггера. `trg_order_restaurant_guard` на таблице `"order"` не позволяет сменить ресторан у заказа, в котором уже есть позиции или отзывы (BR-7.3, BR-9.2). `trg_product_restaurant_guard` на таблице `product` не позволяет перенести в другой ресторан блюдо, которое уже входит в заказы (BR-7.3).

### Ловушка 4. Полиморфный отзыв (BR-9.1)

Отзыв может относиться к блюду, к ресторану или к заказу, поэтому на пару `review.entity_id` (uuid) и `review.entity_type` (`review_entity_type`) нельзя повесить обычный внешний ключ: он не знает, в какую таблицу смотреть. Целостность обеспечивает триггер `trg_review_entity_check`. Если отзыв на блюдо, оно должно входить в состав заказа; если на ресторан, это должен быть ресторан этого заказа (в обоих случаях BR-9.2); если на заказ, то `entity_id` равен `order_id`.

Кроме того, отзыв всегда связан с заказом того же клиента, который его написал (BR-9.2). Это обеспечивает составной внешний ключ `fk_review_order_client (order_id, client_id) - "order"(order_id, client_id)`, для которого в `"order"` создан `uq_order_id_client`. Триггер `trg_order_structure_review_guard` дополнительно не дает удалить или изменить позицию заказа, на которую уже написан отзыв (BR-9.2).

Я рассматривал и отверг нормализацию через три отдельные таблицы отзывов (на блюдо, ресторан и заказ). Она размножила бы схему и сломала бы правило «один отзыв на объект в заказе» (BR-9.5), которое сейчас выражено одним ограничением `UNIQUE`.

## CHECK

| Таблица | Ограничение | Условие | BR | Обоснование |
|---|---|---|---|---|
| client | `ck_client_login_not_blank` | `btrim(login) <> ''` | BR-2.1, BR-11.4 | Пользователь регистрируется по логину, стало быть пустым он быть не может. |
| client | `ck_client_password_md5` | `password ~ '^[0-9a-f]{32}$'` | BR-2.3 | Пароль хранится только как md5-хеш, а не открытым текстом. `md5()` дает ровно 32 hex-символа. |
| client | `ck_client_phone_format` | `phone_number ~ '^\+7[0-9]{10}$'` | BR-1.2, BR-2.1, BR-11.6 | Пользователь регистрируется в том числе и по логину, стало быть пустым он быть не может (BR-2.1). Агрегатор работает в одном городе (BR-1.2), соответственно в одной стране и, стало быть, для номера лишь 1 код региона (РФ, выбрано мной, пользуясь правилом BR-11.6) + все номера состоят из 10 символов, итого 12 в общей сумме (`char(12)`). |
| address | `ck_address_street_not_blank` | `btrim(street) <> ''` | BR-3.1, BR-11.4 | Улица обязательна. |
| address | `ck_address_house_not_blank` | `btrim(house_number) <> ''` | BR-3.1, BR-11.4 | Дом обязателен. |
| address | `ck_address_apartment_not_blank` | `apartment_office IS NULL OR btrim(apartment_office) <> ''` | BR-3.2, BR-11.3 | Кв./офис необязательна, их отсутствие выражается `NULL`, а не пустой строкой. |
| restaurant | `ck_restaurant_name_not_blank` | `btrim(restaurant_name) <> ''` | BR-4.1, BR-11.4 | Название обязательно. |
| restaurant | `ck_restaurant_descr_not_blank` | `btrim(description) <> ''` | BR-4.1, BR-11.4 | Описание обязательно. |
| restaurant | `ck_restaurant_details_not_blank` | `btrim(company_details) <> ''` | BR-4.1, BR-4.5, BR-11.4 | Реквизиты (юридическая информация) обязательны. |
| restaurant | `ck_restaurant_work_hours` | `work_end > work_start` | BR-4.4 | Закрытие строго позже открытия. |
| restaurant | `ck_restaurant_rating` | `rating IS NULL OR rating BETWEEN 0 AND 5` | BR-4.2, BR-9.7 | Диапазон 0..5. `NULL` - нет отзывов. |
| courier | `ck_courier_fio_not_blank` | `btrim(fio) <> ''` | BR-6.1, BR-11.4 | ФИО курьера обязательно. ФИО клиента нет (BR-2.6), это относится только к курьеру. |
| courier | `ck_courier_phone_format` | как у клиента | BR-6.1, BR-11.6 | Единый формат телефона. |
| courier | `ck_courier_dismissal_required` | если `status = 'уволен'`, то `dismissal_date IS NOT NULL` | BR-6.3 | Уволенный обязан иметь дату увольнения. |
| courier | `ck_courier_dismissal_after_hire` | `dismissal_date IS NULL OR dismissal_date >= hire_date` | BR-6.1, BR-6.3 | Дата увольнения не раньше найма. |
| courier | `ck_courier_coefficient_range` | `coefficient BETWEEN 0.1 AND 0.5` | BR-6.4 | Допустимые коэффициенты. |
| courier_pay | `ck_courier_pay_year` | `year BETWEEN 2000 AND 2100` | BR-10.1, BR-10.3 | Выплата раз в месяц, год - часть ключа. Границы - защита от опечаток (BR-11.6). |
| courier_pay | `ck_courier_pay_month` | `month BETWEEN 1 AND 12` | BR-10.1, BR-10.3 | Месяц - часть ключа. |
| courier_pay | `ck_courier_pay_amount` | `amount >= 0` | BR-10.4 | Зарплата неотрицательна. |
| courier_pay | `ck_courier_pay_coef` | `coefficient_used BETWEEN 0.1 AND 0.5` | BR-6.4, BR-10.2 | Примененный коэффициент берется из того же диапазона. |
| product_category | `ck_product_category_name_not_blank` | `btrim(...) <> ''` | BR-5.7, BR-11.4 | Название категории обязательно. |
| product | `ck_product_name_not_blank` | `btrim(product_name) <> ''` | BR-5.2, BR-11.4 | Название обязательно. |
| product | `ck_product_descr_not_blank` | `btrim(description) <> ''` | BR-5.2, BR-11.4 | Описание обязательно. |
| product | `ck_product_price` | `price >= 0` | BR-5.3 | Цена неотрицательна. |
| product | `ck_product_rating` | `rating IS NULL OR rating BETWEEN 0 AND 5` | BR-5.4, BR-9.7 | Диапазон 0..5. `NULL` - нет отзывов. |
| product | `ck_product_photo_url` | `photo_url IS NULL OR photo_url ~* '^https?://'` | BR-5.6 | Фото - URL, необязательно. |
| "order" | `ck_order_commission` | `commission = round(order_amount * 0.10, 2)` | BR-7.10, BR-1.4 | Комиссия - 10% от суммы блюд. |
| "order" | `ck_order_total` | `total_amount = order_amount + commission` | BR-7.10, BR-1.5 | Клиент платит блюда плюс комиссию. |
| "order" | `ck_order_min_total` | `total_amount >= 1000` | BR-7.11, BR-1.8 | Минимальная сумма заказа. |
| "order" | `ck_order_delivery_required` | если `status = 'доставлен'`, то `delivery_timestamp IS NOT NULL` | BR-7.12 | Время окончания доставки заполняется при статусе «доставлен». |
| "order" | `ck_order_delivery_after_create` | `delivery_timestamp IS NULL OR delivery_timestamp >= order_timestamp` | BR-7.13 | Доставка не раньше создания. |
| "order" | `ck_order_description_not_blank` | `btrim(description) <> ''` | BR-11.4 | Комментарий не должен быть пустой строкой. При отсутствии комментария - `NULL`. |
| payment | `ck_payment_amount_positive` | `amount > 0` | BR-8.4, BR-1.8 | Сумма попытки равна общей сумме заказа (больше либо равно 1000), нулевых платежей нет. |
| order_structure | `ck_order_structure_quantity` | `quantity > 0` | BR-7.15 | Количество положительное, может быть дробным (`numeric(8,3)`). |
| review | `ck_review_rating` | `rating BETWEEN 1 AND 5` | BR-9.4 | Оценка отзыва 1..5. Диапазон 0..5 у агрегатов (BR-4.2, BR-5.4) - другое правило. |
| review | `ck_review_descr_not_blank` | `btrim(description) <> ''` | BR-9.3, BR-11.4 | Текст отзыва обязателен. |
| review | `ck_review_photo_url` | `photo_url IS NULL OR photo_url ~* '^https?://'` | BR-9.3 | Фото необязательно. Если есть - URL, в противном случае - `NULL`. |

## UNIQUE

| Таблица | Ограничение | Столбцы | BR | Обоснование |
|---|---|---|---|---|
| client | `uq_client_login` | `login` | BR-2.2 | Логин уникален. |
| client | `uq_client_phone` | `phone_number` | BR-2.2 | Телефон уникален. |
| address | `uq_address_physical` (`NULLS NOT DISTINCT`) | `street, house_number, apartment_office` | BR-2.4, BR-3.4 | Адрес - общая сущность: один адрес у разных клиентов. Поэтому физический адрес хранится один раз. `NULLS NOT DISTINCT` нужен, чтобы два адреса без квартиры не считались разными. |
| client_address | `pk_client_address` | `(client_id, address_id)` | BR-2.5 | Адрес нельзя привязать к клиенту дважды. |
| restaurant | `uq_restaurant_address` | `address_id` | BR-3.3 | У ресторана один адрес, два ресторана не делят адрес. |
| courier_pay | `pk_courier_pay` | `(year, month, courier_id)` | BR-10.3 | Одна запись на курьера и месяц. |
| product_category | `uq_product_category_name` | `product_category_name` | BR-5.7, BR-11.4 | Категория - справочник, названия не дублируются. |
| payment | `uq_payment_transaction` | `transaction_id` | BR-8.3,  BR-11.1 | Внешний ID транзакции уникален. Правило BR-8.3 не задает формат внешнего идентификатора, отсюда мной был выбран тип `uuid` согласно FOOD-101 (где все ID это `uuid`) и правилу BR-11.1 |
| payment | `uq_payment_one_success` (частичный, `WHERE status = 'успех'`) | `order_id` | BR-8.1, BR-8.7 | У заказа не более одной успешной попытки. «Ровно одна» невозможна: при «все с ошибкой» (BR-8.7) успешной нет. |
| order_structure | `pk_order_structure` | `(order_id, product_id)` | BR-7.16 | Блюдо в заказе не повторяется. |
| review | `uq_review_once_per_entity` | `(order_id, entity_type, entity_id)` | BR-9.5 | Не более одного отзыва на объект в рамках заказа. |
| "order" | `uq_order_id_client` | `(order_id, client_id)` | BR-9.2 | Техническая цель составного FK отзыва. `order_id` уже PK, поэтому данные не ограничиваются. |
| "order" | `uq_order_id_total` | `(order_id, total_amount)` | BR-8.4 | Техническая цель составного FK платежа. Аналогично не ограничивает данные. |

## FOREIGN KEY

| Таблица | Ограничение | Ссылка | ON DELETE | BR | Обоснование |
|---|---|---|---|---|---|
| client_address | `fk_client_address_client` | `client` | CASCADE | BR-2.4, BR-3.5 | Привязка адреса к клиенту исчезает вместе с клиентом, сам адрес остается. |
| client_address | `fk_client_address_address` | `address` | RESTRICT | BR-2.4, BR-3.5 | Адрес не удаляется, пока привязан к клиенту. |
| restaurant | `fk_restaurant_address` | `address` | RESTRICT | BR-3.3, BR-3.5 | Адрес ресторана существует и не удаляется вместе с рестораном. |
| courier_pay | `fk_courier_pay_courier` | `courier` | RESTRICT | BR-10.3, BR-10.7 | История выплат не теряется при удалении курьера. |
| product | `fk_product_category` | `product_category` | RESTRICT | BR-5.1, BR-5.7 | Блюдо принадлежит ровно одной категории. |
| product | `fk_product_restaurant` | `restaurant` | RESTRICT | BR-5.1 | Блюдо принадлежит ровно одному ресторану. |
| "order" | `fk_order_courier` | `courier` | RESTRICT | BR-7.5 | Заказ доставляет курьер. |
| "order" | `fk_order_client` | `client` | RESTRICT | BR-7.1, BR-7.2 | Заказ оформляет клиент. |
| "order" | `fk_order_address` | `address` | RESTRICT | BR-7.4 | Адрес доставки (из ERD). |
| "order" | `fk_order_restaurant` | `restaurant` | RESTRICT | BR-7.2 | У заказа один ресторан. |
| "order" | `fk_order_client_address` | `client_address (client_id, address_id)` | RESTRICT | BR-7.4 | Составной FK: адрес доставки - один из адресов этого клиента (ловушка 2). |
| payment | `fk_payment_order` | `"order"` | RESTRICT | BR-8.1 | Попытка оплаты относится к заказу. |
| payment | `fk_payment_order_amount` | `"order" (order_id, total_amount)` | RESTRICT | BR-8.4 | Составной FK: сумма попытки равна общей сумме заказа (ловушка 1). |
| order_structure | `fk_order_structure_order` | `"order"` | CASCADE | BR-7.14 | Позиции - часть заказа. |
| order_structure | `fk_order_structure_product` | `product` | RESTRICT | BR-7.14 | Блюдо в составе заказа существует. |
| review | `fk_review_client` | `client` | RESTRICT | BR-9.2 | Отзыв оставляет клиент. |
| review | `fk_review_order` | `"order"` | RESTRICT | BR-9.1, BR-9.2 | Отзыв всегда связан с заказом. |
| review | `fk_review_order_client` | `"order" (order_id, client_id)` | RESTRICT | BR-9.2 | Составной FK: заказ принадлежит автору отзыва (ловушка 4). |

Всего 18 FK. У `review.entity_id` FK нет по причине, описанной в ловушке 4.

## NOT NULL (только бизнес-обязательные)

| Таблица.столбец | BR | Обоснование |
|---|---|---|
| client: `login`, `password`, `phone_number` | BR-2.1, BR-11.4 | Все три атрибута обязательны. |
| address: `street`, `house_number` | BR-3.1, BR-3.2 | Обязательны, необязательна только кв./офис. |
| restaurant: `restaurant_name`, `inn`, `kpp`, `orgn`, `work_start`, `work_end`, `status` | BR-4.1, BR-4.4, BR-4.5 | Перечислены в составе ресторана. |
| courier: `first_name`, `last_name`, `middle_name`, `phone_number`, `status`, `hire_date`, `coefficient` | BR-6.1, BR-6.4, BR-6.5 | Поля курьера. Дата увольнения необязательна, см. NULL. |
| product: `product_name`, `price`, `description`, `status` | BR-5.2, BR-5.3, BR-5.5 | Поля блюда. |
| "order": `order_timestamp`, `order_amount`, `commission`, `total_amount`, `status`, `pay_status` | BR-7.1, BR-7.10 | Время создания и три суммы обязательны. |
| payment: `payment_type`, `amount`, `transaction_id`, `payment_timestamp`, `status` | BR-8.2, BR-8.3 | Все атрибуты попытки обязательны. |
| order_structure: `quantity` | BR-7.14, BR-7.15 | Позиция без количества невозможна. |
| review: `review_timestamp`, `entity_id`, `entity_type`, `description`, `rating` | BR-9.1, BR-9.3 | Текст и рейтинг обязательны, фото нет. |

## NULL (осознанно разрешено)

Ровно 7 столбцов (BR-11.3). Это проверяется пунктом B.8 в `tests.md`.

| Таблица.столбец | BR | Почему `NULL` |
|---|---|---|
| address.`apartment_office` | BR-3.2 | У частного дома нет квартиры или офиса. |
| courier.`dismissal_date` | BR-6.3 | Заполняется только у уволенных. |
| "order".`delivery_timestamp` | BR-7.12 | Заказ может быть еще не доставлен. |
| "order".`description` | BR-7.1 | Из правила следует, что заказ оформляет сам клиент. Комментарий может и не добавить. |
| product.`photo_url` | BR-5.6 | Фото необязательно. |
| product.`rating` | BR-5.4, BR-9.7 | Нет отзывов, значит рейтинг `NULL`. |
| restaurant.`description` | BR-4.1 | Правило напрямую не запрещает отсутствие описания. |
| restaurant.`rating` | BR-4.1, BR-9.7 | Нет отзывов, значит рейтинг `NULL`. |
| review.`photo_url` | BR-9.3 | Фото необязательно. |

## DEFAULT и GENERATED

| Таблица.столбец | Значение | BR | Комментарий |
|---|---|---|---|
| все `*_id` (кроме составных частей ключей) | `exts.uuid_generate_v4()` | BR-11.1, BR-13.3 | Схема `exts` уже существует и не создается скриптами. |
| restaurant.`status` | `'активен'` | BR-4.3 | Новый ресторан активен. |
| product.`status` | `'доступно'` | BR-5.5 | Новое блюдо доступно. |
| courier.`status` | `'свободен'` | BR-6.2 | Новый курьер свободен. |
| courier.`hire_date` | `current_date` | BR-6.1 | Найм сегодня, если не указано иное. |
| courier.`coefficient` | `0.1` | BR-6.5 | Начальный коэффициент. |
| "order".`order_timestamp` | `localtimestamp` | BR-7.1, BR-11.2 | Время сервера. |
| "order".`status` | `'создан'` | BR-7.7 | Начальный статус. |
| "order".`pay_status` | `'ожидает'` | BR-7.9 | Платежей еще нет. |
| "order".`description` | `'без комментариев'` | BR-11.3 | Вместо `NULL`: комментарий не входит в разрешенные `NULL`. |
| payment.`payment_timestamp` | `localtimestamp` | BR-8.2, BR-11.2 | Время сервера. |
| payment.`status` | `'в_обработке'` | BR-8.2 | Начальный статус попытки. |
| review.`review_timestamp` | `localtimestamp` | BR-9.3, BR-11.2 | Время сервера. |

`generated` не используется. Столбцы `commission` и `total_amount` сделаны обычными полями с проверками `ck_order_commission` и `ck_order_total`, а не вычисляемыми `GENERATED ... STORED`. ERD и BR-7.10 описывают их как поля заказа, а тестовые данные и приложение передают значения явно. Если значения не сходятся, `CHECK` сообщает об этом ошибкой, а не молча пересчитывает данные.

Гарантия при этом та же, что дало бы `GENERATED`: рассогласованные `order_amount`, комиссия и итог в базу попасть не могут. Сам `order_amount` сделать вычисляемым нельзя в принципе, потому что это сумма по другой таблице, `order_structure`.

## Нормализация (3НФ)

| Таблица | Вывод |
|---|---|
| client | Все атрибуты зависят только от `client_id`. Логин и телефон - альтернативные ключи (BR-2.2). |
| address | Все атрибуты зависят от `address_id`. Адрес - общая сущность (BR-2.4, BR-3.4). |
| client_address | Связь M:N (BR-2.4) разрешена таблицей-связкой, неключевых атрибутов нет. |
| restaurant | 1:1 с адресом (BR-3.3). Атрибуты зависят только от `restaurant_id`. |
| courier | Все атрибуты зависят от `courier_id`. |
| courier_pay | Ключ `(year, month, courier_id)`. `amount` и `coefficient_used` - факт конкретной выплаты, а не копия `courier.coefficient` (тот относится к следующему месяцу). |
| product_category | Справочник (BR-5.7). |
| product | Категория и ресторан вынесены в отдельные таблицы (BR-5.1). |
| "order" | См. особые случаи ниже. |
| payment | См. особые случаи ниже. |
| order_structure | Ключ `(order_id, product_id)`, неключевой атрибут только `quantity`. `restaurant_id` не дублируется (иначе нарушение 2НФ, ловушка 3). |
| review | См. особые случаи ниже. |

1. Рейтинги `restaurant.rating` и `product.rating` - осознанная денормализация. Значение можно вывести из таблицы `review`, но BR-9.6 прямо требует хранить агрегированный рейтинг и пересчитывать его автоматически. Согласованность обеспечивает триггер `trg_review_rating_change`, вызывающий `rating_change()` при INSERT, UPDATE и DELETE (BR-9.7, FOOD-105). Если отзывов нет, рейтинг равен `NULL`. У заказа агрегированного рейтинга нет (BR-9.6).
2. `"order".commission` и `total_amount` зависят от `order_amount`, то есть это транзитивная зависимость. Но BR-7.10 требует хранить все три значения, а `CHECK` не дает им разойтись. Пересчитать `order_amount` задним числом нельзя: в `order_structure` нет цены на момент заказа, а `product.price` со временем меняется. Поэтому `order_amount` является зафиксированным фактом, а не дублем.
3. `payment.amount` повторяет `"order".total_amount`. Это не избыточность, а прямое требование BR-8.4. Расхождение исключено составным внешним ключом `fk_payment_order_amount`.
4. `"order".pay_status` - сводка по таблице `payment` (BR-7.8, BR-8.7). Ее поддерживает триггер `trg_payment_sync_order_pay_status`.
5. `review.entity_id` вместе с `entity_type` - полиморфная ссылка (BR-9.1). Это сознательное решение, причины описаны в ловушке 4.
