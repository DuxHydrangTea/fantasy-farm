# Kế hoạch chi tiết: Chiều sâu 4 hệ trồng trọt (Planting Depth) — v2.1

Đã hoàn thành vòng cân bằng mô phỏng B1: [đơn Hoàn Hảo bảo đảm giá, bếp mẻ lớn và số liệu](economy_balance_b1.md). Giá/thông số vẫn thử nghiệm; chưa thay thế phiên chơi thực dài hạn.

- **Ngày chốt:** 25/10/2026 (v2 sau review ngoài + GĐ3 tranh luận; v2.1 bổ sung 5 quy tắc theo review thứ hai — không cần vòng tranh luận mới theo kết luận của reviewer)
- **Nguồn gốc:** [tranh biện 3 giai đoạn giữa hai designer](planting_depth_debate_2026-10-25.md) (GĐ1 chiến lược → GĐ2 chi tiết + nghiệm thu → GĐ3 xử lý review độc lập)
- **Trạng thái:** **S0, S1, S2, S3a, S4 và S5 đã triển khai, save v33**; xem [S0–S1](planting_depth_s0_s1.md), [S2](planting_depth_s2.md) và [S3a: UI ghép cành, quả Star và Chef](planting_depth_s3a.md). S3b vẫn hoãn; [S5 đã triển khai](planting_depth_s5.md). Xem [S4: vườn ong và sổ công thức](planting_depth_s4.md). Các hệ số kinh tế (1.8x/3.5x, 2x, 30 gỗ/ngày…) là **giá thử nghiệm**, chốt chính thức ở phần 4 (cân bằng) của `completion_plan.md`.
- **LƯU Ý ĐỐI CHIẾU:** dự án đã có [kho nông sản/kho vật tư](farm_storage_s3_s5.md) (save v25) và [crop worker v2](crop_worker_automation.md) (save v26). Trước S0 phải rà: (1) tier chất lượng áp cho luồng produce qua **warehouse**; (2) worker v2 gieo hạt tuân theo fix pre-watering; (3) mọi version schema là **bump +1 từ schema hiện hành**, không phải số cứng.

## 1. Mục tiêu & phi mục tiêu

**Mục tiêu:** 4 hệ trồng có 4 bản chất chơi khác nhau — đo bằng bộ test 3 trục: **vectơ đánh đổi** / **đích đầu ra** / **hồ sơ chú ý**.

**Phi mục tiêu:** không thêm minigame bấm giờ; không FOMO/deadline; không xóa mechanic đã ship; không chống time-travel (known accepted risk); S0 **không** thay đổi kinh tế sức chứa kho.

## 2. Nguyên tắc xuyên suốt

| Hệ | Đánh đổi | Đích đầu ra | Hồ sơ chú ý |
|---|---|---|---|
| Rau | Vốn lưu động + phân bổ nỗ lực (tưới chọn lọc, ô màu mỡ) | Đơn hàng + Bếp | Mỗi session, nhẹ |
| Hoa | Không gian hình học (combo quanh tổ) | Mật hương vị → Bếp cao cấp | Hiếm — khi tái bố trí |
| Cây ăn quả | Vốn cố định + **chọn làn đầu ra: tiền hay bếp** (ghép cành) | Orders (Sản lượng) HOẶC Kitchen (Tuyển chọn) | Định kỳ thụ động |
| Cây gỗ | Chi phí cơ hội đất | Tư liệu hạ tầng + phân Root | Theo cột mốc mở đất |

- **Thang giá trị chất lượng (THỬ NGHIỆM):** Thường 1.0x · Bạc 1.8x · Vàng 3.5x — áp cho RAU (công sức mỗi chu kỳ). **Quả ghép không dùng thang này** (xem S3a).
- **Nguyên tắc Worker:** tự động hóa LAO ĐỘNG, không bao giờ QUYẾT ĐỊNH (ghép cành, bố trí hoa, bón Root, đập gốc).
- **Quy tắc chọn tầng khi tiêu nguyên liệu (v2.1) — không có caller nào vô tình tiêu hàng quý:**
  - `EXACT_TIER(tier)`: chế độ mặc định cho mọi caller cũ và mọi luồng tự động — đơn hàng thường dùng `EXACT_TIER(Thường)`; công thức bếp dùng `EXACT_TIER(tầng yêu cầu)`. Thiếu đúng tầng → hiện đếm thiếu, không đụng tầng khác.
  - `TIER_SET(allowed, prefer)`: chỉ dùng khi người chơi **chủ động cho phép** một tập tầng (bán theo lựa chọn, nộp Perfect…) — `LOW_FIRST/HIGH_FIRST` là thứ tự ưu tiên TRONG tập đã cho phép, không phải cơ chế leo tầng ngầm.
  - **Perfect Delivery:** `TIER_SET({Bạc, Vàng}, prefer Bạc trước)` — tiêu Bạc trước, giữ Vàng.
  - **Vận chuyển ≠ tiêu dùng:** gửi/rút Warehouse, chuyển stack giữa kho và túi, worker giao sản phẩm về kho — chuyển **nguyên trạng tầng 1:1**, không áp `EXACT_TIER` hay bất kỳ chọn lọc tầng nào (chỉ có tiêu nguyên liệu mới được chọn tầng).
  - Mọi giao dịch tiêu tầng có preview số lượng từng tầng trước xác nhận.
- **Quy tắc ngược bài phạt:** mọi bonus mất-được-không (không tưới chỉ mất 1 bậc chất lượng).

## 3. Các slice (mỗi slice bump +1 version schema từ hiện hành)

### S0 — Chất lượng trong stack, KHÔNG đổi sức chứa (v2)

- **Data:** slot `{item, count}` → `{item_id, tiers[3]}`. **Giữ nguyên `max_stack` hiện tại** — tổng 3 tầng không vượt giới hạn slot; vượt thì tràn sang slot thứ hai cùng item_id. `consume(EXACT_TIER/TIER_SET)` quét gộp mọi slot cùng item **trong đúng phạm vi tầng của mode** (tầng ưu tiên theo `prefer`, không vượt tập cho phép); UI xếp các slot cùng item cạnh nhau. Warehouse/điều kiện kho đầy của worker **giữ nguyên ngữ nghĩa**.
- **API (v2.1):** `add(item, amount, tier=0)`; `consume(item, amount, mode)` với mode ∈ {`EXACT_TIER(tier)`, `TIER_SET(allowed, prefer)`} — trả số bỏ mỗi tầng; `count(item, tier)`; `has(item, amount, tier)`. **Caller cũ đổi sang `EXACT_TIER(Thường)`** — hành vi cũ giữ 100%, không caller nào có khả năng tiêu Bạc/Vàng ngoài ý muốn (xem quy tắc chọn tầng ở mục 2).
- **Migration:** stack cũ → `tiers=[count, 0, 0]`.
- **Test/Đạt khi:** fixture save cũ load đúng; nộp đơn cần 5 Bạc khi chỉ có 5 Thường → FAIL rõ; tổng tầng vượt max_stack tràn sang slot 2 đúng; consume gộp 2 slot đúng thứ tự.

### S1 — Rau: nước → Bạc, Root → Vàng

- `crop.gd` thêm `watered: bool`, `root_boost: bool` (lưu trong crop record). `water()`/`rain_water()` set cho ô có crop; **`plant()` đọc trạng thái đất: `watered = moisture > 0 or raining`** (fix pre-watering). Item "Root Tonic" (Bếp chế từ `root_item`) chỉ nhận khi `watered == true`, 1 lần/chu kỳ.
- Harvest tier: 2 nếu (watered && root_boost), 1 nếu watered, 0 còn lại. Boost ong-giảm-deadline giữ nguyên.
- Migration: crop dở dang save cũ → `watered=true` (grace Bạc 1 lần).
- Feedback diegetic (v2.1 — tách "ẩm đất" khỏi "hứa chất lượng"): đất ẩm tối chỉ là trạng thái ẩm (bay hơi sau 6h); cờ `watered` giữ nguyên cả vụ. **Dấu "hứa Bạc/Root" phải nằm trên CÂY hoặc khung thông tin** (`soil_focus_component` sẵn có), không phụ thuộc màu đất — tránh người chơi hiểu nhầm "đất khô = mất Bạc". Root = đốm vàng; harvest burst 3 biến thể.
- Test: mưa tính tưới; gieo đất ẩm sẵn → Bạc; Root chưa tưới bị chối; save/load giữa chu kỳ; worker tưới hộ cho Bạc.

### S2 — Gỗ & Lâm nghiệp hoàn chỉnh (v2 — kinh tế khóa chặt)

**Đã triển khai:** giá mua 63 xu (làm tròn từ 62,5); gỗ thêm cho mức 3×3/4×4/5×5/6×6 là 10/15/20/30, lấy Warehouse rồi túi (Thường). Chưa có hook mở rộng Bếp. Xem [báo cáo S2](planting_depth_s2.md).

- Giá bán wood → 1 xu; **giá mua wood = 2.5 × GIÁ BÁN CŨ (pre-nerf)**, độc lập với giá bán mới. **Cap cứng 30 gỗ/ngày** (hiện `12/30` trên UI shop; reset theo mốc ngày chung).
- Tool upgrade từ U3 thêm chi phí wood; mở rộng Bếp thêm wood nếu có hook. Định lượng wood các bậc nâng cấp phải đối chiếu cap 30/ngày + tốc độ tự trồng (không được biến van thoát thành cổng chờ — rà ở phần cân bằng).
- **Chống root-printer:** root_item CHỈ rơi khi đập gốc của cây **đã trưởng thành** (2 root/gốc); cây non uproot hoàn trả sapling, không root (tái dùng pattern `fruit_tree.uproot`).
- Stump: `dig_hits = 1`; cuốc NxN quét gồm cả gốc.
- Migration: wood cũ giữ nguyên làm vật liệu, không đền.
- Test: không farm tiền bằng gỗ; mua vượt 30 bị chặn; đập gốc non không ra root; NxN dọn gốc; save cũ an toàn.

### S3a — Ghép cành (GIỮ chu kỳ quả hiện tại)

**Đã triển khai:** UI E/click/touch trên cây trưởng thành, hướng hiện tại/hướng chờ, nút thu; Sáp Ghép (5 gỗ + 1 Mật Dại + 1.000 xu, 60 giây); 4 quả Star riêng và 4 món Chef dùng Star. Thông số thử nghiệm, hướng mới luôn bắt đầu sau lần thu kế tiếp. Xem [hướng dẫn và kiểm chứng S3a](planting_depth_s3a.md).

- `TreeDefinition` + `graft: NONE|YIELD|QUALITY`; save thêm `graft`. **Trưởng thành lần đầu → prompt "Chờ Định Hình", chọn FREE, không deadline — cây chưa chọn vẫn ra quả thường ×1** (no FOMO). Đổi hướng = "Sáp Ghép" (Bếp: mật ong + wood + vàng).
- **Cân bằng 2 nhánh (v2 — tách trục):** YIELD = `harvest_amount` ×2 quả Thường (làn tiền/Orders); QUALITY = số lượng giữ nguyên nhưng ra **quả Star — nguyên liệu BẾP RIÊNG** mở công thức thượng hạng, **giá bán thô = 1.0x quả thường** (không nhân 3.5x). Tradeoff thật: làn Orders hay làn Kitchen.
- **Đổi hướng ghép áp dụng TỪ VỤ TIẾP THEO (v2.1):** đợt hiện tại — kể cả cây đang tích `fruit_work` chưa chín — vẫn thu theo hướng cũ; hướng mới có hiệu lực từ chu kỳ bắt đầu sau lần thu kế tiếp. Cài đặt: tách `active_graft` (chi phối mẻ đang chạy) và `pending_graft`; harvest xong mới swap. Chống đổi hướng sát lúc thu.
- Migration: cây trưởng thành save cũ → prompt chọn FREE lần đầu vào game; `fruit_work`/quả đang chín **giữ nguyên**; graft mặc định NONE.
- Test: 2 nhánh đúng hiệu ứng; quả Star là item riêng, không thay thế quả thường trong công thức thường; worker thu hộ tôn trọng graft.

### S3b — (DEFERRED) Nhịp bình minh — slice riêng SAU thử chơi S3a

- Chỉ làm nếu thử chơi xác nhận vấn đề trôi mốc 24h là thật. Khi làm: **dùng chung mốc ngày hiện có của weather/lương (06:00 UTC+7)** — một hằng ngày duy nhất toàn game, không thêm 04:00 riêng.
- Grace bằng timestamp: sinh quả ở bình minh D ⟺ `matured_at ≤ dawn(D−1)` (so sánh timestamp, chống 03:58→04:00). Mỗi loài `fruits_per_dawn` 1–3; không dồn offline. Buff ong-cho-quả (đang rút ngắn chu kỳ) chuyển thành **+1 quả/bình minh** cho cây trong bán kính (thay vì bị xóa cùng `fruit_cycle_seconds`).

### S4 — Vườn hoa: 3 cụm, 8 chậu cố định, snapshot đầu mẻ (v2)

- **Bố cục đã được người dùng chọn:** giữ 180 vị trí của 4 khối 9×5. Khối trên trái có 3 tổ **hàng 3, cột 2/5/8** (thay 3 chậu tâm); mỗi tổ đọc đúng **8 chậu quanh nó** (24 chậu combo). 18 chậu còn lại của khối này và 135 chậu trong 3 khối khác trồng tự do: tổng **177 chậu trồng + 3 tổ**, 153 chậu Tự Do. **Không dùng bán kính cho tổ combo.**
- **Gió tách bạch:** ong RUỘNG giữ +50% bán kính (hiện trạng, không đụng); cụm VƯỜN: ngày gió +25% tốc độ tạo mật.
- **Công thức chốt lúc BẮT ĐẦU mẻ ủ (snapshot) — tách bạch "khóa công thức" và "duy trì sản xuất" (v2.1):** hệ thống quét vòng 8 chậu, xác định Recipe ID, lưu vào mẻ; giữa mẻ hái/nhổ/trồng không đổi LOẠI mật. **Tốc độ sản xuất vẫn phụ thuộc nguồn hoa HIỆN CÓ** (khớp kiến trúc sẵn: `honey_rate(pollination.source_id)`, hết hoa rơi về nhịp Mật Dại) — giữ hoa vài giây đầu mẻ không ăn được tốc độ; **tiến độ đã tích không bao giờ mất** khi thiếu hoa (no-punishment). Vòng invalid lúc snapshot → Mật Tạp; cấu hình mới áp dụng mẻ sau.
- **Ưu tiên công thức:** xét lai trước, đơn sắc sau; 2 lai cùng đúng → theo thứ tự định nghĩa trong data.
- 5 công thức in rõ trong Sổ tay Ong từ đầu; bóng mờ chỉ cho hũ chưa từng nấu.
- Hive hybrid: cụm giữa sẵn dùng; tổ 1 & 3 "mục" — sửa 15 gỗ + 500 vàng từng tổ.
- **Migration hai pha, không mất gì (v2.1):** (1) tính TOÀN BỘ phương án di chuyển trước khi sửa save — hoa ở 3 ô tổ → chậu Tự Do trống gần nhất (giữ tiến độ), hive cũ thứ 4+ → item hive vào túi **kèm điều kiện: mọi mẻ mật đang chạy/chờ thu trên các tổ cần di dời hoặc hoàn trả đã được thu hết** — hoàn trả item hive trơ trụi không bảo toàn được mẻ mật, nên migration **đợi thu hết mẻ rồi mới chuyển** (điều kiện này nằm trong nhóm "đủ điều kiện" của bước kiểm tra, cùng chuyện đủ chậu/đủ chỗ túi — đã có cơ chế trì hoãn + thông báo + chạy lại idempotent lo phần chờ); (2) kiểm tra đủ chỗ; đủ thì áp dụng; thiếu thì trì hoãn chuyển đổi giữ layout cũ. **Tuyệt đối không gọi `add()` rồi bỏ phần dư** — không mất hoa, tiến độ, mẻ mật hay tổ ong trong mọi tình huống.
- **Chờ migration — ngăn khởi động mẻ mới:** ngay khi xác định tổ thuộc diện di dời/hoàn trả, đánh dấu tổ đó chờ chuyển đổi **trước khi mô phỏng offline hoặc cập nhật sản xuất**. Mẻ đã bắt đầu vẫn tích tiến độ theo luật cũ, hoàn tất và cho thu bình thường; không reset tiến độ hoặc xóa mật chờ thu. Sau khi thu, tổ giữ trạng thái trống, không bắt đầu mẻ tiếp theo cho tới khi migration hoàn tất. Tổ đã trống khi đánh dấu cũng không khởi động mẻ mới. Chỉ áp dụng cho tổ cần di dời/hoàn trả; các tổ khác hoạt động bình thường. Trạng thái chờ phải được lưu hoặc suy ra ổn định khi load để save/load và offline không vô tình tạo mẻ mới. Thông báo nêu rõ tổ đang chờ chuyển đổi và điều kiện còn thiếu; kiểm tra lại sau khi thu mật/dọn chỗ và khi load, áp dụng migration đúng một lần khi đủ điều kiện.
- Test: snapshot sống sót qua kịch bản hái hoa giữa mẻ; tráo chậu phút chót không đổi mật; ưu tiên lai>đơn; sửa tổ trừ gỗ+vàng. Migration: mẻ cũ tiếp tục và thu đủ; tổ chờ không tự khởi động mẻ mới sau thu hoặc qua save/load/offline; tổ không di dời vẫn sản xuất; thiếu chỗ không mất đồ; đủ điều kiện thì chuyển đúng một lần và tổ được giữ lại hoạt động theo luật mới.

### S5 — Kinh tế vĩ mô: Perfect Delivery + ô màu mỡ

- Perfect Delivery: auto-fill **chỉ dùng Thường**; nút "Nộp Hoàn Hảo" tách riêng (cần 100% đơn từ Bạc+), thưởng = max(150% thưởng đơn, 110% giá bán đúng tầng) (B1, THỬ NGHIỆM); preview số lượng từng tầng sẽ dùng trước xác nhận.
- **Ô màu mỡ = cơ chế kinh tế (không phải polish):** 15–20% ô farmland **rải theo Ô (không theo cột)**, layout = `stable_hash(cell_x, cell_y, LAYOUT_VERSION)`; **LAYOUT_VERSION lưu trong save** — thuật toán giữ ổn định giữa các bản game, hỗ trợ thuật toán cũ theo version đã lưu; đổi version phải qua migration chủ đích, cập nhật game không làm ô đổi chỗ. Hiệu quả `max(base + 1, int(round(base × 1.5)))` cho mọi loại rau; viền đỏ, sáng lên khi cầm hạt; không ảnh hưởng tầng chất lượng.
- Test: base 1 → 2; base 4 → 6; cập nhật ALGO_VERSION không di chuyển ô nếu không migrate; preview tầng đúng.

## 4. Thứ tự & phụ thuộc

| Slice | Phụ thuộc | Bump schema |
|---|---|---|
| S0 Chất lượng stack (không đổi sức chứa) | Rà farm storage trước | +1 |
| S1 Chất lượng rau | S0 | +1 |
| S2 Lâm nghiệp | — | +1 |
| S3a Ghép cành | S0 (quả Star), S2 (Sáp Ghép cần wood) | +1 |
| S4 Vườn ong | S2 (sửa tổ cần gỗ) | +1 |
| S5 Kinh tế vĩ mô | S0, S1 | +1 |
| S3b Bình minh (deferred) | S3a thử chơi xong | +1 |

## 5. Rủi ro đã chấp nhận

- Time-travel (chỉnh giờ) — chấp nhận như Stardew/AC.
- Nerf giá bán wood không đền bù (wood giờ là vật liệu giá trị hơn).
- Optimizer hết sink cuối game — thuộc phần 4 và các milestone sau.
- Cap 30 gỗ/ngày có thể thành cổng chờ nếu định lượng wood nâng cấp lệch — rà ở phần cân bằng.

## 6. Ý tưởng trượt (deferred)

- Tem Thị Trấn (chờ decor shop) · Hạt phấn buff ong · Silo-building cosmetic · "Gỗ Cổ Thụ" · bình minh 04:00 riêng (dùng mốc chung 06:00 nếu S3b làm).

## 7. Ghi chú engineering

- S0: tier áp cho cả luồng warehouse (farm storage v25) — rà trước khi code.
- S1: tái dùng `_moisture`; cờ per-crop trong crop record (tiền lệ `fertilized`, `pollination_reduction`).
- S4: mở rộng `PollinationComponent` thêm đọc 8 chậu theo garden-grid; Recipe ID snapshot lưu trong batch record.
- S5: ALGO_VERSION nằm trong save schema, không hardcode.
