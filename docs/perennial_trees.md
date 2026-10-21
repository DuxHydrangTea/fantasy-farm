# Vườn cây ăn quả và rừng lấy gỗ

Hai khu đất mới dùng ô TileMap 16 px: trái `Rect2i(10,58,53,30)`, phải
`Rect2i(66,58,52,30)`. Lưới trồng cách nhau 48 px, chừa mép cho tán cây.
`TreePlantation` dựng khi world vào scene; không thay farmland hoặc chậu hoa.
Camera được mở xuống hết khu đất mới để click di chuyển tới mọi ô.

## Cách chơi và thông số mặc định

- Mua cây giống/hạt cây và rìu ở **Farm supplies** tại LaiBuon. Mỗi cây giống
  giá 60 xu; rìu 250 xu. Chọn vật phẩm trên hotbar, đứng gần vị trí trồng
  có khung xanh, nhấn Space hoặc chuột phải. Cây ăn quả chỉ trồng bên trái,
  cây lấy gỗ chỉ trồng bên phải. Khung đỏ báo vị trí không hợp lệ.
- Cây ăn quả có bốn loại: táo, đào, lê và cherry. Tưới một lần bằng bình tưới
  để bắt đầu lớn trong 180 giây. Cây trưởng thành không cần tưới; sau mỗi
  90 giây có 3 quả. C/E hoặc click cây có quả để hái ngay, không vung cuốc.
  Click từ xa tự đi đến cây rồi hái. Quả rơi từ tán, bay về nhân vật và hiện +3.
  Nếu túi thiếu chỗ, cây giữ nguyên quả. Cuốc + chuột phải bứng cây, trả
  một cây giống về túi; túi đầy thì giữ nguyên cây.
- Tổ ong trong phạm vi giảm thời gian hồi quả 25%, không cộng dồn nhiều tổ.
  Ong không hỗ trợ lúc mưa; phạm vi vẫn chịu ảnh hưởng thời tiết như hệ thống
  ong hiện có. Ong chỉ tăng tốc giai đoạn ra quả, không tăng tốc cây non.
- Oak, Birch, Spruce lớn trong 240 giây, không cần tưới. Cầm rìu, chặt 4 nhát
  để nhận 5 Wood và 1 hạt cùng loại. Thân đổ là hiệu ứng hình ảnh; trạng thái
  gốc được ghi ngay để save giữa hiệu ứng không tạo gỗ lần hai.
- Gốc cây tiếp tục chặn đường với collider 15×6 px. Dùng cuốc đào 3 nhát
  nhận 2 Root Wood và dọn ô đất. Nếu để nguyên, sau 120 giây gốc nảy chồi;
  chồi lớn trong 120 giây (bằng nửa thời gian trồng mới).
- Gỗ/hạt/gỗ rễ không chứa hết sẽ rơi thành ItemPickup, phần dư được lưu cùng
  các đống đồ hiện có. Produce Buyer mua cả bốn loại quả và hai loại gỗ.

## Dữ liệu và assets

`scripts/tree_definition.gd` và `trees/definitions/*.tres` chứa thời gian,
sản lượng, số nhát và textures. `items/trees` chứa cây giống, quả và gỗ.
`scripts/setup/setup_tree_resources.py` có thể dựng lại các resource mặc định;
không chạy lại nếu đã chỉnh thông số thủ công trong các resource cây.

Fruit_Trees_Fruit_Objects.png thực tế có 5 ô: nho, táo, lê, đào, cherry.
Các cây hiện tại dùng cột 1/2/3/4 tương ứng, bỏ ô nho. Atlas gỗ lấy theo
chiều rộng từng file chia 3 (Big Birch rộng 96, Oak/Spruce rộng 192),
không giả định mọi frame đều 64 px. Frame 0 là gốc, 1 là cây, 2 là tán đổ.
Sprite neo theo pixel cuối có alpha để collider luôn khớp gốc.

`FruitTree` và `TimberTree` kế thừa `PerennialTree`; `TreeInteraction` khóa
mục tiêu, slot và công cụ từ đầu động tác dùng công cụ, chỉ commit một lần tại frame
tác động do FarmingActionComponent cấu hình. Hái quả commit ngay khi trong tầm;
hiệu ứng rơi/bay chỉ trình diễn, không cộng lại vật phẩm. C dùng để hái khi cây có quả,
kể cả đang cầm cuốc; chuột phải dùng công cụ đang chọn.

Save v11 thêm danh sách `trees`. Save v1–v10 được migrate với danh sách rỗng,
giữ nguyên inventory và tiến độ cũ. TreeSaveSchema kiểm tra ID trong catalog,
vùng/lưới, timestamp, tiến độ, số nhát và ô trùng trước khi thay đổi world.
Tiến độ dựa vào FarmClock/TimeManager, không dùng Timer cho sinh trưởng.
Mỗi cây lưu `last_at`, không tính lặp thời gian và không lùi khi đồng hồ lùi.
Mỗi cây chỉ giữ tối đa một lứa quả, không tích vô hạn khi offline.

Tán cây đung đưa theo gió bằng shader chia sẻ theo texture; mỗi vị trí có nhịp
riêng, chân cây và collider giữ cố định. Gốc cây đã chặt không đung đưa.

## Kiểm tra

```powershell
python tests/run_tree_tests.py --godot C:\path\to\godot.exe
python tests/run_tree_tests.py --godot C:\path\to\godot.exe --all
python tests/run_tree_tests.py --godot C:\path\to\godot.exe --preview
python tests/run_tree_tests.py --godot C:\path\to\godot.exe --validate
```

Runner dùng project/cache/user-data riêng và tắt editor plugins trong project
tạm. Preview tạo `.godot/tree-preview.png` với các stage và gốc trong hai khu
đất thật; không bind SaveManager hoặc thêm cây thử vào save của người chơi.
Validator in riêng diagnostics của tính năng cây; `counts.warnings` vẫn bao
gồm warning có sẵn từ các dependency được Godot nạp theo.
