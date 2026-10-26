class_name TreePlotUpgradeCatalog
extends Resource
@export var prices: Dictionary = {}

func valid() -> bool:
	if prices.size() != 2:
		return false
	for id: String in ["fruit", "timber"]:
		var rows: Variant = prices.get(id)
		if not rows is Array or rows.size() != 16:
			return false
		var previous: int = 0
		for value: Variant in rows:
			if not (value is int or value is float) or not is_finite(float(value)) or value <= previous or value != floor(float(value)):
				return false
			previous = int(value)
	return true

func price(kind: TreeDefinition.Kind, level: int) -> int:
	var rows: Array = prices.get("fruit" if kind == TreeDefinition.Kind.FRUIT else "timber", [])
	return int(rows[level - 1]) if level >= 1 and level <= rows.size() else 0
