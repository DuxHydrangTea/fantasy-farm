# Console debug F1 — danh sách và plan triển khai

## Hành vi

- Chỉ khởi tạo trong debug build. F1 mở/đóng, Esc đóng; đóng menu gameplay khác trước khi mở console.
- Console tạm dừng SceneTree, giữ trạng thái pause trước đó; nhập chữ không kích hoạt hành động gameplay. Nhập lệnh rồi Enter, ↑/↓ xem 100 lệnh gần nhất, Tab điền gợi ý đầu tiên; hiển thị tối đa 5 gợi ý theo ngữ cảnh subcommand/item/loài/worker/nhánh nâng cấp.
- Cú pháp `/command param1 param2`; hỗ trợ chuỗi trong dấu nháy đơn/đôi và escape bằng backslash. Không chạy biểu thức GDScript hoặc đường dẫn script.
- Debug sửa trực tiếp farm hiện tại, có thể được autosave bình thường. Test dùng world con không bind profile đang chơi.
- `here`: ô tại vị trí player, hoặc vật nuôi gần nhất trong 64 pixel. `all confirm`: xác nhận thao tác ruộng toàn bộ. Tọa độ `/tp` là world pixel; tọa độ `/crop` là ô farmland.
- Quality: `normal`, `silver`, `gold`; mặc định `normal`. Kho có alias `supply`, `produce`, cũng chấp nhận ID kho thật. Worker dùng số slot 1–3 hoặc persistent ID.

## Catalog đã chốt

| Cú pháp | Công dụng |
|---|---|
| `/help [command]` | Hướng dẫn lệnh, lấy từ registry |
| `/clear` | Xóa output console |
| `/find item|crop|animal <query>` | Tra ID; query có thể nằm trong dấu nháy |
| `/inspect here`, `/pos` | Xem vật nuôi/ô gần player, tọa độ |
| `/money get`, `/money set <amount>`, `/money add <amount>` | Số xu, tuân thủ giới hạn ví |
| `/give <item> [count=1] [quality=normal]` | Cấp vào túi, từ chối nếu không nhận đủ |
| `/storage info [id]` | Xem kho và sức chứa |
| `/storage add <id> <item> <count> [quality]` | Cấp vào kho đúng loại, đủ chỗ |
| `/tp <x> <y>` | Dịch chuyển trong giới hạn camera thế giới |
| `/tp workers|farm|coop|barn|pond|orders` | Tới vị trí đặt tên; có thể dùng tọa độ để chỉnh chỗ đứng |
| `/time get`, `/time hour <0-23|auto>` | Đồng hồ mô phỏng và preview ánh sáng riêng |
| `/time advance <count> <second|minute|hour|day>` | Replay đầy đủ qua adapter/worker async; tối đa 7 ngày/lệnh, độc lập cài đặt offline progress |
| `/weather set sunny|rain|cloudy|windy`, `/weather auto` | Override hôm nay hoặc chọn lại thời tiết tự nhiên hôm nay; lịch ngày sau vẫn tự động |
| `/crop info [here|x y]` | Giống, soil, tiến độ, bệnh |
| `/crop grow|water [here|x y|all confirm]` | Cho chín hoặc tưới qua API farming |
| `/crop disease pests|weeds|clear [here|x y|all confirm]` | Đặt sâu/cỏ hoặc xóa cả hai |
| `/land unlock <1-24>` | Mở đất tới tổng số khối; không thu hồi đất |
| `/animal list [species]`, `/animal info <id|here>` | ID, chuồng, tuổi, nhu cầu, bệnh, sản lượng |
| `/animal spawn <species> [count=1]` | Spawn miễn phí nhưng giữ luật loài, sức chứa và vị trí hợp lệ |
| `/animal disease <id|here> on|off` | Gây/chữa bệnh |
| `/animal needs <id|here> food|water <0-100>` | Đặt nhu cầu |
| `/animal age <id|here> young|adult` | Chỉnh tuổi, visual và behaviour |
| `/worker list`, `/worker info <slot|id>`, `/worker target <slot|id>` | Roster, task, reservation, navigation và lý do chờ |
| `/worker hire` | Theo điều kiện thuê/lương và giới hạn 3 |
| `/worker pause|resume <slot|id|all>` | Giữ task và tiến độ; không resume người chưa được trả lương |
| `/worker upgrade speed|hoe|sowing|watering|harvest <level>` | Đặt cấp miễn phí; speed 0–10, công cụ 1–3; giữ snapshot task dở |
| `/upgrade tool <hoe|watering_can|sowing> <1-6>` | Cấp nông cụ player, độc lập worker |
| `/upgrade pen <pen_id> <1-6>` | Cấp/sức chứa chuồng, từ chối hạ dưới dân số |
| `/objective list`, `/objective complete <id>` | Hoàn thành objective đang active; nhận thưởng theo nút claim bình thường |
| `/order list` | State đơn hàng |
| `/save status`, `/save validate` | Profile/revision/readiness; validate live DTO và primary/backup nếu bind local repository |
| `/perf on|off|snapshot` | HUD FPS/process/physics và counter CPU scheduler/navigation/commit |

Lệnh ID sai, số âm ngoài phạm vi, `NaN`, quá số tham số hoặc thiếu xác nhận trả lỗi. Command bất đồng bộ có cờ busy; không đóng console giữa replay. Parser/registry có API `register(path, usage, description, handler, write)` để bổ sung handler.

## Plan và thành phần

1. [x] `DebugCommandRegistry`: tokenizer, registry allowlist, help sinh từ catalog.
2. [x] `FarmDebugCommands`: xử lý/validate tham số và điều phối các API world. Không thêm autoload; world sở hữu console.
3. [x] `FarmDebugConsole`: UI container theo theme dự án, input F1/Esc/Enter/history/Tab, output và HUD perf.
4. [x] Tích hợp debug-only tại composition root `FarmWorld`; bổ sung API pause/resume worker để giữ duration/paused_at và kiểm tra tiền lương.
5. [x] Test parser, input, tiền/kho, cây/bệnh, loài/sức chứa, worker cap/upgrades, save validation, timeline. Render desktop/mobile và xem ảnh.

## Kiểm chứng

Godot 4.7.1 Mono:

- Test mới `test_debug_console.gd`: 6/6 pass, 112 assertion sau sửa cuối. Bao gồm F1/Esc bằng input event thật, pause/focus/history/log, parser quotes/lỗi, gợi ý, giới hạn ví/kho/chất lượng, không mutate khi input lỗi/busy, thuê người thứ tư thất bại, pause/resume, snapshot task giữ nguyên sau nâng cấp, spawn và save schema, sâu+cỏ đồng thời, ánh sáng tách đồng hồ, replay tăng đúng 60 giây.
- Hồi quy cùng test mới + `test_worker_ui.gd` + `test_persistence_bootstrap.gd`: 24/24 pass (277 assertion ở lượt trước bổ sung gợi ý/kiểm tra log). Worker upgrades riêng: 16/16 pass.
- Native Forward+ / D3D12: render và đã xem ảnh 1280×720, 844×390; input nằm trong màn hình, log đọc được và cuộn được trên màn nhỏ. Preview xác nhận SaveManager không bind profile đang chơi.
- Đã sửa lỗi log biến mất khi `/help` chạy trước layout đầu tiên: buffer giới hạn 64.000 ký tự, giữ 48.000 ký tự cuối khi vượt ngưỡng, không phụ thuộc số dòng render.
- Lint sau sửa vẫn 2 lỗi tài nguyên/5 cảnh báo nền, **0 chẩn đoán mới**. `git diff --check` sạch. Các ảnh thiếu là `pet_shop_pigpen.png`, `crop_flower_shop_red.png` đã tồn tại trước task.

Artifact: `.godot/debug-console-tests-last.log`, `.godot/debug-console-final-tests.log`, `.godot/debug-console-compile.log`, `.godot/debug-console-preview.log`, `.godot/debug-console-preview/console-1280x720.png`, `.godot/debug-console-preview/console-844x390.png`, `.godot/debug-console-lint-{before,after}.json`.

Chạy lại:

```powershell
& C:/Godot_v4.7.1-stable_mono_win64/Godot_v4.7.1-stable_mono_win64_console.exe --headless --path C:/projects/fantasy-farm -s addons/gut/gut_cmdln.gd '-gconfig=' -gtest=res://tests/integration/test_debug_console.gd -gexit
& C:/Godot_v4.7.1-stable_mono_win64/Godot_v4.7.1-stable_mono_win64_console.exe --path C:/projects/fantasy-farm res://tests/support/debug_console_preview.tscn
```
