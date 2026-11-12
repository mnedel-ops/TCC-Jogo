extends GdUnitTestSuite


func _item(index: int, valor: int, nome := "Item") -> ItemData:
	var it := ItemData.new()
	it.index = index
	it.nome = nome
	it.valorVenda = valor
	return it


func _world(money: int, items: Array[int] = []) -> Array:
	var p := PlayerData.new()
	p.money = money
	var inv := InventoryData.new()
	inv.items = items.duplicate()
	return [p, inv]


func test_valor_venda_defaults_to_zero() -> void:
	assert_int(ItemData.new().valorVenda).is_equal(0)


func test_shop_buys_for_half_of_valor_venda() -> void:
	assert_int(ShopRules.buy_price(_item(1, 50))).is_equal(50)
	assert_int(ShopRules.sell_price(_item(1, 50))).is_equal(25)


func test_sell_price_rounds_down() -> void:
	assert_int(ShopRules.sell_price(_item(1, 51))).is_equal(25)
	assert_bool(ShopRules.can_sell(_item(1, 1))).is_false()
	assert_bool(ShopRules.can_buy(_item(1, 1))).is_true()


func test_negative_or_zero_value_is_not_tradable() -> void:
	assert_bool(ShopRules.can_buy(_item(1, 0))).is_false()
	assert_bool(ShopRules.can_buy(_item(1, -5))).is_false()
	assert_bool(ShopRules.can_buy(null)).is_false()


func test_buy_takes_money_and_adds_item() -> void:
	var w := _world(100)
	var p: PlayerData = w[0]
	var inv: InventoryData = w[1]
	var it := _item(7, 40)
	assert_int(ShopRules.buy(p, inv, it)).is_equal(ShopRules.Result.OK)
	assert_int(p.money).is_equal(60)
	assert_int(inv.get_quantity(7)).is_equal(1)


func test_buy_without_money_changes_nothing() -> void:
	var w := _world(10)
	var p: PlayerData = w[0]
	var inv: InventoryData = w[1]
	assert_int(ShopRules.buy(p, inv, _item(7, 40))).is_equal(ShopRules.Result.NOT_ENOUGH_MONEY)
	assert_int(p.money).is_equal(10)
	assert_bool(inv.is_empty()).is_true()


func test_buy_with_exact_money_works() -> void:
	var w := _world(40)
	assert_int(ShopRules.buy(w[0], w[1], _item(7, 40))).is_equal(ShopRules.Result.OK)
	assert_int((w[0] as PlayerData).money).is_equal(0)


func test_sell_gives_half_and_removes_one() -> void:
	var w := _world(0, [7, 7])
	var p: PlayerData = w[0]
	var inv: InventoryData = w[1]
	assert_int(ShopRules.sell(p, inv, _item(7, 40))).is_equal(ShopRules.Result.OK)
	assert_int(p.money).is_equal(20)
	assert_int(inv.get_quantity(7)).is_equal(1)


func test_sell_item_not_owned_changes_nothing() -> void:
	var w := _world(5)
	var p: PlayerData = w[0]
	assert_int(ShopRules.sell(p, w[1], _item(7, 40))).is_equal(ShopRules.Result.NOT_IN_INVENTORY)
	assert_int(p.money).is_equal(5)


func test_sell_item_without_value_is_refused_and_kept() -> void:
	var w := _world(0, [7])
	var inv: InventoryData = w[1]
	assert_int(ShopRules.sell(w[0], inv, _item(7, 0))).is_equal(ShopRules.Result.NOT_TRADABLE)
	assert_int(inv.get_quantity(7)).is_equal(1)


func test_buy_then_sell_loses_half() -> void:
	var w := _world(100)
	var it := _item(7, 40)
	ShopRules.buy(w[0], w[1], it)
	ShopRules.sell(w[0], w[1], it)
	assert_int((w[0] as PlayerData).money).is_equal(80)


func test_money_is_final_when_inventory_signals_change() -> void:
	# GameSession salva quando o inventário muda; o dinheiro já tem que estar certo.
	var w := _world(0, [7])
	var p: PlayerData = w[0]
	var inv: InventoryData = w[1]
	var seen: Array[int] = []
	inv.changed.connect(func(): seen.append(p.money))
	ShopRules.sell(p, inv, _item(7, 40))
	assert_array(seen).contains_exactly([20])


func test_tradable_items_skips_unpriced() -> void:
	var db := ItemDatabase.new()
	db.items = [_item(1, 10), _item(2, 0), _item(3, 5)]
	var out := ShopRules.tradable_items(db)
	assert_int(out.size()).is_equal(2)
	assert_int(ShopRules.tradable_items(null).size()).is_equal(0)


func test_real_items_all_have_a_value() -> void:
	var db: ItemDatabase = load("res://DATABASE/Inventory/ItemDatabase.tres")
	for it in db.items:
		assert_bool(it.valorVenda > 0).is_true()
