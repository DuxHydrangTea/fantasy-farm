extends Node
## Reproducible catalog audit. No personal profile, wall clock or gameplay writes.
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var prices: ProducePriceCatalog = preload("res://resources/shops/produce_prices.tres")
	var catalog: SaveCatalog = SaveCatalog.new()
	var report: Dictionary = {"orders":[],"recipes":[],"orchard":[],"crops":[],"honey":[]}
	for entry: OrderDefinition in OrderService.DEFAULT_CATALOG.entries:
		var values: Array[int] = [0,0,0]
		for i: int in range(entry.items.size()):
			var price: ProducePrice = prices.find(entry.items[i].item_id)
			for tier: int in range(3):
				values[tier] += ItemQuality.unit_price(price.price,tier)*entry.amounts[i]
		var revised: Array[int] = []
		for variant: int in range(3):
			var bag: InventoryComponent = InventoryComponent.new()
			bag.starting_tools = false
			add_child(bag)
			var wallet: WalletComponent = WalletComponent.new()
			add_child(wallet)
			wallet.set_balance(0)
			var service: OrderService = OrderService.new(bag,wallet,func(_entry: OrderDefinition) -> bool: return true)
			var state: Dictionary = OrderSaveSchema.fresh()
			state.initialized = true
			state.next_serial = 2
			state.slots[0] = {"serial":1,"template":String(entry.order_id)}
			service.restore(state)
			for i: int in range(entry.items.size()):
				var silver: int = entry.amounts[i] if variant == 0 else 0 if variant == 1 else int(entry.amounts[i]/2)
				bag.add(entry.items[i],silver,1)
				bag.add(entry.items[i],entry.amounts[i]-silver,2)
			revised.append(int(service.quote(1,true).coins))
			bag.free()
			wallet.free()
		report.orders.append({"id":String(entry.order_id),"ordinary":entry.reward_coins,"old_perfect":roundi(entry.reward_coins*1.5),"market":values,"new_perfect_silver_gold_mixed":revised})
	for recipe: CookingRecipe in ChefCooking.RECIPES:
		var cost: int = recipe.coin_cost
		var marketable: bool = true
		for i: int in range(recipe.ingredients.size()):
			var price: ProducePrice = prices.find(recipe.ingredients[i].item_id)
			if price == null:
				marketable = false
				continue
			cost += ItemQuality.unit_price(price.price,recipe.tier_at(i))*recipe.amounts[i]
		var output: ProducePrice = prices.find(recipe.output.item_id)
		if output != null:
			report.recipes.append({"id":String(recipe.recipe_id),"inputs_sale":cost,"output":output.price,"net":output.price-cost,"hours":recipe.cook_seconds/3600.0,"marketable_inputs":marketable})
	for tree: TreeDefinition in catalog.trees.values():
		if tree.kind == TreeDefinition.Kind.FRUIT:
			var price: int = prices.find(tree.harvest_item.item_id).price
			report.orchard.append({"id":String(tree.tree_id),"cycle_hours":tree.fruit_cycle_seconds/3600.0,"yield_income":tree.harvest_amount*2*price,"star_raw_income":tree.harvest_amount*prices.find(tree.star_harvest_item.item_id).price})
	var supplies: ShopCatalog = preload("res://resources/shops/farm_supply.tres")
	for offer: ShopOffer in supplies.offers:
		if offer.item == null or not offer.item.crop is CropDefinition:
			continue
		var crop: CropDefinition = offer.item.crop as CropDefinition
		var price: ProducePrice = prices.find(crop.harvest_item.item_id)
		var nets: Array[int] = []
		for tier: int in range(3):
			nets.append(crop.harvest_amount*ItemQuality.unit_price(price.price,tier)-offer.price)
		report.crops.append({"id":String(crop.crop_id),"seconds":crop.growth_seconds,"seed":offer.price,"yield":crop.harvest_amount,"net_by_tier":nets})
	for id: String in ["mixed","mono_06","hybrid_01_06"]:
		var item: ItemDefinition = HoneyComboCatalog.item(id)
		var rate: float = 1.0 if id == "mixed" else 2.0
		report.honey.append({"id":id,"hours_full_bloom":24.0/rate,"hours_windy":24.0/rate/1.25,"capped_batch":100,"sale_per_batch":100*prices.find(item.item_id).price})
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var file: FileAccess = FileAccess.open(args[0],FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("ECONOMY_AUDIT ",args[0])
	get_tree().quit()
