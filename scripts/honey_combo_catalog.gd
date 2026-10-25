class_name HoneyComboCatalog
extends RefCounted
## Ordered recipes: hybrids beat mono flowers; opposite pairs share the hive center.
const IDS: Array[String] = ["hybrid_01_06", "hybrid_02_07", "hybrid_03_08", "mono_06", "mono_07"]
const PAIRS: Array[Vector2i] = [Vector2i(1,0), Vector2i(0,1), Vector2i(1,1), Vector2i(1,-1)]
const ITEMS: Dictionary = {
 "mixed": preload("res://items/honey/mixed_honey.tres"),
 "hybrid_01_06": preload("res://items/honey/hybrid_01_06_honey.tres"),
 "hybrid_02_07": preload("res://items/honey/hybrid_02_07_honey.tres"),
 "hybrid_03_08": preload("res://items/honey/hybrid_03_08_honey.tres"),
 "mono_06": preload("res://items/honey/mono_06_honey.tres"),
 "mono_07": preload("res://items/honey/mono_07_honey.tres")}

static func resolve(blooms: Dictionary) -> String:
	for i: int in range(3):
		var a: String = "flower_%02d" % (i + 1)
		var b: String = "flower_%02d" % (i + 6)
		var matched: Dictionary = {}
		for axis: Vector2i in PAIRS:
			var species: String = String(blooms.get(axis, ""))
			if species in [a,b] and blooms.get(-axis, "") == species:
				matched[species] = true
		if matched.has(a) and matched.has(b):
			return IDS[i]
	for i: int in range(2):
		var count: int = 0
		for species: String in blooms.values():
			if species == "flower_%02d" % (i + 6):
				count += 1
		if count >= 4:
			return IDS[i + 3]
	return "mixed"

static func item(id: String) -> ItemDefinition:
	return ITEMS.get(id) as ItemDefinition

const FLOWER_NAMES: Array[String] = [
	"Rose", "Carnation", "Orchid", "Lavender", "Bluebell",
	"Hydrangea", "Marigold", "Sunflower", "Lily of the Valley", "Blue Lotus"
]

static func instruction(id: String) -> String:
	var index: int = IDS.find(id)
	if index < 0:
		return TranslationServer.translate("No combo: Mixed Honey")
	if index < 3:
		var name_a: String = TranslationServer.translate(FLOWER_NAMES[index])
		var name_b: String = TranslationServer.translate(FLOWER_NAMES[index + 5])
		return TranslationServer.translate("Two opposite {a} + two opposite {b}").format({"a": name_a, "b": name_b})
	var name_a: String = TranslationServer.translate(FLOWER_NAMES[index + 2])
	return TranslationServer.translate("At least four {a} in the eight neighboring pots").format({"a": name_a})
