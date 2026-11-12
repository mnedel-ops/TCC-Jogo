class_name ShopRules
extends RefCounted

# Regras da loja, sem UI. O lojista vende pelo valorVenda do item
# e compra do jogador pela metade desse valor.

const SELL_DIVISOR := 2

enum Result { OK, INVALID_ITEM, NOT_TRADABLE, NOT_ENOUGH_MONEY, NOT_IN_INVENTORY }


# Preço que o jogador paga ao lojista.
static func buy_price(item: ItemData) -> int:
	if item == null:
		return 0
	return maxi(item.valorVenda, 0)


# Preço que o lojista paga ao jogador: metade do valorVenda (arredonda pra baixo).
@warning_ignore("integer_division")
static func sell_price(item: ItemData) -> int:
	return buy_price(item) / SELL_DIVISOR


static func can_buy(item: ItemData) -> bool:
	return buy_price(item) > 0


static func can_sell(item: ItemData) -> bool:
	return sell_price(item) > 0


# Itens do banco que têm preço. Usado quando o lojista não tem lista própria.
static func tradable_items(database: ItemDatabase) -> Array[ItemData]:
	var out: Array[ItemData] = []
	if database == null:
		return out
	for item in database.items:
		if can_buy(item):
			out.append(item)
	return out


static func buy(player: PlayerData, inventory: InventoryData, item: ItemData) -> Result:
	if player == null or inventory == null or item == null:
		return Result.INVALID_ITEM
	if not can_buy(item):
		return Result.NOT_TRADABLE
	var price := buy_price(item)
	if player.money < price:
		return Result.NOT_ENOUGH_MONEY
	# Dinheiro primeiro: o inventário emite changed e dispara o autosave.
	player.add_money(-price)
	inventory.add_item(item.index)
	return Result.OK


static func sell(player: PlayerData, inventory: InventoryData, item: ItemData) -> Result:
	if player == null or inventory == null or item == null:
		return Result.INVALID_ITEM
	if not can_sell(item):
		return Result.NOT_TRADABLE
	if inventory.get_quantity(item.index) <= 0:
		return Result.NOT_IN_INVENTORY
	player.add_money(sell_price(item))
	inventory.remove_item(item.index)
	return Result.OK


static func message_for(result: Result, item: ItemData, buying: bool) -> String:
	var nome := item.nome if item != null else "item"
	match result:
		Result.OK:
			if buying:
				return "Você comprou %s por $ %d." % [nome, buy_price(item)]
			return "Você vendeu %s por $ %d." % [nome, sell_price(item)]
		Result.NOT_ENOUGH_MONEY:
			return "Dinheiro insuficiente."
		Result.NOT_IN_INVENTORY:
			return "Você não tem esse item."
		Result.NOT_TRADABLE:
			return "Esse item não tem valor de troca."
	return "Não foi possível concluir."
