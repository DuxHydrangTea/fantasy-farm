# Lớn lên, sản xuất phụ phẩm và nhặt vật phẩm

Các scene kế thừa `scenes/animals/animal.tscn` dùng chung vòng đời này. Trong
farm mẫu, các con hiện có bắt đầu ở tuổi trưởng thành, riêng `Chicken_8` và
`Chicken_9` bắt đầu từ tuổi 0 để thử tiến trình lớn lên.

## Cấu hình tuổi và sprite

- `AnimalDefinition.maturity_seconds`: số giây để trưởng thành, mặc định 120.
- `Animal.initial_age_seconds`: tuổi ban đầu riêng của từng instance; mặc định
  0 là con non. Gán bằng hoặc lớn hơn `maturity_seconds` để bắt đầu trưởng thành.
- `juvenile_frames`: dùng khi con non và resource có animation idle/walk hợp lệ.
  Nếu thiếu hoặc không hợp lệ, dùng `skin_frames` của con đó, rồi tới `adult_frames`.
- Khi trưởng thành, dùng skin trưởng thành riêng. Nếu cần đổi bộ sprite, đợi
  animal đứng yên để giữ nguyên chuỗi ngồi/ngủ/đứng dậy và hành động ăn/uống.

`AnimalGrowthComponent` giữ tuổi riêng của mỗi con và phát `matured` đúng một
lần khi qua mốc trưởng thành. Tuổi tiếp tục tăng dù con vật đang đói/khát.

## Cấu hình phụ phẩm

Gán `production` trong resource của loài. `AnimalProductionDefination` giữ:

| Thuộc tính | Ý nghĩa |
| --- | --- |
| `production_item` | ItemDefinition của phụ phẩm, loại PRODUCE |
| `production_amount` | Số lượng mỗi chu kỳ, mặc định 1 |
| `production_seconds` | Số giây đủ điều kiện để hoàn tất một chu kỳ |
| `collection_mode` | WORLD_DROP mặc định, hoặc DIRECT_COLLECTION qua API |

Các resource đang cấu hình:

| Loài | Phụ phẩm | Chu kỳ |
| --- | --- | --- |
| Gà | Trứng gà | 30 giây |
| Bò | Sữa bò | 60 giây |
| Vịt | Trứng vịt | 40 giây |
| Ngỗng | Trứng ngỗng | 50 giây |
| Lợn | Nấm truffle | 60 giây |
| Cừu | Len | 60 giây |
| Ngựa | Phân hữu cơ | 60 giây |

Chỉ thời gian vừa **đã trưởng thành**, vừa có **thức ăn > 0 và nước > 0** mới
được cộng. Khi hết thức ăn/nước, giữ tiến độ đang có và tiếp tục sau khi ăn/uống.
Ví dụ, chu kỳ 30 giây đang đạt 20 giây thì thiếu nước: sau khi có nước chỉ cần
thêm 10 giây hợp lệ, không tính bù khoảng thời gian khát.

Clock chung đi qua một khoảng dài vẫn tính đúng phần trước/sau trưởng thành
và thời điểm thức ăn/nước cạn. Gọi lặp cùng timestamp hoặc lùi timestamp không
tạo thêm tuổi hay vật phẩm. Nhiều chu kỳ được tính bằng một phép chia, không
tạo vòng lặp theo từng sản phẩm.

## Sinh vật phẩm và nhặt vào túi

Các resource hiện dùng WORLD_DROP. Animal tạo `scenes/objects/item_pickup.tscn`
bằng icon sẵn có của item, trong cùng pen và nằm trong giới hạn chuồng. Những
lần sản xuất tiếp theo cộng vào cùng một đống tới khi người chơi nhặt hết;
vật phẩm đã rơi vẫn tồn tại nếu animal bị xóa.

Player có `ItemCollector`: đi lại gần phụ phẩm để tự nhặt vào inventory đang
được hotbar và túi đồ dùng chung. Túi đầy thì vật phẩm ở lại; nếu chỉ nhận được
một phần, phần còn lại vẫn nằm trên đất. Bỏ bớt đồ khi vẫn đứng cạnh sẽ tự thử
nhặt lại, không cần bước ra rồi vào lại. Việc nhặt chống gọi lặp và chống xử lý
đệ quy từ signal inventory, tránh nhân đôi item.

Pickup dùng layer vật lý 4 (bitmask 8), sensor của player chỉ theo dõi layer đó;
animal và các vật thể khác không nhặt được. Component pickup/collector tái sử
dụng được cho item khác ngoài phụ phẩm.

Với DIRECT_COLLECTION, output ở `ProductionComponent.stored_amount`; gọi
`animal.collect_produce(inventory)` để chuyển vào túi, trả về số nhận thực tế
và giữ phần dư. Chế độ này không tự tạo item trên đất.

## Các phần chịu trách nhiệm

- `AnimalNeedsComponent`: đồng hồ, mức no/nước và khoảng thời gian được cấp đủ.
- `AnimalGrowthComponent`: tuổi và mốc trưởng thành.
- `AnimalProductionComponent`: chu kỳ, tiến độ, số lượng chờ chuyển ra.
- `Animal` scene/controller: nối các component, lựa chọn sprite và tạo đống phụ phẩm.
- `ItemPickup`, `ItemCollector`: chuyển vật phẩm vào InventoryComponent dùng chung.

## Kiểm thử

```sh
python3 tests/run_animal_tests.py --godot /đường/dẫn/tới/godot
```

Runner kiểm tra cả ăn/uống trước đó, tuổi, fallback sprite và đổi sprite an
toàn, phần chu kỳ qua mốc trưởng thành, hết thức ăn/nước, cấp đồ lại sau một
khoảng dài, clock đi lùi/lặp, nhiều chu kỳ, tất cả 7 loài, nhận trực tiếp, gom
vật phẩm, túi đầy, nhặt một phần và sensor thật trên scene player.

`--all` chạy thêm các suite khác. Những lỗi UI/camera headless đã có trên mã
gốc vẫn được báo thất bại bình thường; runner không bỏ qua chúng.
