# Nhà bếp và chế biến món ăn (Kitchen / Cooking)

Mua **Bếp lò** giá **2,500 xu** từ tab Supplies của LaiBuon (đặt cùng nhóm với
Beehive). Đặt bếp trên đất đã mở bằng ghost preview tái dùng toàn bộ
`BeehivePlacementComponent`:_snap lưới farm, phạm vi 96 world pixels, đỏ khi vị
trí không hợp lệ, chỉ trừ 1 item khi đặt thành công. Bếp là công trình vĩnh viễn
trong phiên bản đầu, tương tự hive.

## Quy tắc đã chốt

| Quy tắc | Giá trị |
| --- | --- |
| Kiểu chế biến | Một bếp generic, **nhận diện món theo nguyên liệu đã nạp** (không chọn recipe bằng UI). |
| Nguyên liệu | Nhập từ túi người chơi theo "gói nguyên vẹn" — trùng semantics nạp máng (`AnimalTrough`). |
| Chu kỳ nấu | 4 giờ thực/món (14,400s), chạy bằng timestamp `FarmClock`, không phụ thuộc delta. |
| Buffer đầu ra | Tối đa **20 món** chờ trong bếp; đầy buffer thì bếp nghỉ (không hỏng, không spoil). |
| Nhận diện recipe | Tập nguyên liệu nạp khớp đúng 1 recipe → món đó; nếu nhiều recipe khớp, chọn recipe có **tổng giá bán output cao nhất** (deterministic, không phụ thuộc thứ tự nạp). |
| Output | `ItemType.PRODUCE` — bán được ngay qua `ProduceBuyer`, thêm đơn giá vào `produce_prices.tres`. |
| Gate mở khóa | Bếp xuất hiện trong shop sau khi mở ≥ 4 cột đất (`land_columns`). |

Nguyên liệu không bị tiêu hao khi chưa khớp recipe: bếp chỉ "khóa" nguyên liệu
vào batch kế tiếp khi có ít nhất 1 recipe khả dụng; ngược lại stock nằm chờ,
E hoàn nguyên về túi.

## Recipe và dữ liệu

`CookingRecipe extends Resource` đặt tại `resources/kitchen/recipes/*.tres`:

```
recipe_id: StringName
inputs: Array[{item: ItemDefinition, amount: int}]   # 1–3 loại
output_item: ItemDefinition                            # PRODUCE
output_amount: int                                     # 1–5
cook_seconds: float = 14400.0
```

Bộ món khởi đầu (giá bán đặt theo công thức `ceil(2.2 × tổng giá input)`,
chốt số cuối khi nhập catalog — nguyên tắc: món nấu luôn > tổng giá nguyên
liệu thô):

| Món | Nguyên liệu (đề xuất) | Giá bán (đề xuất) |
| --- | --- | --- |
| Trứng chiên | 1 trứng gà | 200 |
| Trứng ngỗng hấp | 1 trứng ngỗng | 340 |
| Bánh mì | 2 lúa mì + 1 trứng vịt | 700 |
| Salad trái cây | 2 trái cây bất kỳ (táo/đào/lê) | 800 |
| Mật ong hoa nướng | 1 mật Floral + 1 lúa mì | 1,000 |

Món ra lò nhận vào `order_catalog`: thêm 1–2 template đơn yêu cầu món nấu với
hệ số 1.25–1.4× hiện hành của master spec.

## Thành phần

| Type | Trách nhiệm |
| --- | --- |
| `CookingRecipe` | Data món: inputs/output/thời gian. |
| `Kitchen` (StaticBody2D) | Va chạm, sprite (2 vùng idle/cooking như Bee_Nest), persistent ID, lệnh thu batch. |
| `KitchenProductionComponent` | Stock nguyên liệu, batch đang nấu, buffer output, `advance(now)` tính theo đoạn biên. |
| `KitchenPlacementComponent` | Tái dùng ghost preview của hive placement. |
| `KitchenSystem` | Điều phối farm-level như `ApiarySystem`: gom các bếp, chạy trên `clock.tick`, boundary segments cho offline. |

Mô phỏngoffline: `KitchenSystem.advance(timestamp)` chia đoạn tại biên "hết
stock", "đầy buffer", "batch xong" — cùng phép toán mà
`BeehiveProductionComponent.advance()` và máng đang chứng minh. Restore cài
state thô tại `saved_at` rồi advance một lần qua các biên offline; load lặp
cùng mốc thời gian không nhân món.

## Tương tác, UI, save

`InteractionTarget.Kind` thêm `KITCHEN` (append cuối enum như đã làm với
BEEHIVE). E/hướng bếp: mở panel nạp nguyên liệu (grid chọn item từ túi, clone
`inventory_slot.gd`) + nút "Hoàn nguyên stock". Badge trên đầu bếp hiển thị
món đang nấu, số món chờ, thời gian còn; khi buffer có món → `Collect …`.
Outline/badge dùng đúng tier ưu tiên của hive.

NPC **chef** (sprite đã import, chưa dùng) trở thành merchant phụ kiện/bếp
hoặc chỉ nằm trang trí bên cạnh bếp trong v1 — không bắt buộc.

Save schema **v21** thêm `kitchens`: mỗi row gồm persistent ID, vị trí, stock
nguyên liệu (item_id + số lượng), recipe đang chạy + work đã tích, buffer
output (item_id + số lượng). Migration v1…v20 khởi tạo list rỗng, không tặng
bếp, không đụng state khác. Validation: recipe/ingredient nằm trong
`SaveCatalog` allowlist (thêm `resources/kitchen` vào các thư mục quét), work
hữu hạn, buffer ≤ 20, không trùng ID/ô đất với crop/hive/pen.

Tests: `tests/unit/test_kitchen_production.gd` (batch, buffer cap, nhận diện
recipe deterministic, offline segments) + `tests/integration/test_kitchen.gd`
(đặt bếp, nạp/thu, bán món, đơn hàng yêu cầu món, migration v20→v21, disk
roundtrip, replay offline).
