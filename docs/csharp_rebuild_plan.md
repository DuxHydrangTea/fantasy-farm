# Kế hoạch viết lại Fantasy Farm bằng C#

Ngày: 13/10/2026. Nhánh: `rebuild/c-sharp`.
Trạng thái: đã triển khai code và kiểm tra tự động. Kiểm tra trực tiếp hình ảnh/điều khiển và export desktop chưa được xác minh.

## Mục tiêu và phạm vi

Viết lại toàn bộ code do dự án sở hữu bằng C#, tổ chức theo module và các hợp đồng interface rõ ràng. Dùng gameplay hiện tại làm mốc nghiệm thu; mỗi module được chuyển cùng scene, resource và kiểm tra tương ứng.

- Chuyển gameplay, input, animation, state machine, tương tác, inventory/hotbar, UI, trồng trọt và phần chăn nuôi đã tồn tại.
- Chuyển cả script trong scene nhà/công trình, autoload của game, công cụ editor và generator đang được sử dụng.
- Tiếp tục dùng assets, atlas, SpriteFrames, TileSet, theme, bố cục scene và dữ liệu hiện tại. Cập nhật các liên kết phụ thuộc script.
- Công cụ Python/PowerShell dùng một lần được kiểm kê riêng: chuyển sang C# nếu còn cần vận hành; gỡ khỏi mã hoạt động nếu nhiệm vụ đã hoàn thành và ghi rõ trong tài liệu.
- Chưa bổ sung cây ăn quả, hoa, câu cá, crafting, save/load hoặc chức năng mới khác trong đợt chuyển đổi. Không phát triển combat.
- Phạm vi triển khai theo đề xuất được giữ khi người dùng yêu cầu triển khai: giữ nguyên `addons/godot_mcp_toolkit` và `addons/scatter2d`, kiểm tra tương thích với Godot .NET. Nếu yêu cầu chuyển cả addon, phải bổ sung kế hoạch riêng cho editor plugin, giao thức MCP, autoload runtime và Scatter2D trước khi triển khai phần đó. Không coi việc giữ addon GDScript là đạt tiêu chí “repo không còn bất kỳ .gd nào”.

## Hiện trạng đã xác minh

- Có 77 file GDScript ngoài `addons` và `.godot`: 18 file trong `scripts/setup`, 59 file còn lại gồm runtime, editor helper và script scene. Đây là số file nguồn hiện tại, không phải số class C# phải tạo.
- Có 4 công cụ Python/PowerShell trong `scripts/setup` và `scripts/merge_tilesets.gd` cần được đưa vào bảng chuyển đổi công cụ.
- Các scene và `.tres` tham chiếu GDScript qua đường dẫn, UID, `script_class`, thuộc tính export và metadata. `ItemSlot` còn được nhúng trực tiếp trong `hub.tscn` và `world.tscn`.
- Luồng dùng vật phẩm: input → Player → tìm mục tiêu → chuẩn bị ActionContext → animation ToolState → thực thi một lần ở frame hiệu lực → đối tượng tương tác.
- Kho sản phẩm và hotbar có quy tắc nhận vật phẩm khác nhau. Thu hoạch chỉ xóa cây sau khi kho nhận đủ toàn bộ sản lượng.
- Trồng trọt dùng 4 hình tăng trưởng; cây lớn theo thời gian ngay cả khi đất khô. Tưới giữ đất ướt trong 5 giây và cộng 5% tổng thời gian tăng trưởng khi cây chưa trưởng thành.
- Chăn nuôi có cấu hình loài/sản phẩm, AI gà đi lang thang và nghỉ, chỉ số no/nước, tick ở chuồng và tương tác nạp máng. Trong đợt này chỉ chuyển hành vi đã có; logic tìm máng, trưởng thành hay tạo sản phẩm cần kiểm kê trước khi được coi là chức năng phải giữ.
- `project.godot` có cấu hình assembly .NET nhưng chưa thấy `.csproj`/`.sln` trong kiểm kê. Máy có SDK .NET 10.0.112; chưa xác minh đường dẫn và phiên bản Godot .NET đang sử dụng. Trường feature `4.7` trong cấu hình không đủ để xác nhận phiên bản executable.

Graph: `home-dungnguyen-Projects-test-js`, generation `2026-10-13T01:12:10Z`, branch được xác nhận là `rebuild/c-sharp`. Coverage không ghi nhận gap trong các phạm vi `scripts`, `components`, `scenes`; các kết luận quan trọng cũng đã đối chiếu nguồn. Đây là kiểm tra theo nhiệm vụ, không phải chứng minh toàn bộ graph hoàn chỉnh.

## Kiến trúc đề xuất

Một project Godot C# chính, một project test cho logic thuần C#. Chỉ tách thêm assembly khi có nhu cầu thực tế. Namespace gốc đề xuất: `FantasyFarm`.

```text
src/
  Core/             # Hợp đồng, kết quả hành động, logic và model thuần C#
  Data/             # Resource: Item, Crop, Animal, Production, cấu hình slot
  Characters/       # Actor, controller, movement, animation, states
  Interactions/     # Focus, chuẩn bị hành động, thực thi, adapter đối tượng
  Inventory/        # Node kết nối kho/hotbar với model và scene
  Farming/          # FarmLand, FarmPlot, tương tác trồng trọt
  Animals/          # Chicken, needs, coop, trough, AI hiện có
  UI/               # InventoryPanel, HotbarView, ItemSlotView, DebugPanel
  World/            # Biến thể công trình, CursorController
tools/              # Editor tool, generator và validator C#
tests/              # Unit tests; scene kiểm tra tích hợp chạy bằng Godot
```

- Interface tạo tại nơi có hợp đồng hoặc nhiều implementation: `IInteractable`, `IInventoryStore`, `ICharacterController`, `IState`. Chốt chữ ký sau khi khóa hành vi hiện tại.
- Model chịu trách nhiệm số lượng, sức chứa, tiến độ và điều kiện; Node chịu trách nhiệm vòng đời Godot, input, physics, hiển thị và nối dependency.
- Resource chứa dữ liệu cấu hình và hình ảnh. Slot cấu hình trong scene được chuyển thành trạng thái runtime riêng khi khởi tạo, tránh sửa resource dùng chung.
- Dùng enum hoặc tham chiếu có kiểu cho state/action trong gameplay. Tên animation và tên node vẫn được xử lý tại lớp tích hợp Godot.
- Dùng event C# cho giao tiếp nội bộ model; dùng signal Godot khi cần liên kết với scene/editor. Có quy tắc đăng ký và hủy đăng ký rõ ràng.
- Dependency được gán qua constructor cho class thuần C#, và qua export/tham chiếu có kiểu cho Node. Chưa cần DI framework hoặc event bus toàn cục.
- Inspector export Node/Resource cụ thể hoặc base class tương thích Godot; adapter kiểm tra và sử dụng interface trong code. Không export trực tiếp interface.

## Thứ tự thực hiện

### 1. Khóa mốc hành vi và lập bảng chuyển đổi

- [x] Ghi commit gốc của nhánh, kiểm kê toàn bộ code sở hữu, scene/resource phụ thuộc, autoload, input action, group và kết nối signal.
- [x] Lập mapping `GDScript → class C# → scene/resource ảnh hưởng → tiêu chí nghiệm thu`, kể cả generator, helper cũ và script ít được dùng.
- [x] Ghi checklist chạy game gốc: di chuyển, tương tác, mở kho, đổi hotbar, gieo/tưới/thu hoạch, máng ăn/nước, hành vi gà, editor preview.
- [x] Tách lỗi có sẵn khỏi lỗi chuyển đổi. Giữ các giá trị dữ liệu hiện tại; thay đổi hành vi cần quyết định riêng.

Hoàn tất khi có một mốc so sánh tái lập được và phạm vi addon được ghi rõ.

### 2. Chuẩn bị nền C# và cơ chế kiểm tra

- [x] Xác minh executable Godot .NET và phiên bản SDK Godot, target framework, export target; khóa phiên bản phù hợp. Giả định ban đầu là desktop Linux/Windows, cần xác nhận trước cấu hình export cuối.
- [x] Tạo project/solution và cấu hình build, nullable, namespace, quy tắc tên file/class; loại mã test và output generator khỏi compilation của game.
- [x] Tạo scene kiểm tra Godot nhỏ để xác minh Node C#, Resource export và signal hoạt động trong editor và headless.
- [x] Thiết lập unit-test project cho logic thuần C#, runner scene C# cho kiểm tra tích hợp. Runner headless trả exit code thất bại khi validator gặp lỗi.

Hoàn tất khi build và scene kiểm tra chạy được; không coi `dotnet build` là bằng chứng game đã hoạt động.

### 3. Viết model dữ liệu và inventory bằng C#

- [x] Viết các Resource tương đương `ItemDefinition`, `CropDefinition`, `AnimalDefinition`, `AnimalProductionDefinition`; giữ giá trị enum đã serialize hoặc có mapping rõ ràng.
- [x] Chuẩn hóa tên lỗi chính tả trong code qua mapping; kiểm tra ID vật phẩm trùng trước khi chọn quy tắc nhận diện item.
- [x] Viết slot/runtime inventory và `IInventoryStore`, giữ giới hạn stack, kho 16 slot, quy tắc hotbar và thao tác thêm toàn bộ hoặc thất bại toàn bộ.
- [x] Chuẩn bị mapping và bản resource/scene kiểm tra cho `.tres` lẫn resource nhúng; kiểm tra script UID, `script_class`, metadata, tên thuộc tính PascalCase và reference lồng nhau. Chỉ thay reference trong scene đang dùng khi các consumer C# tương ứng đã sẵn sàng.
- [x] Viết test sức chứa, cộng dồn, tiêu thụ hạt/thức ăn, số lượng không hợp lệ, kho đầy và tính độc lập giữa hai instance.

Hoàn tất khi mọi definition cần cho game load đúng trong scene kiểm tra C# và inventory vượt các test quy tắc hiện tại.

### 4. Viết nhân vật, controller và state machine

- [x] Chuyển CharacterBase/Player, movement và input controller; dùng hợp đồng controller rõ ràng để Player và AI chia sẻ actor.
- [x] Viết `IState` và cơ chế enter/exit/update/physics update; dùng base class khi cần dùng chung logic hoặc cấu hình scene.
- [x] Chuyển idle/walk/tool/water và animation adapter, giữ cách quay hướng, flip, fallback và frame hiệu lực đang dùng.
- [x] Nối lại `player.tscn`, initial/default state, node reference và signal; kiểm tra thứ tự khởi tạo.

Hoàn tất khi player di chuyển và dùng công cụ đúng hướng, dừng đúng lúc, không đăng ký callback trùng khi đổi state.

### 5. Viết hệ thống tương tác và kết nối UI

- [x] Viết `IInteractable`, context hành động có kiểu và kết quả thực thi; giữ bảo đảm một hành động chỉ tạo hiệu lực một lần.
- [x] Chuyển FocusComponent/InteractionFocusComponent, giữ cách chọn theo khoảng cách, hướng nhìn, độ ổn định khi đổi mục tiêu và khóa focus trong animation.
- [x] Kiểm tra lại item/slot/target tại lúc thực thi; xử lý mục tiêu đã bị giải phóng hoặc slot đã đổi trong thời gian chờ animation.
- [x] Chuyển hotbar view, inventory panel, item slot view, PlayerUI, debug panel và cursor autoload. Giữ chọn bằng phím/chuột và khóa tương tác khi mở kho.
- [x] Chuyển signal handler trong scene và hủy subscription theo vòng đời phù hợp.

Hoàn tất khi UI phản ánh đúng dữ liệu và thao tác lặp nhanh không gây tiêu thụ item hoặc hiệu lực trùng.

### 6. Viết lại trồng trọt và đưa vào world

- [x] Chuyển FarmLand, FarmPlot và FarmPlotInteractable; giữ tạo grid, plot ID, focus/growth bar và 4 giai đoạn cây.
- [x] Giữ thời gian tăng trưởng, quy tắc tưới và thu hoạch; kiểm tra kho nhận đủ sản lượng trước khi xóa cây.
- [x] Nối scene C# vào world; kiểm tra cả runtime và `[Tool]` tạo grid trong editor, tránh tạo plot trùng.
- [x] Kiểm tra chu trình gieo → lớn → tưới → thu hoạch với nhiều loại cây, kho đầy, thiếu hạt, ô đã có cây và cây chưa chín.

Hoàn tất khi luồng trồng trọt cũ chạy trọn vẹn trên C#.

### 7. Viết lại phần chăn nuôi đang có

- [x] Chuyển Chicken, ChickenAIController, ChickenActionState, AnimalNeeds, ChickenCoop và máng ăn/nước.
- [x] Giữ vùng đi lang thang, timer hành vi, trạng thái nghỉ/ngủ, tốc độ giảm no/nước, ngưỡng trạng thái và giới hạn máng.
- [x] Chuyển toàn bộ definition và dữ liệu sản phẩm đã chuẩn bị; phân biệt dữ liệu với logic đang thực sự hoạt động.
- [x] Kiểm tra đăng ký/hủy đăng ký vật nuôi, tick sau khi node bị giải phóng, nạp máng đầy và tiêu thụ thức ăn chính xác.

Hoàn tất khi chăn nuôi đạt đúng mốc đã ghi ở bước 1. Các phần đang dở dang được ghi lại để phát triển sau.

### 8. Chuyển công cụ editor và script công trình

- [x] Chuyển 16 script biến thể nhà/công trình, hỗ trợ preview `[Tool]`; bảo toàn mapping enum → texture và vị trí/collision scene.
- [x] Chuyển 18 setup generator và helper merge TileSet sang các lệnh C# có trách nhiệm rõ ràng, có thể dùng chung utility.
- [x] Cung cấp EditorScript hoặc runner scene cho generator; build trước rồi chạy bằng Godot .NET. Không giả định có thể thay `.gd` bằng `.cs` trong lệnh `--script` hiện tại.
- [x] Giữ đường dẫn output và dữ liệu catalog, kiểm tra vùng atlas/frame, chế độ ghi đè, UID/reference và tính lặp lại của generator.
- [x] Chuyển hoặc loại bỏ có ghi nhận 4 script migration Python/PowerShell; cập nhật toàn bộ hướng dẫn chạy công cụ.

Hoàn tất khi editor preview đúng và chạy generator trong vùng output kiểm tra không làm mất chỉnh sửa scene hiện có.

### 9. Dọn mã cũ và nghiệm thu toàn dự án

- [x] Sau khi từng nhóm đã đạt kiểm tra, gỡ GDScript của nhóm đó; quét scene/resource/config/docs để tìm reference cũ, cả reference theo UID.
- [x] Xác minh danh sách script sở hữu ban đầu: mỗi file có bản C#, được hợp nhất hoặc được loại bỏ với lý do; không bỏ sót `scenes`, setup tool hoặc autoload.
- [x] Chạy unit tests, import/load scene và resource bằng Godot .NET headless, smoke test world, và chạy checklist tương tác tự động trong scene.
- [ ] Kiểm tra trực tiếp hình ảnh và cảm giác điều khiển trong editor/game khi người dùng có thể mở Godot.
- [x] Kiểm tra addon theo phạm vi đã chốt; nếu giữ addon, mọi `.gd` còn lại phải thuộc danh sách ngoại lệ bên thứ ba được ghi rõ.
- [ ] Kiểm tra export desktop mục tiêu khi có cấu hình/export templates.
- [x] Cập nhật README, kiến trúc, lệnh build/test/generate và danh sách chăn nuôi chưa hoàn tất.

Hoàn tất khi toàn bộ code sở hữu đang hoạt động là C#, các nhóm hành vi cũ đạt kiểm tra, editor/resource không còn reference script thiếu, và bản export mục tiêu khởi động được.

## Quy tắc thực hiện và nghiệm thu

- Mỗi giai đoạn là một nhóm thay đổi review được, có code, chuyển dữ liệu và kết quả kiểm tra đi cùng. Các thay đổi hiện để ở working tree cho người dùng review; giữ mốc ban đầu để đối chiếu.
- Trong thời gian chuyển đổi có thể còn cả C# và GDScript giữa các module; hạn chế bridge tạm và gỡ khi hoàn tất. Đích cuối được xác định theo phạm vi code sở hữu và quyết định addon.
- Dùng scene/resource kiểm tra riêng trong lúc viết các nhóm phụ thuộc. Một nhóm chỉ được nối vào world khi toàn bộ chuỗi consumer liên quan đã chuyển; không giao Resource C# cho thuộc tính vẫn yêu cầu class GDScript.
- Tránh đăng ký đồng thời hai global class trùng tên khi `class_name` GDScript cũ còn tồn tại. Có thể trì hoãn `[GlobalClass]` trên bản C# thử nghiệm; đăng ký tên cuối cùng và rebuild editor cache tại thời điểm chuyển cả nhóm. Theo dõi reference asset khi đổi tên/di chuyển file.
- Không sửa hành vi chăn nuôi đang dở hoặc thêm chức năng trong cùng commit chuyển đổi. Sửa lỗi cản trở migration cần ghi trigger, hành vi trước/sau và test tương ứng.
- Bắt buộc kiểm tra các ranh giới: kho đầy không mất cây, action không thực thi hai lần, resource runtime không dùng chung trạng thái, target giải phóng không gây exception, signal không giữ callback cũ.
- Build thành công, load scene thành công và tương tác chạy đúng là ba tiêu chí riêng. Cần đủ cả ba.

## Cơ sở kỹ thuật

- C# export chỉ hỗ trợ kiểu tương thích Variant; Node/Resource có thể gán trong Inspector: [C# exported properties](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_exports.html).
- Dùng `[GlobalClass]` cho các loại cần tạo/chọn trong editor, tên file phải khớp tên class: [C# global classes](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_global_classes.html).
- Signal dùng event C#; custom signal và lambda bắt biến cần quản lý ngắt kết nối: [C# signals](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_signals.html).
- `[Tool]` và công cụ editor phải được kiểm tra cả trong editor lẫn runtime: [Running code in the editor](https://docs.godotengine.org/en/stable/tutorials/plugins/running_code_in_the_editor.html).
- Cần Godot .NET và SDK phù hợp. Nếu mục tiêu có web, phải đánh giá lại lựa chọn export vì Godot 4 C# hiện chưa hỗ trợ web theo tài liệu: [C# basics](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_basics.html).
