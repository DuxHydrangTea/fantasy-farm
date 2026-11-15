class_name WalletComponent
extends Node
## Quản lý số xu nguyên của người chơi, được lưu dưới dạng giá trị nguyên.
##
## Số dư hợp lệ nằm trong khoảng từ 0 đến [constant MAX_COINS]. Các thao tác
## thành công có thể phát [signal changed] để giao diện và hệ thống khác cập nhật.

## Phát sau khi số dư thực sự thay đổi và thông báo được bật.
signal changed(balance: int)
## Số xu ban đầu của ví mới.
const STARTING_COINS: int = 10000
## Giới hạn trên của số dư ví.
const MAX_COINS: int = 1000000000
## Số xu hiện tại. Dùng [method set_balance] để kiểm tra giới hạn và thông báo.
var balance: int = STARTING_COINS

## Đặt số dư thành [param value], trả về [code]false[/code] nếu vượt giới hạn.
## Khi [param notify] là [code]true[/code], phát [signal changed] nếu giá trị đổi.
func set_balance(value: int, notify: bool = true) -> bool:
	if value < 0 or value > MAX_COINS:
		return false
	if balance != value:
		balance = value
		if notify:
			changed.emit(balance)
	return true

## Cộng [param amount] xu dương vào ví.
## Trả về [code]false[/code] nếu số tiền không dương hoặc làm vượt giới hạn.
func credit(amount: int) -> bool:
	return amount > 0 and amount <= MAX_COINS - balance and set_balance(balance + amount)
