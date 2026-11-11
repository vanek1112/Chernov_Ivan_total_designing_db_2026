create or replace procedure chernov_food.erase_test_data() as $$
begin
	delete from chernov_food.review;
	delete from chernov_food.payment;
	delete from chernov_food.order_structure;
	delete from chernov_food."order";
	delete from chernov_food.courier_pay;
	delete from chernov_food.client_address;
	delete from chernov_food.product;
	delete from chernov_food.restaurant;
	delete from chernov_food.client;
	delete from chernov_food.courier;
	delete from chernov_food.product_category;
	delete from chernov_food.address;
end;
$$ language plpgsql;
