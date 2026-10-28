class_name ShopCatalog
extends Resource
@export var display_name: String = "LAI BUON'S SHOP"
@export var category_ids: Array[int] = [0, 1, 2, 3, 4, 5]
@export var offers: Array[ShopOffer] = []
@export var animal_offers: Array[AnimalShopOffer] = []
