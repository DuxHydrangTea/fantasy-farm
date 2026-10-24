class_name WalletComponent
extends Node
## Integer currency owned by the player; persisted as a primitive value.
signal changed(balance: int)
const STARTING_COINS: int = 10000
const MAX_COINS: int = 1000000000
var balance: int = STARTING_COINS

func set_balance(value: int, notify: bool = true) -> bool:
	if value < 0 or value > MAX_COINS:
		return false
	if balance != value:
		balance = value
		if notify:
			changed.emit(balance)
	return true

func credit(amount: int) -> bool:
	return amount > 0 and amount <= MAX_COINS - balance and set_balance(balance + amount)
