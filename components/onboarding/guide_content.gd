class_name GuideContent
extends RefCounted
## Localizable instructions indexed by the existing objective IDs, not new counters.
const TOPICS: Array[String] = ["Current step", "Controls", "Bag and trading", "Time and animals", "Orders", "Getting unstuck"]
const SHORT: Dictionary = {
	"first_soil": "Move to bare farmland. Select the hoe and use it once.",
	"first_seed": "Select a seed in the hotbar. Use it on prepared soil.",
	"first_water": "Select the watering can. Use it on the planted tile.",
	"first_harvest": "Wait for maturity, then interact with the crop.",
	"first_sale": "Bring produce to the buyer beside the supply shop.",
	"first_animal": "Buy an animal at the supply shop or check your pens.",
	"first_feed": "Select feed. Stand near a food trough and interact.",
	"first_trough_water": "Select the watering can. Interact with a water trough.",
	"first_expansion": "Visit the land sign and confirm the next column."
}
const DETAILS: Dictionary = {
	"first_soil": "Use the unlocked strip at the edge of the farmland. Stand beside an untilled tile and face it. Select the hoe, then use it. Previously prepared unlocked soil also counts.",
	"first_seed": "Move a seed into one of the first six bag slots if needed, then select that slot. Stand beside dry, prepared, empty farmland and use the seed. Only a successful planting after this step unlocks counts.",
	"first_water": "Select the watering can and use it on dry soil containing your crop. Plain soil and rain do not count as manually watering a crop. Rewater when soil dries out.",
	"first_harvest": "Keep the planted tile watered and wait for the plant to mature. Interact with the mature crop. If the bag cannot hold the full harvest, sell some produce first; the crop remains in place.",
	"first_sale": "The produce buyer stands beside the supply merchant near the market stalls. Approach, face the buyer and interact. Select produce and a quantity, then sell. Supply purchases and order deliveries do not count as this sale.",
	"first_animal": "The supply merchant sells young animals for available pen space. Existing living animals also count. Open Objectives to claim this reward when it is ready.",
	"first_feed": "Buy feed from the supply merchant if needed. Select feed, stand beside a food trough and interact. Feed is consumed only when the refill lands. A full trough does not count.",
	"first_trough_water": "Select the watering can, stand beside a water trough and interact. A successful refill counts; a full trough does not. The watering can is not consumed.",
	"first_expansion": "Find the sign at the next locked farmland column. Approach and interact to see the price, then confirm if you can afford it. Existing ownership of two columns also counts."
}

static func controls(touch: bool) -> String:
	return "Move with the left joystick or tap the ground. Tap a hotbar slot to select it, then tap Use. Face a target and tap Interact, or tap the target itself. Pinch with two fingers to zoom. Swipe lists and help text to scroll. Play in landscape." if touch else "Move with WASD, arrow keys or a left click on the ground. Select slots 1–6 with number keys or the mouse. Use the selected item with Space or right click. Interact with E or click a target. Open Bag with Tab or I, Objectives with J, and Help with H. Scroll lists with the wheel."

static func current(goals: ObjectiveProgress, touch: bool) -> String:
	var step: ObjectiveDefinition = goals.active()
	if step == null:
		return TranslationServer.translate("All introductory objectives are complete. Keep farming or visit the order board for repeatable requests.")
	var text: String = TranslationServer.translate(step.title) + "\n\n"
	text += TranslationServer.translate("This step is complete. Open Objectives and claim its reward to unlock the next step.") if goals.ready_to_claim() else TranslationServer.translate(String(DETAILS.get(String(step.objective_id), step.description)))
	var input_tip: String = "Tap a hotbar slot, then Use. Tap Interact for nearby targets." if touch else "Select a hotbar slot, then press Space to use it. Press E for nearby targets."
	return text + "\n\n" + TranslationServer.translate(input_tip)

static func topic(index: int, goals: ObjectiveProgress, touch: bool) -> String:
	match index:
		0: return current(goals, touch)
		1: return TranslationServer.translate(controls(touch))
		2:
			var bag_tip: String = "In Bag, select a slot, tap Move, then tap its destination. Move a seed or tool into the first six slots to use it." if touch else "Drag items between bag slots to swap or stack them. Move a seed or tool into the first six slots to use it."
			return TranslationServer.translate("Open Bag to inspect all 64 slots. Only the first six slots appear on the hotbar. Tools are reusable; seeds and feed are consumed. Sell harvested crops, flowers or animal produce to the produce buyer. Buy seeds and feed from the supply merchant. Selling produce for coins is separate from delivering orders.") + "\n\n" + TranslationServer.translate(bag_tip)
		3: return TranslationServer.translate("Growth uses real elapsed time, including time away from the game. An unwatered flower does not start growing; crops need moist soil. Animal hunger, thirst, age and lifespan also advance offline. Keep food and water in troughs. Open the pen's wooden sign to see needs and production; young or hungry animals may not produce. Opening a menu does not pause the farm. The game autosaves; let the save notice finish before leaving. Long absences can leave animals hungry, thirsty or past their lifespan.")
		4: return TranslationServer.translate("The order board is left of the market stalls. It holds up to three requests. Bring all requested items, select an order and confirm delivery for coins. Abandoning also asks for confirmation and has no coin penalty. There are no deadlines. Sell all at the produce buyer can sell items requested by orders, so deliver those first if you want to keep them.")
	return TranslationServer.translate("If your bag is full, sell produce or stack matching items. If seeds run out, water and harvest existing crops, collect animal produce or flowers, then sell them and buy seeds. Check your pens and the supply merchant. If you have no seeds, no produce in your bag, no field crops and too few coins for seeds, you may request one carrot seed here once per profile. This does not reset the farm or give coins. Hints can be disabled or skipped without completing objectives or receiving their rewards.")
