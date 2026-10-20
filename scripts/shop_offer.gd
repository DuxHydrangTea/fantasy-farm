class_name ShopOffer
extends Resource
enum Category { CROP, FEED, FLOWER }
@export var item: ItemDefinition
@export_range(1, 1000000) var price: int = 10
@export var category: Category = Category.CROP
