# Thiết kế farming và world theo lưới

Cập nhật: 2026-10-16. Tài liệu thiết kế cho `fantasy-farm`, theo hướng game nông trại lấy cảm hứng từ Stardew Valley và tận dụng asset hiện có.

Đây là đích thiết kế và lộ trình học, không phải mô tả các hệ thống đã triển khai. Hướng dẫn từng tính năng tiếp tục tuân theo `docs/RULES.md`: giải thích bản chất, thiết lập Editor, code nhỏ có kiểu, giải thích API và chạy thử trước khi đi tiếp.

## 1. Phạm vi và thay đổi so với thiết kế cũ

Các yêu cầu hiện tại:

- Người chơi có thể cuốc đất trên mọi ô hợp lệ, không giới hạn ở luống hoặc scene ô trồng bố trí sẵn.
- Có thể tưới, gieo hạt trên đất đã cuốc, chăm cây và thu hoạch.
- Có thể chặt cây gỗ và đặt vật thể như hàng rào; về sau mở rộng sang công trình chiếm nhiều ô.
- Hình đất tự nối theo các ô lân cận bằng terrain khi asset đáp ứng đủ các cạnh/góc cần thiết.
- Tương tác dùng ô trước mặt theo `facing_direction`, không dùng con trỏ chuột để chọn ô.
- Thêm state machine cho nhân vật khi bắt đầu triển khai hành động dùng công cụ, gồm cuốc và tưới.

Thiết kế này thay thế phương án cũ «mỗi ô cố định là một FarmPlot.tscn». Không làm theo các code mẫu FarmPlot/FarmLand/ToolState/Player của bản tài liệu trước: chúng không còn khớp với mô hình lưới và cấu trúc Player đang học.

«Cuốc tùy ý» nghĩa là bất kỳ ô nào đáp ứng luật canh tác. Nước, đá nền, đường lát, nền nhà hoặc ngoài ranh giới bản đồ có thể không cho phép cuốc. Chặt cây gỗ khác với thu hoạch hoa màu.

## 2. Dữ liệu ô: các thuộc tính độc lập

Không gộp mọi tình huống vào một enum như `WET_WITH_CROP`, `DRY_WITH_CROP`, `BUILDING`. Một ô có thể đồng thời đã cuốc, đang ướt và có cây.

| Nhóm | Dữ liệu dự kiến | Vai trò |
| --- | --- | --- |
| Định danh | `map_id` + tọa độ ô `Vector2i` | Nhận diện ô ổn định, dùng cho truy vấn và save |
| Nền | Loại nền, khả năng cuốc/đặt vật thể | Thông tin cơ bản lấy từ bản đồ và định nghĩa terrain |
| Đất | `is_tilled: bool` | Đã cuốc hay chưa |
| Nước | `wet_remaining: float` nếu chọn mô hình thời gian | Độ ướt độc lập với cây; có thể suy ra khô/ướt |
| Cây trồng | ID loại cây và tiến độ tăng trưởng | Không có cây thì ID rỗng; stage suy ra từ tiến độ |
| Chiếm chỗ | ID vật thể hoặc không có | Tra ra cây gỗ, đá, hàng rào hoặc công trình |

Tên trường là dự kiến, sẽ chốt khi viết từng script. Định nghĩa cây/công trình dùng Resource chung; trạng thái runtime thuộc ô hoặc instance, không sửa Resource cấu hình để cập nhật một ô.

`WorldGrid` sở hữu dữ liệu runtime của các ô và chỉ mục chiếm chỗ. Các controller gửi yêu cầu qua API; Player, UI và sprite không trực tiếp gán dữ liệu ô. Thay đổi hợp lệ cập nhật dữ liệu trước, rồi phát sự kiện để phần hiển thị cập nhật.

Chỉ cần lưu phần thay đổi so với bản đồ nền cùng trạng thái cần duy trì. Không cần tạo một Node cho mọi ô trống hoặc cấp dữ liệu tăng trưởng cho mọi ô trên bản đồ.

### Luật thao tác dự kiến

| Thao tác | Điều kiện chính | Kết quả |
| --- | --- | --- |
| Cuốc | Trong map, nền cho phép, chưa cuốc, không có vật chặn | Đánh dấu đã cuốc, cập nhật hình luống và vùng lân cận |
| Tưới | Đã cuốc | Cập nhật nước theo luật được chọn; có thể tưới trước khi gieo |
| Trồng | Đã cuốc, chưa có cây, không bị chiếm chỗ, có hạt | Tạo dữ liệu cây và trừ hạt đúng một lần |
| Thu hoạch | Cây trưởng thành, có thể nhận sản phẩm | Nhận sản phẩm và cập nhật/xóa cây theo định nghĩa |
| Chặt cây gỗ | Đúng đối tượng, đúng công cụ, trong tầm | Trừ sức chịu đòn; khi bị đốn, cập nhật vật thể và ô chiếm chỗ |
| Đặt vật thể | Toàn bộ diện tích hợp lệ, đủ vật phẩm, không chồng vật cản/Player | Đăng ký vật thể và các ô chiếm chỗ cùng nhau |

Bản đầu đề xuất không cho công trình đè lên cây trồng. Đất đã cuốc có được đặt công trình hay phải hoàn nguyên trước là lựa chọn cần chốt. Các kiểm tra phải thống nhất giữa bản xem trước và lúc thực hiện thật.

## 3. Thành phần và quyền sở hữu

| Thành phần dự kiến | Trách nhiệm |
| --- | --- |
| `WorldGrid` | Dữ liệu ô, quy đổi tọa độ, ranh giới map, đăng ký/hủy chiếm chỗ và API thay đổi dữ liệu |
| `TargetingComponent` | Tính ô trước mặt từ vị trí chân và hướng nhìn; thông báo khi mục tiêu đổi |
| `FarmingController` | Luật cuốc/tưới/trồng/thu hoạch; yêu cầu WorldGrid cập nhật dữ liệu hợp lệ |
| `PlacementController` | Chọn vật thể, hiển thị bản xem trước, kiểm tra footprint và yêu cầu đặt/gỡ |
| Phần hiển thị farming | Nghe thay đổi dữ liệu, cập nhật tile đất, nước và hình cây |
| Scene cây gỗ/công trình | Hình, collision và hành vi riêng; giữ trạng thái riêng như sức chịu đòn của cây |
| `CropDefinition` / định nghĩa công trình | Cấu hình dùng chung: hình, thời gian, sản phẩm, diện tích, điều kiện |
| Player | Điều phối input, các component và yêu cầu hành động |
| State machine của nhân vật | Cho phép/chặn hành động, điều phối vòng đời dùng công cụ |
| `AnimationComponent` | Phát animation tương ứng, không quyết định luật đất hay quyền hành động |

`WorldGrid` và các controller thuộc scene world, chưa cần Autoload. Mỗi bản đồ có dữ liệu lưới riêng. Tên `WorldGridManager` hoặc `PlacementManager` không bắt buộc; ranh giới trách nhiệm quan trọng hơn hậu tố tên.

Bản đầu không cần mọi lớp có ngay một script riêng. Chỉ tách khi triển khai tới chức năng đó, giữ API và quyền sở hữu rõ ràng. Node cha gọi xuống, component con báo lên bằng signal; không dùng global event bus cho mọi sự kiện cục bộ.

## 4. Chọn ô trước mặt

Luồng mục tiêu cho lưới vuông trực giao:

```text
Vị trí chân Player trong world
    → chuyển về local của lớp lưới chuẩn
    → chuyển thành ô Player đang đứng
    → cộng hướng nhìn một ô
    → kiểm tra ranh giới
    → hiển thị khung chọn ở tâm ô mục tiêu
```

- Dùng một lưới chuẩn thống nhất cho nền, farming và placement. Các layer phải cùng kích thước ô và cùng căn lưới.
- Dùng `to_local()` rồi `local_to_map()` để xác định ô; dùng `map_to_local()` và chuyển về world để đặt highlight. Không lấy tọa độ world chia kích thước tile mà bỏ qua transform của layer.
- Lấy điểm chân/gốc nhân vật phù hợp với scene, không mặc định tâm texture chính là chân.
- Hướng nhìn giữ nguyên khi đứng yên; dùng bốn hướng từ `FacingComponent`.
- Cập nhật mục tiêu khi hướng nhìn hoặc ô Player đang đứng thay đổi. Chỉ nghe signal đổi hướng là chưa đủ khi đi thẳng.
- Khi bắt đầu hành động, chốt map, ô mục tiêu, hướng và công cụ. Không để input tiếp theo đổi mục tiêu giữa animation.
- Trước frame tác động, kiểm tra lại ô/đối tượng còn hợp lệ.

Highlight cho biết vị trí đang chọn; trạng thái hợp lệ phụ thuộc công cụ đang chọn. Đây là hệ thống dùng chung cho cuốc, tưới, chặt và điểm gốc của placement.

## 5. Terrain và hiển thị

Đất dùng `TileMapLayer`; cấu hình Terrain Sets và các cạnh/góc trong TileSet trước khi dùng `set_cells_terrain_connect()` lúc chạy. Terrain chọn hình có sẵn, không tự sinh hình cạnh/góc mà asset thiếu.

Tách hai câu hỏi:

- Hình dạng luống phụ thuộc những ô nào đã cuốc.
- Độ ướt phụ thuộc dữ liệu nước của từng ô.

Tưới một ô giữa luống không được làm mất kết nối hình luống với các ô khô xung quanh. Sau khi xem asset, chọn cách thể hiện phù hợp: lớp phủ ướt hoặc bộ biến thể khô/ướt giữ cùng cấu trúc cạnh/góc. Chưa chốt cách vẽ trước khi kiểm tra asset.

Khi thêm/xóa đất đã cuốc, cập nhật cả ô và các hàng xóm có hình nối bị ảnh hưởng. Dữ liệu gameplay của hàng xóm không đổi chỉ vì tile hiển thị được chọn lại.

TileSet custom data phù hợp với thuộc tính nền dùng chung như khả năng canh tác. Không lưu trạng thái nước/cây riêng từng ô bằng cách sửa TileData dùng chung.

Hàng rào có quy tắc nối theo hàng rào lân cận, tách khỏi quy tắc nối luống đất. Thêm hoặc gỡ một đoạn cần cập nhật các đoạn liên quan.

Cây trồng, cây gỗ và công trình có thể dùng scene riêng để hỗ trợ hình, collision và hành vi. Y-sort dựa trên gốc/chân; đất nền nằm dưới nhân vật. Không cần tạo scene ô đất chỉ để có hình cây trên ô đó.

## 6. Chiếm chỗ và placement

- Vật thể có một ô gốc và danh sách offset ô tạo thành footprint.
- Hàng rào bản đầu có thể chiếm một ô; công trình lớn chiếm nhiều ô.
- Mọi ô của một công trình trỏ về cùng ID vật thể. Gỡ từ một ô thuộc footprint phải tìm được vật thể chủ quản.
- Kiểm tra toàn bộ footprint trước khi thay đổi. Nếu một ô không hợp lệ thì không đặt một phần, không trừ vật phẩm.
- Kiểm tra va chạm với Player/NPC hoặc vật thể động khi đặt; chỉ mục ô không tự thay thế mọi kiểm tra vật lý.
- Gỡ vật thể giải phóng toàn bộ footprint và cập nhật hình nối/collision liên quan.
- Cây gỗ nhận thao tác tại gốc hoặc footprint; tán cây phủ lên ô khác không tự đồng nghĩa chiếm toàn bộ các ô hình ảnh đó.
- Cây gỗ đặt sẵn trong Editor cũng phải được đăng ký chiếm chỗ trước khi cho phép canh tác/placement.

Bản đầu chỉ làm đặt/gỡ một hàng rào một ô. Xoay công trình, footprint không chữ nhật và bản xem trước phức tạp để sau.

## 7. State machine: bắt đầu khi có hành động dùng công cụ

Không cần thêm state machine chỉ để chọn ô hoặc phát idle/walk. Thêm khi bắt đầu dùng cuốc đầu tiên; bình tưới dùng cùng vòng đời hành động.

| State ban đầu | Vai trò |
| --- | --- |
| `Locomotion` | Nhận hướng di chuyển; AnimationComponent chọn idle/walk |
| `UsingTool` | Khóa di chuyển và hướng, chốt hành động, chạy animation, yêu cầu tác động một lần, chờ kết thúc |

Cuốc và tưới dùng chung `UsingTool`, cấu hình công cụ quyết định animation và tác động. Chỉ tách state riêng khi hành vi đủ khác biệt. Không mặc định cần IdleState, WalkState, HoeState và WaterState ngay từ đầu.

```text
Input yêu cầu dùng công cụ
    → kiểm tra có thể bắt đầu và chốt ô/hướng/công cụ
    → vào UsingTool, dừng di chuyển
    → phát animation hành động không loop
    → tới frame tác động, phát yêu cầu đúng một lần
    → controller kiểm tra lại và thực hiện thao tác hợp lệ
    → animation kết thúc, trở về Locomotion
```

- State machine quyết định nhân vật được làm gì; AnimationComponent thể hiện bằng hình. `FacingComponent` tiếp tục sở hữu hướng nhìn.
- Trong UsingTool, chặn luồng input trực tiếp vào MovementComponent/FacingComponent và chặn cập nhật idle/walk ghi đè animation hành động. Chỉ đổi state mà giữ nguyên các kết nối input hiện tại sẽ không tự khóa nhân vật.
- Khi trở về Locomotion, đọc lại hướng input hiện tại: input controller chỉ phát khi hướng đổi có thể không tự phát lại phím đang giữ.
- Frame tác động được cấu hình theo clip thực tế, không hardcode chung cho mọi công cụ. Bảo đảm chỉ áp dụng một lần và không bỏ sót khi frame hiển thị bị nhảy.
- Kiểm tra clip tồn tại trước khi vào hành động; clip thiếu không được làm nhân vật kẹt state.
- Animation hành động tắt Loop; `animation_finished` không phát cho clip lặp.
- Hủy trước tác động thì không sửa world; hủy sau tác động không được áp dụng thêm lần nữa. Dọn kết nối khi rời state.
- State của Player không phải trạng thái đất. Đất vẫn thuộc WorldGrid.

## 8. Cây trồng và thời gian: giữ đề xuất cũ để chốt sau

Asset hoa màu hiện có bốn texture stage; xem `crop_resources.md`. AtlasTexture chỉ là hình ảnh, chưa phải cấu hình tăng trưởng/sản lượng.

Các mục sau là đề xuất từ tài liệu cũ, chưa coi là yêu cầu mới đã chốt:

- Tiến độ theo thời gian chơi, không phụ thuộc ngày; pause/thoát world dừng tiến độ, chưa tăng trưởng offline.
- Đất tự khô, ví dụ sau 300 giây.
- Cây lớn cả khi khô; tưới đất khô cộng tiến độ bằng 5% tổng thời gian ban đầu.
- Tưới lại đất ướt không cộng bonus và không reset thời gian ướt.
- Tưới ô trống được phép; cây gieo sau đó bắt đầu tiến độ 0, không nhận bonus hồi tố.
- Stage 4 là trưởng thành; thu hoạch xóa cây nhưng giữ đất/nước; chưa tự mọc lại.

Nếu giữ cách chia thời gian cũ: stage 1 từ 0 đến dưới 1/3; stage 2 từ 1/3 đến dưới 2/3; stage 3 từ 2/3 đến dưới 100%; stage 4 tại 100%. Nếu muốn thời lượng từng stage riêng, đưa ngưỡng vào CropDefinition.

Chốt lại mô hình thời gian khi tới bước tăng trưởng. Dữ liệu ô giữ tách biệt để hỗ trợ cả phương án theo thời gian hoặc theo ngày mà không gộp lại toàn bộ trạng thái.

Không đặt một `_process()` cho mọi ô trống. Khi triển khai đồng hồ, chỉ theo dõi ô còn nước hoặc cây cần tăng trưởng; cách cập nhật cụ thể quyết định theo quy mô và độ dễ hiểu.

## 9. Inventory và lưu/tải

Triển khai sau khi vòng lặp thử nghiệm đã hoạt động:

- Trừ hạt/vật phẩm và áp dụng tác động đúng một lần khi thao tác thực sự thành công.
- Khi thu hoạch, kiểm tra/đặt trước sức chứa trước khi xóa cây; túi đầy không được làm mất sản phẩm.
- Save có phiên bản định dạng, `map_id`, tọa độ ô dưới dạng x/y, trạng thái đất/nước/cây và danh sách vật thể có ID, ô gốc, footprint hoặc định nghĩa để khôi phục footprint.
- Không serialize Node hoặc dùng tham chiếu runtime làm ID bền vững.
- Lưu các ô khác nền và các thay đổi của vật thể dựng sẵn, kể cả cây đã bị chặt. Không lưu cây bị chặt thì load map nền sẽ làm nó xuất hiện lại.
- Load dữ liệu nền → áp thay đổi ô/vật thể → khôi phục chỉ mục chiếm chỗ → dựng lại hình/terrain/collision → cho phép tương tác.
- Kiểm tra ID định nghĩa, ranh giới và dữ liệu cũ; trường mới dùng giá trị mặc định phù hợp. Hình terrain và stage có thể tính lại từ dữ liệu.
- Chưa chốt định dạng save hoặc tăng trưởng offline ở bước hiện tại.

## 10. Lộ trình học và checkpoint

| Bước | Kết quả có thể chạy thử |
| --- | --- |
| 1. Ô trước mặt | Highlight đúng khi quay, đi thẳng qua ô mới và đứng yên; kiểm tra cả map có offset |
| 2. Lưới và luật nền | Phân biệt ô cuốc được, nước/đá và ngoài map; đọc dữ liệu mà chưa sửa world |
| 3. Cuốc + state machine | Một lượt dùng cuốc đổi đúng một ô; khóa di chuyển/hướng; hành động kết thúc bình thường |
| 4. Terrain | Cuốc/xóa ô cạnh, góc, ở giữa luống đều nối hình đúng; không cần ảnh hưởng dữ liệu ô bên cạnh |
| 5. Tưới | Đổi nước trên đúng ô; không phá hình nối đất hoặc bị idle/walk ngắt hành động |
| 6. Một loại cây | Gieo, tăng trưởng, thu hoạch; ô có cây và nước vẫn là hai thuộc tính độc lập |
| 7. Chặt cây gỗ | Chỉ tác động cây ở ô mục tiêu; đốn xong giải phóng đúng ô |
| 8. Hàng rào | Preview, đặt/gỡ một ô, chặn chồng lấn và nối hình với hàng xóm |
| 9. Công trình nhiều ô | Kiểm tra cả footprint; đặt/gỡ toàn bộ, không để sót ô bị chiếm |
| 10. Inventory + save/load | Không trừ đồ hai lần; load giữ đất/cây/công trình và cây đã chặt |

Mỗi bước chia tiếp thành các micro-step theo RULES, dừng tại checkpoint để người học xác nhận. Không tạo toàn bộ framework trước khi có một vòng lặp chơi được. Chưa cần chunk streaming, Server APIs, đa luồng hoặc hệ thống ngày phức tạp.

## 11. Bối cảnh repo và tài liệu tham khảo

Hiện repo có Player cùng các component input, movement, facing và animation; world dùng TileMapLayer. `world/farm/FarmWorld.tscn` có lớp cỏ và các layer chưa đặt tên theo chức năng. Scene tree, kích thước ô, vị trí chân và TileSet cần kiểm tra lại tại thời điểm triển khai; không dùng hướng dẫn chuyển đổi map/offset của tài liệu cũ như dữ kiện hiện tại.

Tài liệu này không thêm script, sửa scene hay xác nhận gameplay đã chạy. Các tên controller/data ở trên là thiết kế dự kiến, có thể tinh chỉnh trong quá trình học.

- [Quy tắc hướng dẫn](RULES.md).
- [Asset cây trồng hiện có](crop_resources.md).
- [Godot-master](../.agents/skills/godot-master/SKILL.md): đọc module phù hợp từng bước; kiểm chứng API trước khi dùng, không áp dụng máy móc mọi khẳng định trong skill.
- [Godot TileMapLayer](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html): chuyển tọa độ, terrain connect và cập nhật ô.
- [Godot Using TileSets](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html): terrain và custom data.
- [Godot AnimatedSprite2D](https://docs.godotengine.org/en/stable/classes/class_animatedsprite2d.html): frame_changed, animation_finished và animation_looped.
