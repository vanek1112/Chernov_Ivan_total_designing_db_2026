-- FOOD-103

create or replace procedure chernov_food.erase_test_data()
language plpgsql
as $$
declare
    v_cnt   bigint;
    v_total bigint := 0;
begin
    delete from chernov_food.review;
    get diagnostics v_cnt = row_count;  v_total := v_total + v_cnt;

    delete from chernov_food.payment;
    get diagnostics v_cnt = row_count;  v_total := v_total + v_cnt;

    delete from chernov_food.order_structure;
    get diagnostics v_cnt = row_count;  v_total := v_total + v_cnt;

    delete from chernov_food."order";
    get diagnostics v_cnt = row_count;  v_total := v_total + v_cnt;

    delete from chernov_food.courier_pay;
    get diagnostics v_cnt = row_count;  v_total := v_total + v_cnt;

    delete from chernov_food.client_address;
    get diagnostics v_cnt = row_count;  v_total := v_total + v_cnt;

    delete from chernov_food.product;
    get diagnostics v_cnt = row_count;  v_total := v_total + v_cnt;

    delete from chernov_food.restaurant;
    get diagnostics v_cnt = row_count;  v_total := v_total + v_cnt;

    delete from chernov_food.client;
    get diagnostics v_cnt = row_count;  v_total := v_total + v_cnt;

    delete from chernov_food.courier;
    get diagnostics v_cnt = row_count;  v_total := v_total + v_cnt;

    delete from chernov_food.product_category;
    get diagnostics v_cnt = row_count;  v_total := v_total + v_cnt;

    delete from chernov_food.address;
    get diagnostics v_cnt = row_count;  v_total := v_total + v_cnt;

    raise notice 'erase_test_data: удалено строк всего: %', v_total;
end;
$$;