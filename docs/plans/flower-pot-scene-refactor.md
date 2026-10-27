# Kế hoạch tách hoa, chậu và bố cục scene

Trạng thái: đã triển khai. Hướng dẫn sử dụng tại `docs/flower-pot-customization.md`.

Kết quả kiểm tra: 50 test unit/integration của hoa, scene, skin, tương tác và ong đạt; một test migration save cũ đạt. Preview editor xác nhận 112 node hiển thị mà không mutate state. Lint không có lỗi/cảnh báo. Bộ unified interaction rộng hơn có ba lỗi fixture thức ăn/đất; đã đối chiếu và xác nhận cùng lỗi với adapter trước refactor. Fingerprint texture chậu người dùng chỉnh không thay đổi.

## Mục tiêu và phạm vi

- Hoa và chậu dùng texture độc lập. Sửa texture chậu đang được scene tham chiếu sẽ cập nhật chậu trống lẫn chậu có cây sau khi Godot import/reload, không chạy script ghép ảnh.
- Lưu 112 instance FlowerPot trong flower_garden.tscn, thành bốn khối 7x4. Chỉnh vị trí trong editor và lưu scene sẽ được giữ nguyên khi chạy.
- Cho mỗi instance chọn loại chậu và chỉnh offset hình hoa riêng, chuẩn bị cho nhiều kiểu chậu.
- Giữ diện tích vườn, vị trí hiện tại, 30 loài, năm stage, thời gian lớn, sản lượng, tưới, thu hoạch, kho đồ, save cũ và ong.
- Không bổ sung chức năng mua/đổi chậu trong gameplay ở đợt refactor này.

## Hợp đồng cần giữ

- FlowerPot vẫn là root StaticBody2D và đầu mối tương tác. Giữ cell, definition, timestamps, stage, reserved và các method plant/water/refresh/harvest/clear/capture/restore_state, tín hiệu changed.
- FlowerGarden tiếp tục cung cấp pots: Dictionary[Vector2i, FlowerPot], pots[cell], persistent_id và lịch GrowthSchedule. Không lấy thứ tự child hoặc NodePath làm ID save.
- Giữ chính xác 112 cell hiện tại và ba cell tổ ong. Giữ khả năng đọc 180 cây cũ và hàng đợi cây dư.
- FlowerDefinition.stage_frames tiếp tục có năm stage và animation grow. Giữ timing/sáu frame đang được consumer dùng; hoa nở tĩnh không được mô tả thành animation mới.
- Mọi thay đổi về hình ảnh nằm ở presentation; không emit changed hoặc thực hiện giao dịch kho đồ khi đổi skin/preview.

## Cấu trúc đích

```text
FlowerGarden
├── Floor
└── Pots
    ├── BlockTopLeft
    ├── BlockTopRight
    ├── BlockBottomLeft
    └── BlockBottomRight
        └── FlowerPot (instance của flower_pot.tscn, cell ổn định)
            ├── VisualRoot
            │   ├── PotSprite (Sprite2D)
            │   └── PlantSocket (Node2D, mốc mặc định của loại chậu)
            │       └── PlantOffset (Node2D, offset riêng có thể chỉnh)
            │           └── Flower (AnimatedSprite2D, chỉ chứa cây)
            ├── CollisionShape2D
            ├── Focus
            └── Progress
```

Trước khi chốt tên node, kiểm tra NodePath trong scene/script/test. Giữ alias sprite cho Flower trong giai đoạn chuyển tiếp nếu consumer cũ còn dùng.

- Root FlowerPot quyết định vị trí gameplay/collision/Y-sort. VisualRoot chỉ chỉnh hình ảnh.
- PotSprite đọc texture dùng chung. Flower bị ẩn khi chậu trống; PotSprite vẫn hiển thị.
- PlantSocket lấy mốc từ cấu hình loại chậu. PlantOffset là chỉnh tay theo instance; controller không reset position/scale này mỗi lần refresh.
- Giữ thứ tự vẽ chậu/cây và Y-sort giữa các chậu. Chỉ thêm lớp miệng chậu phía trước nếu một kiểu chậu thực sự cần che gốc cây.
- Giữ nguyên collision trong đợt này, không tự suy ra collider từ kích thước PNG.

## Resource và trách nhiệm

- Thêm PotDefinition Resource: pot_id, texture, offset hình chậu, plant socket, mặc định cho hiển thị. Dùng chung resource cho các chậu cùng loại; chỉnh riêng phải tạo resource riêng hoặc dùng PlantOffset của instance.
- FlowerDefinition chỉ sở hữu art/cấu hình cây. Chuyển stage_frames về ảnh chỉ có cây, bỏ phần chậu baked-in.
- FlowerPotVisual/controller hiển thị áp PotDefinition, chọn stage và bật/tắt cây. Không phụ thuộc inventory, save hoặc lịch tăng trưởng.
- FlowerPot giữ state/use case hiện tại và gọi controller đồng bộ hiển thị.
- FlowerGarden đăng ký các instance scene, không tạo hoặc đặt lại vị trí từ vòng lặp _ready.
- Không thêm event bus, command framework hoặc autoload cho refactor này. Dùng các method và signal hiện có; call parent-child trực tiếp cho hiển thị.

Các file dự kiến:

```text
components/flowers/flower_pot.gd                 # state/use case giữ ổn định
components/flowers/flower_pot_visual.gd          # presentation
scripts/pot_definition.gd                       # resource loại chậu
resources/pots/clay_pot.tres                    # tham chiếu texture người dùng đang sửa
scenes/flowers/flower_pot.tscn                  # node hoa/chậu riêng
scenes/flowers/flower_garden.tscn               # 112 instance được lưu
flowers/frames/*.tres                           # chỉ chứa cây
```

## Triển khai theo từng bước

1. Chốt baseline: snapshot các file liên quan, ảnh vườn hiện tại và test hiện tại. Giữ ảnh chậu người dùng đã chỉnh làm nguồn chính; không lấy lại bản cũ trong output.
2. Chuẩn bị art chỉ có cây: dùng nguyên 30 PNG hoa 32x32. Tách stage mầm từ nguồn animation gốc, bỏ chậu cũ, giữ frame order/timing. Chuẩn hóa mốc gốc cây cho mọi stage; không thay art bằng AI hoặc tự vẽ lại.
3. Tách presentation trong flower_pot.tscn: thêm PotSprite và các node anchor/offset, nối controller. Đối chiếu ảnh trước/sau để giữ chính xác độ hạ cây ba pixel đã duyệt. Cập nhật empty/harvest/clear để chỉ đổi sự hiện diện của cây.
4. Dùng công cụ editor một lần để tạo 112 instance theo bố cục đã duyệt và ghi vào flower_garden.tscn, kèm owner đúng. Sau đó bỏ cơ chế runtime tạo node và áp position. _ready chỉ thu thập, kiểm tra cell trùng/thiếu, đăng ký garden và signal một lần.
5. Rà consumer: vị trí tổ ong và khoảng cách phải đọc instance thực tế, không đọc Layout.position_for khi chạy. Đổi các phép so sánh pot.position sang global_position hoặc garden.to_local(global_position) nếu chậu nằm trong node khối. Overlay ong dùng vị trí các cell thực tế.
6. Rà interaction: các điểm đọc trực tiếp FlowerPot.sprite được chuyển qua API hiển thị. Picking/highlight phải tính cả chậu và cây; chậu trống vẫn chọn được khi Flower bị ẩn. Progress và focus có anchor riêng, không phụ thuộc height của PNG ghép.
7. Xóa đường đi ghép ảnh sau khi không còn consumer. Script build không được copy đè texture chậu đã chỉnh. Dọn composite và tài nguyên empty_frames cũ sau khi tìm toàn bộ reference và xác minh không còn dùng.

Mỗi bước chỉ chuyển sang bước tiếp theo khi các test liên quan đạt; không đổi core gameplay cùng lúc với cấu trúc scene.

## Save và việc custom

- Giữ cell là định danh ổn định, position là cấu hình scene. Kéo node không đổi ID; load save không ghi đè vị trí scene.
- Giữ cơ chế overflow hiện có. Dữ liệu của slot không còn tồn tại không được âm thầm bỏ.
- Vị trí fixed hive phải theo root FlowerPot có cell tương ứng, kể cả khi di chuyển node cha của khối. Chuẩn hóa vị trí hive từ scene đã tin cậy sau khi kiểm tra garden_id/slot; kiểm tra placement/collision trước khi mutate world. Không dựa riêng vào tọa độ lưới cũ hardcode.
- Chọn loại chậu trong scene không cần đổi schema save ở đợt này. Nếu sau này người chơi đổi chậu lúc chạy, thêm pot_id tùy chọn với migration/default; không serialize đường dẫn resource tùy ý từ JSON.
- Preview editor dùng preview_flower/preview_stage riêng, không tạo cây khởi đầu, tiến thời gian, thay inventory hoặc ghi save.

## Điều kiện nghiệm thu

- Sửa PNG chậu dùng chung, để Godot reimport và chạy lại: cả chậu trống lẫn có cây cập nhật mà không bake.
- Chọn hai loại chậu ở hai instance: đổi một loại không đổi ảnh hoa hoặc loại còn lại.
- Kéo một FlowerPot và một node khối, chỉnh PlantOffset, lưu/mở lại/chạy scene: transform được giữ. Tổ ong, focus, khoảng cách tương tác và click target đi theo đúng vị trí mới.
- Chạy đủ 30 loài qua năm stage: tưới một lần, tăng trưởng theo timestamp, thu hoạch đúng số lượng và đúng một lần; kho đầy không mất cây.
- Save/load cây mới và save cũ đủ 180 cây, overflow, starter flowers, khóa mở vườn, ba tổ ong và recipe đều giữ hành vi.
- Kiểm tra editor không phát sinh instance/tín hiệu trùng, preview không mutate state.
- Kiểm tra bounds bằng tổng vùng pixel hiển thị của PotSprite và Flower sau transform, không dùng kích thước composite cũ. Chụp đủ bốn khối trong game; không tràn viền hoặc sai thứ tự vẽ.
- Lint và các suite flower garden, flower pack 30, honey garden, save migration đều đạt. Chỉ dọn asset/code cũ sau khi xác minh reference.

## Điểm rủi ro đã thấy trong code

- _update_visual hiện reset transform và lấy height PNG ghép: phải bỏ để custom node không bị ghi đè.
- HoneyGardenSystem.center_point và BeehiveRangeDisplay còn đọc công thức layout: phải chuyển sang node thực tế.
- InteractionTarget/Resolver còn đọc .sprite trực tiếp: cần API/fallback cho chậu trống và bounds hai lớp.
- Các node khối làm thay đổi ý nghĩa local position; không được dùng local position của hai parent khác nhau để tính khoảng cách.
- Resource dùng chung có thể bị sửa ảnh hưởng toàn bộ instance; phân biệt cấu hình theo loại với override riêng.
- Các test hiện tại khẳng định texture 32x48/composite path phải đổi sang kiểm tra hai lớp và kết quả nhìn thấy, không giữ assertion khóa kiến trúc cũ.
