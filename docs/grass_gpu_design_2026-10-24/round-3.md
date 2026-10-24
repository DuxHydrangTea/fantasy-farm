# Vòng 3 — Codex ↔ Antigravity

Model yêu cầu: `gemini-3.8-flash-high`; effort: `high`; chế độ: `plan`.

## Phản biện gửi đi

Round 3 — final red-team/convergence. No tools, edits, or questions to the human. Your revised renderer is much better, but the actor contract still silently loses animals and makes unsupported performance claims. Resolve these before signing off.

New PRIMARY-SOURCE verification (Godot 4.7 source, both servers/rendering/renderer_rd/shaders/canvas.glsl and drivers/gles3/shaders/canvas.glsl): the MultiMesh instance matrix is multiplied into model_matrix BEFORE #CODE : VERTEX. Therefore bottom-root MODEL_MATRIX*vec4(0,0,0,1) is supported by source on BOTH backends. Still require engine POC with multiple transformed instances, flipped/scaled parents, row offsets, camera zoom and origin. Official docs explicitly say RenderingServer bypassing nodes only helps a SceneTree bottleneck, not an already saturated GPU.

Remaining corrections required:
- You reintroduced '16 wins completely' and '50 actors will cross over to 128x128 R8' without measurements. Retract these too. R8 is a scalar mask: it cannot directly store a directional bend vector. A directional field needs a defined multi-channel packing/format and an actual render-target API support check. RTT also has actor/draw/clear cost; not truly unlimited.
- Static/sleeping actors still occupy shader influence slots, are tested in every visible blade vertex and must remain pressing grass under their bodies. Skipping redundant CPU uploads is NOT zero per-frame GPU cost. Never drop stationary actors solely for being stationary.
- A 16-slot list with hysteresis still omits >16 visible actors; 'no omissions' was false. The default contract for this farm must support ALL eligible existing actors (up to87), not silently sacrifice nearby animals. Proposed exact baseline: compile/test a bounded MAX_INTERACTORS=96 array (position+radius/strength and previous-position/velocity data as needed, a few KiB), shader loops only active_count; benchmark counts 1,8,16,32,64,87. Optional smaller variants only if they do NOT drop eligible actors (fallback to full variant when needed). If 96 or real active load fails target limits, use the measured alternative FIELD backend or explicitly restrict gameplay scope with human approval. This does not claim the 96 path will be fast: that's what we must measure. Compare 60Hz vs30Hz uploads with real perceptual latency; do not assume30Hz is faster overall. At N<=87, CPU position collection may be negligible.
- Stateless smooth falloff can recover continuously; it is not a physical spring history. Baseline wind+distance/swept-capsule bend with clamped accumulation and a bounded recent-impact approximation is sufficient for 'sway when passing'; persistent trails are optional later. No per-blade CPU state, physics collision, or GPU readback.
- Strict one Node: ONE owner/manager, multiple chunk/row CanvasItem RIDs, shared atlas/material and static instance buffers. Row items must be siblings/flattened into the SAME world Y-sort group as actors; matching z_index/ground row pivot matters. Sort inside MultiMesh alone is insufficient. Handle world-local row transforms, source tile origin/flip/scale, actual opaque-ground pivot (16px image bottom is not automatically visible root), manager hide/disable/reload, and do not double-free resource-owned RIDs. User-created canvas RIDs are freed by owner; resource refs have resource ownership.
- Chunk size256/512px and background/tall split are INITIAL TEST VALUES, not settled magic constants. Enlarge bounding rect for full sprite extent + maximum shader displacement. Do not rebuild buffers or rescan TileMap each frame; source extraction and atlas prep at load/editor bake, changes incremental. Only allowlisted decorative grass is replaced; baked Ground/soil/rocks/flowers/crops remain as authored. Reuse authoring TileMaps as data, not deform the mixed 4px atlas blindly.
- Proposed acceptance gates: EXACTLY <=1 added scene Node, zero per-blade scripts/physics/Tweens; verified anchors/atlas frames/y-sort/actor completeness; no CPU collision readback; bounded memory and RID lifetime; compare baseline/static/wind/interactions at1k/10k/50k VISIBLE tufts and1/16/32/87 actors, plus offscreen-world scaling. Report CPU and GPU frame times and p95/p99, not only FPS; budgets tied to a60fps frame16.67ms or30fps33.33ms product target. No fabricated timings or arbitrary60draw-call cutoff. Real Android/iPhone/browser thermal runs are required for claims, desktopGL alone not proof.

Please give a final signed-off design contract in Vietnamese <=1000words. State AGREE or remaining material objections. If you reject full96uniform as a BASELINE to benchmark, offer a comparably precise completeness-preserving baseline and justify WITHOUT invented benchmark data. Separate agreed architecture from measurements/POC still outstanding. This is architecture agreement, not a declaration that an implementation has passed. We will document the three rounds and proceed to a POC only on the user's later implementation request.

## Phản hồi của Antigravity

**XÁC NHẬN ĐỒNG THUẬN (AGREE)**. Tôi hoàn toàn đồng ý với các hiệu chỉnh, cơ chế bảo toàn actor và tiêu chuẩn đánh giá nghiêm ngặt mà bạn đưa ra ở Vòng 3. Dưới đây là văn kiện kiến trúc thống nhất cuối cùng trước khi chuyển sang giai đoạn dựng POC.

---

### 1. Rút lại và Sửa đổi Cuối cùng (Final Retractions)

1. **Rút lại toàn bộ suy đoán về RTT/R8**: R8 là định dạng vô hướng đơn kênh, không thể lưu vector uốn định hướng (directional bend) nếu không mã hóa phức tạp hoặc dùng đa kênh (RGBA). Render Target Texture (RTT) luôn có chi phí clear, draw và switch context cố định, không phải "vô hạn" hay "tự động rẻ hơn".
2. **Loại bỏ giới hạn 16-slot làm mất actor**: Không chấp nhận việc âm thầm bỏ rơi các con vật hợp lệ trên màn hình. Mọi actor trong tầm tương tác (tối đa 87 con vật + Player) phải được đảm bảo phản hồi.
3. **Sửa đổi quan niệm về Actor đứng yên**: Bỏ qua cập nhật CPU không có nghĩa là GPU tiêu tốn 0ms. Động vật đứng yên vẫn đè lên cỏ, vẫn chiếm slot và vẫn buộc vertex shader phải tính khoảng cách để duy trì trạng thái bị đè.

---

### 2. Hợp đồng Kiến trúc Đã Thống nhất (Agreed Design Contract)

#### A. Renderer Cơ sở & Quản lý Hình học
- **Cơ sở lý thuyết vững chắc**: Mã nguồn Godot 4.7 (`canvas.glsl` trên cả RD và GLES3) đã xác nhận: ma trận instance của `MultiMesh` được nhân vào `model_matrix` **trước** khối `#CODE : VERTEX`. Do đó, logic gốc tọa độ đáy (`MODEL_MATRIX * vec4(0, 0, 0, 1)`) được hỗ trợ tự nhiên trên cả Forward+ lẫn Compatibility.
- **Hình học Quad chuẩn**: Dùng quad đáy $x \in [-8, 8]$, $y \in [-16, 0]$, pivot tại $(0, 0)$. Chiều cao uốn được chuẩn hóa theo tỷ lệ $-y / 16.0$. Phải tinh chỉnh offset nếu gốc trực quan (visual opaque root) của pixel art lệch khỏi đáy ảnh 16px.
- **Atlas & Hoạt ảnh 8 frame trên GPU**: Gom 18 strip $128 \times 16$ thành 1 atlas duy nhất tại build/bake time. Shader tự tính UV frame dựa trên `TIME`, phase và strip ID truyền qua `INSTANCE_CUSTOM`. Giữ nguyên dữ liệu gốc của Ground, đá, hoa màu; chỉ thay thế cỏ trang trí thuộc danh sách cho phép (allowlist).
- **Mở rộng AABB (Culling Bounds)**: Bounding rect của các chunk cỏ phải được cộng thêm biên độ dịch chuyển tối đa của shader (`max_displacement`) để tránh bị biến mất đột ngột ở rìa màn hình.

#### B. Khung Quản lý Thực thi (Strict $\le 1$ Scene Node)
- **Cấu trúc sở hữu**: Đúng **1 Scene Node duy nhất** (`GrassManager : Node2D`) quản lý vòng đời.
- **Tương thích Y-Sort**: Không dùng một MultiMesh khổng lồ. Tạo các `CanvasItem RID` theo từng dải hàng (row-bands) hoặc chunk, gán làm sibling trực tiếp trong cùng nhóm Y-sort của World (`RS.canvas_item_set_parent`). Gốc toạ độ Y của từng CanvasItem RID phải khớp chính xác với trục Y của hàng gạch đó.
- **Quy tắc giải phóng tài nguyên**: Giải phóng thủ công toàn bộ các `CanvasItem RID` do code tự tạo trong `_exit_tree()` bằng `RS.free_rid()`. Giữ nguyên cơ chế quản lý tự động đối với các Resource (Mesh, Texture) để tránh lỗi double-free.

#### C. Hợp đồng Tương tác Actor Toàn vẹn (Actor Completeness Contract)
- **Baseline không mất actor**: Thiết lập mảng uniform cố định với `MAX_INTERACTORS = 96` (đủ cho 87 farm animals + player + 8 slot dự phòng). Mảng chứa tọa độ hiện tại, bán kính, lực và tọa độ trước đó (dữ liệu swept capsule).
- **Shader Loop động**: Shader chỉ lặp qua `uniform int active_count`.
- **Mô hình uốn không trạng thái (Stateless Analytic + Swept Capsule)**:
  - Sử dụng swept-capsule distance để actor chạy nhanh không bị lọt qua cỏ giữa 2 nhịp cập nhật.
  - Tích lũy độ uốn có giới hạn (clamped accumulation) kèm xấp xỉ suy giảm êm sau va chạm gần nhất. Không dùng mô phỏng vật lý per-blade, không đọc ngược GPU (no readback).

---

### 3. Kế hoạch Kiểm chứng Thực nghiệm & Tiêu chí Chấp thuận (Acceptance Gates)

Mọi tuyên bố về hiệu năng từ thời điểm này bắt buộc phải dựa trên đo đạc thực tế, không dùng số suy đoán:

#### A. Ma trận Đo đạc Benchmark (A/B Test)
- **Mật độ cỏ hiển thị**: Kiểm thử tại các mốc **1.000**, **10.000**, và **50.000** bụi cỏ hiển thị trên màn hình.
- **Tải trọng Actor**: Đo đạc tại các mốc **1**, **8**, **16**, **32**, **64**, và **87** actor đồng thời.
- **Tần số cập nhật**: So sánh trực tiếp CPU/GPU time và độ trễ cảm nhận giữa **60Hz** và **30Hz** upload.
- **Thang đo bắt buộc**: Ghi nhận CPU Frame Time, GPU Frame Time, phân vị **p95** và **p99** (hướng tới mục tiêu khung hình 16.67ms cho 60fps hoặc 33.33ms cho 30fps). Bắt buộc chạy profile nhiệt trên thiết bị thật (Android, iOS và trình duyệt WebGL2), không chỉ dựa vào Desktop OpenGL.

#### B. Tiêu chí Chấp thuận (Gate Pass Criteria)
1. **Kiến trúc**: Đúng $\le 1$ Scene Node, không sinh node con, không dùng CPU Tweens/Area2D/Physics per-blade.
2. **Hình ảnh**: Không rách pixel art khi camera zoom lẻ; gốc cỏ bám sát mặt đất; Y-sort chính xác tuyệt đối với Actor ở cả 4 hướng di chuyển.
3. **Toàn vẹn**: 87 actor chạy qua đều làm uốn cỏ chính xác; không có hiện tượng giật nảy (popping) do rớt slot.
4. **VRAM/Ổn định**: Không rò rỉ RID khi reload scene; duy trì ổn định không tụt xung do quá nhiệt trên mobile.

---

### 4. Kết luận Phê duyệt

Kiến trúc trên đã đạt độ chín về mặt lý thuyết và thỏa mãn toàn bộ ràng buộc của dự án. Chúng ta **chính thức chốt hợp đồng kiến trúc này** và sẵn sàng chuyển sang bước triển khai Proof of Concept (POC) khi bạn yêu cầu.

