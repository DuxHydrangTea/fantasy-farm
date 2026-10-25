# Người làm thuê — 3 vai chuyên biệt (Hired Workers)

Worker là NPC có thân đi tuần tự tìm việc, **tách theo 3 vai chuyên biệt** —
mỗi vai một địa bàn và một nhóm việc, người chơi tuyển theo điểm nghẽn của
nông trại. Kiến trúc: **một `WorkerActor` generic + `WorkerRole` strategy**
(role quyết định cách quét việc, hành động, khu trực và đóng góp offline).

| Vai trò | Việc làm (v1) | Địa bàn | Không làm (v1) |
| --- | --- | --- | --- |
| **Crop hand** (trồng trọt) | Tưới ô trồng khô, thu hoạch khi chín, gom pickup | Khoảng cột đất (`land_columns`) | **Cuốc/gieo tự động** — để sau v1 khi có UI chọn giống + kiểm soát diện tích; bón phân, mở đất |
| **Ranch hand** (chăn nuôi) | Tiếp thức ăn (item từ giỏ) và nước (miễn phí từ nguồn chỉ định), gom sản phẩm WORLD_DROP | Một chuồng chỉ định (theo `AnimalPen.persistent_id`) | Mua/bán vật nuôi, tonic |
| **Orchard hand** (cây trái) | Thu trái chín theo chu kỳ, gom trái/gỗ rơi | Vùng `FRUIT_REGION` của `TreePlantation` (cố định) | Chặt cây, trồng cây |

Thứ tự triển khai: **Orchard làm mẫu trước** (vùng cố định, lưới cây so le
đều, chu kỳ timestamp sẵn — ít rủi ro nhất, chứng minh khung
WorkerActor/Role + giỏ + save + offline an toàn), rồi Ranch, rồi Crop.

## Quy tắc đã chốt

| Quy tắc | Giá trị |
| --- | --- |
| Kiểu worker | NPC có thân, FSM 4 trạng thái chung `IDLE → WALK_TO_TASK → WORKING → PATROL` — không tái dùng FSM 11 trạng thái của vật nuôi. Một mục tiêu/lần; cân bằng độc lập với nâng cấp nông cụ của player (nông cụ đã hoàn thành 6×6, worker không hưởng). |
| Di chuyển | Dùng `movement.set_target()` (API thật của MovementComponent — bản thân nó tự hủy đích sau ~0.2s bị chặn). Worker **không đổi config của player**: behaviour giữ đích của riêng mình, đo thời gian kẹt theo ngưỡng riêng (2s) rồi **bỏ việc, quay lại sau**. Đi thẳng, không pathfinding, không rời khu. |
| Điểm tiếp cận | Không đi vào tâm mục tiêu (thân cây có collision, máng có thân): đứng tại **điểm tiếp cận** = tâm mục tiêu lệch xuống dưới nửa chiều cao + margin (đứng "bên dưới" theo y-sort), nếu đường tới bị chặn thì thử 4 offset trực giao; đều kẹt → bỏ việc. |
| Tại mục tiêu | Đứng idle + hẹn giờ `work_seconds = 2s` rồi commit API. Không animation công cụ — chỉ cần walk/idle của NPC sprite (lumberjack/bartender/chef). |
| Công suất | **Mô phỏng theo nhiệm vụ rời rạc (discrete-event), không theo ngân sách trung bình**: mỗi việc tốn `travel` tính từ khoảng cách thực tới mục tiêu cụ thể + `work_seconds = 2s`; worker luôn giữ **nhiệm vụ đang làm + thời điểm hoàn thành tuyệt đối**; tiến độ dở dang giữ nguyên qua biên thời tiết/lương/save — không đặt lại ngân sách mỗi đoạn nên chia nhiều đoạn ngắn không mất công suất. Offline suy ra từ cùng timeline nên **không thể vượt online** (mỗi việc trả đủ travel thật + work). |
| Ưu tiên việc | Theo vai, cụ thể: **Ranch** — máng nước/thức ăn đang thiếu TRƯỚC, gom sản phẩm sau; **Orchard** — trái chín gần nhất > pickup > patrol; **Crop** — cây chín > ô khô đang trồng > pickup > patrol. Chung: **re-validate mục tiêu ngay trước commit** (player có thể vừa xử lý xong) — mục tiêu đã bị xử lý thì bỏ, chọn việc kế, thời gian đã đi không hoàn lại. |
| Điều kiện dừng (chung online/offline) | Hết nguyên liệu (hạt/feed), đầy giỏ (ngừng thu, vẫn làm việc không thu), hết lương (tạm nghỉ). Offline xử lý dừng tại **đúng timestamp** của timeline, không xử lý cuối khoảng. |
| Giỏ | `InventoryComponent` 16 slot, **`starting_tools = false`**. **Stack cap 100 áp tại runtime trong InventoryComponent** (override giới hạn stack cho giỏ worker — không chỉ validate lúc save, kẻo runtime tạo stack lớn rồi save tự từ chối chính nó). Ví dụ quả: `FruitTree.harvest()` hiện cho 300 quả/lần → 3 stack × 100; **không đủ chỗ cho toàn bộ 300 quả thì không thu, cả đợt giữ trên cây** theo API thu nguyên đợt hiện tại — test case bắt buộc của M1. |
| Nhận / rút | Hai nút riêng trên worker: **"Nhận sản phẩm"** chỉ move thành phẩm (PRODUCE/honey/trái…), **"Rút nguyên liệu"** riêng — tránh nhận cả giỏ làm mất hạt/feed của ca tiếp theo. Tràn túi giữ lại trong giỏ. |
| Ranch — nước & thức ăn | Thức ăn: item FEED từ giỏ worker. Nước: **miễn phí từ nguồn nước chỉ định trong khu** (không tốn item). Nạp máng qua API của máng và **đồng bộ mô phỏng chuồng (`pen.advance_offline`) trước khi nạp** — không viết trực tiếp vào stock. Offline nạp tại **đúng biên máng cạn** theo event, không cộng sổ đầu khoảng (cộng sổ sẽ đổi thời điểm đàn thiếu ăn và sản lượng). |
| Lương | **Trả trước tại bình minh cho ngày mới**. **Ưu đãi ca đầu: miễn phí tới bình minh kế tiếp, áp dụng MỘT lần cho mỗi vai trong profile** (lưu cờ; sa thải rồi thuê lại không được miễn nữa — chống lách hire/fire trước bình minh). Thuê lại luôn chịu lương như thường. Hết tiền tại biên ngày → **tạm nghỉ** — giữ hợp đồng, giữ giỏ; đủ tiền ở biên kế thì tự làm lại. Nhiều worker mà tiền thiếu: trả theo **thứ tự thuê** (deterministic, ổn định qua load), worker sau tạm nghỉ. Mức 1.800 / 2.200 / 2.800 là **giá thử nghiệm** — đo sản lượng thực ở M5. |
| Số lượng | **v1 mỗi vai đúng 1 worker.** Mốc chỉ là điều kiện mở khóa (Orchard ≥ 10 cây, Ranch ≥ 2 chuồng, Crop ≥ 12 cột đất mở) — không cộng dồn thuê thêm. |
| Nước tưới (crop) | V1 bình vô hạn; cân bằng lại ở phần 4 nếu quá mạnh. |
| Objectives | Hành động worker phát `action_committed` như player và được tính vào objectives (farming không phân biệt actor). Muốn tách thì lọc theo actor — flag cho sau. |
| Cỏ GPU | Worker vào group `grass_interactors` — cỏ tự né, không sửa shader. |

## Thành phần

| Type | Trách nhiệm |
| --- | --- |
| `WorkerDefinition` | Role, sprite variant, tốc độ, `work_seconds`. `.tres` tại `resources/workers/`. |
| `WorkerActor` (CharacterBody2D) | Composite chung: `MovementComponent` (tham chiếu riêng, không đụng config player) + `AnimationComponent` + `WorkerBehaviourComponent` + giỏ (`starting_tools=false`, stack cap 100) + outline tương tác. Persistent ID như `AnimalActor`. |
| `WorkerBehaviourComponent` | FSM chung: hỏi `role.scan(zone)` lấy nhiệm vụ gần nhất (điểm tiếp cận + callback + work_seconds); giữ đích qua ngưỡng kẹt 2s của riêng worker bất chấp MovementComponent hủy đích 0.2s (re-set hoặc theo dõi delta). |
| `CropRole` / `RanchRole` / `OrchardRole` | Strategy RefCounted thuần: khu, quét việc, hành động (gọi API sẵn có), đóng góp offline theo công suất chung. Unit test không cần cảnh. |
| `WorkerService` | Farm-level (pattern `ApiarySystem`): đăng ký, lương biên ngày (trả trước, thứ tự thuê), offline = tổng đóng góp role theo segment. |
| `WorkerBoard` | Biển thuê clone pattern `pen_board.tscn` + `pen_dashboard.gd`: thuê, xem khu, nạp nguyên liệu, nhận/rút, sa thải có xác nhận. |

## Offline và tương quan online/offline

Offline là **discrete-event timeline**: trạng thái = (nhiệm vụ đang làm, thời
điểm hoàn thành tuyệt đối). `WorkerService.advance(timestamp)` xử lý các
event theo thứ tự timestamp: hoàn thành nhiệm vụ, biên bình minh (lương trả
trước / hết tiền tạm nghỉ), biên thời tiết, máng cạn (ranch), độ ẩm đất
(crop), trái chín (orchard), giỏ đầy. Timeline liên tục — phần dở dang của
một nhiệm vụ đi qua biên/save giữ nguyên, không tính lại.

- Mỗi nhiệm vụ trả đúng `travel` (khoảng cách thực tới mục tiêu đó) +
  `work_seconds` → offline không thể nhanh hơn online trên cùng chuỗi việc.
- Ranch nạp máng tại biên cạn (sync pen simulation trước khi nạp — event
  theo stock, không cộng sổ). Crop tưới tại biên khô (mưa bỏ nhờ
  `rain_water`), thu tại biên chín.

**Parity testing**: mỗi kịch bản test đôi (online vs offline) chạy cùng một
lịch nhiệm vụ trong điều kiện kiểm soát (không vật cản, cùng seed); so kết
quả theo chuỗi nhiệm vụ hoàn thành. Va chạm vật lý và kẹt đường là khác biệt
chấp nhận được — mục tiêu là khớp **chuỗi việc và timestamp hoàn thành**
trong điều kiện chuẩn, không khớp tuyệt đối từng frame.

## Save và tương tác

- `InteractionTarget.Kind` thêm `WORKER`: hai lệnh nhận sản phẩm / rút nguyên
  liệu (nút riêng). Worker chỉ có badge việc đang làm + mức giỏ (X/16, mỗi
  stack ≤ 100).
- Save schema **v23** (v22 đã dùng cho Chef/cooking). Mỗi worker row gồm:
  - persistent ID, role, tham chiếu khu (khoảng cột / pen ID / vùng),
  - **`hire_order`** (thứ tự thuê — trả lương ổn định sau load),
  - **`state`** (đang làm / tạm nghỉ) + **`paid_through_day`** (đã trả tới mốc nào),
  - **`simulated_at`** (mốc đã mô phỏng tới) + **`current_task` + tiến độ/thời
    điểm hoàn thành dở dang** (để offline/save/load không mất công việc dở),
  - **cờ ưu đãi ca đầu đã dùng, theo từng vai** (profile-level),
  - **giỏ là nguồn duy nhất của nguyên liệu** — bỏ trường "nguyên liệu mang
    theo" riêng, feed/hạt chính là item trong giỏ (một bản dữ liệu, không thể lệch).
  Migration v1…v22 khởi tạo list rỗng; validation: khu hợp lệ theo role,
  item trong allowlist `SaveCatalog`, stack ≤ 100, timestamp hoàn thành hợp lệ,
  không trùng ID / hire_order.
- **Save + nhận giỏ đi kèm M1 Orchard** (không đợi M4/M5) để mốc đầu tiên đã
  dùng được trong game thật.

## Lộ trình (mỗi mốc chơi được; verify cảnh đầy đủ ban ngày — bài học tán cây)

1. **M0** — WorkerActor đi tuần waypoint trên map thật (chưa có việc).
2. **M1** — Orchard online hoàn chỉnh: quét trái chín, thu vào giỏ, board tối
   giản (thuê/sa thải/nạp/nhận/rút), lương bình minh, **save v23**.
3. **M2** — Orchard offline (model + test đôi) — chứng minh trọn vẹn
   online + offline + lưu an toàn cho một vai.
4. **M3** — Ranch online → offline (feed từ giỏ, nước miễn phí, nạp theo biên
   cạn).
5. **M4** — Crop online → offline (tưới + thu hoạch).
6. **M5** — Đo lường sản lượng/lương (phần 4 của plan), cân bằng stack cap và
   giá thuê; mở khóa các mốc.

Sau v1: cuốc/gieo tự động cho crop (kèm UI chọn giống + kiểm soát diện tích),
nhiều worker/vai, nâng cấp cho worker.

Tests: `tests/unit/test_worker_roles.gd` (mỗi role: scan/ưu tiên/công suất
offline theo công thức), `test_worker_service.gd` (lương: biên ngày, thuê
05:59, thiếu tiền nhiều worker, tạm nghỉ), `tests/integration/test_workers.gd`
(wiring map thật, nhận/rút tách biệt, stack ≤ 100, starting_tools=false,
migration v22→v23, roundtrip, replay 48h, test đôi online/offline chuẩn).
