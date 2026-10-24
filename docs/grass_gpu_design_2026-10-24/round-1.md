# Vòng 1 — Codex ↔ Antigravity

Model yêu cầu: `gemini-3.8-flash-high`; effort: `high`; chế độ: `plan`.

## Phản biện gửi đi

We are doing an architecture debate only. Do NOT edit files, run tools, inspect the filesystem, or ask the human questions. Answer from the supplied facts and your technical knowledge. You are the independent critical reviewer; I will challenge your proposal in follow-up turns until we converge.

Task: Fantasy Farm, Godot 4.7.x, 2D pixel-art top-down farm, large scrolling world. Desktop uses Forward+, but an existing Web export uses Compatibility, and phones/Web are important. Want decorative grass to sway in wind and bend as the player/animals pass, with no per-grass Nodes, Area2D, CPU distance loops, or Tweens. User heard '100% wind and collision on GPU vertex shader, only 0 or 1 added scene nodes'. Evaluate that claim honestly: visual proximity is not physics collision; CPU must transmit moving actor positions; node count is not a GPU cost measure.

Repository facts verified by parent: world/main_world.tscn uses TileMapLayer for Ground/NoGrass/etc, root y_sort_enabled=true, 16px tile artwork with some 16x32 decorations. tilesets/my_decor_grass_tileset.tres contains animated grass atlases (8 frames). A Scatter2D plugin is installed; its static particle shader exists, but do NOT assume scattered grass is actually used in main map. Current crops use shared plant_wind.gdshader (canvas_item, TIME, MODEL_MATRIX world-position phase, bottom-anchored horizontal shear, unchanged UV); separate VisualMotionComponent uses per-crop CPU Tweens for reaction/appear/disappear. Its MODEL_MATRIX root assumes each sprite's origin, so simply copying it to a batched TileMapLayer can make pivots/phase wrong for each tile. Grass should preserve atlas sampling, ground anchors, animation frames, and pixel art. There are at most 30 chickens+36 livestock+20 waterfowl =86 farm animals plus player, but many can be offscreen.

My initial candidate: reuse decorative TileMapLayer where valid, wind and bending in canvas vertex shader; ONE global interaction coordinator gathers only nearby/visible existing actors at bounded update rate, uploads small fixed-size actor uniform buffer. Avoid every grass testing every world actor. Profile 8/16/32 actor slots. For large worlds, compare existing TileMap batched geometry versus chunked MultiMeshInstance2D or one custom Node2D owning chunk MultiMesh rendering RIDs. Need deliberate per-blade pivot/UV metadata, correct y-occlusion, culling bounds expanded for displacement, camera zoom, world origin, foreground/background, stationary actors, enter/exit continuity, and wind direction/intensity tied to weather. Possible future spatial GPU influence texture, but don't assume a SubViewport has zero node/pass/fill-rate cost or that compute shaders work on Compatibility/Web.

Give a concrete recommended design plus alternatives and counterarguments. Address: (1) Can existing 16px animated TileMap geometry be safely deformed with no atlas/pivot seam? Is mesh metadata guaranteed? (2) Is one giant MultiMesh efficient for a huge map, and can its instances y-sort against actors? (3) Fixed actor lists vs spatial interaction texture: actual asymptotic costs, uniform limits, WebGL/phone tradeoffs. (4) Stateless analytic bend vs persistent spring field/trails. (5) Why target 0/1 SCENE nodes without claiming 0/1 draw calls, allocations or GPU passes. (6) Explicit rejection criteria and benchmark plan, no fabricated FPS. Propose a phased implementation that can be changed after measurement. Be skeptical, and list unresolved points you need me to verify. Vietnamese answer preferred, <=1200 words.

## Phản hồi của Antigravity

Dưới đây là đánh giá phản biện độc lập về mặt kiến trúc cho hệ thống tương tác cỏ trong Fantasy Farm (Godot 4.7.x, Compatibility/Forward+).

---

### 1. Bóc trần luận điểm "100% GPU / 0–1 Scene Node"

Tuyên bố này đánh tráo khái niệm giữa **tính toán hình thái (visual displacement)** và **va chạm vật lý (physics collision)**:
- **Visual displacement ≠ Collision**: Shader vertex chỉ đẩy tọa độ đỉnh dựa trên khoảng cách tức thời. Không có phản lực lên Actor, không có broad-phase/narrow-phase và GPU không thể báo ngược va chạm về CPU nếu không stall pipeline (bất khả thi trên WebGL/Compatibility).
- **CPU không thể đứng ngoài**: GPU không tự biết 87 con vật đang ở đâu nếu CPU không gom tọa độ, culling ngoài màn hình và đẩy vào Uniform Buffer/Texture mỗi frame.
- **Bẫy "0 hoặc 1 Scene Node"**: Node count chỉ phản ánh chi phí traversal của SceneTree (CPU). Cái giết chết WebGL/Mobile là **Draw Calls, State Changes, Fill-rate và Vertex Shader instruction limits**, chứ không phải số lượng Node trên cây phả hệ.

---

### 2. Mổ xẻ 6 vấn đề kỹ thuật cốt lõi

#### (1) TileMapLayer: Biến dạng đỉnh 16px/16x32, Pivot và Atlas Seam
- **Mất Pivot cục bộ**: `TileMapLayer` gộp các tile thành các quadrant/chunk mesh lớn. `MODEL_MATRIX` là gốc tọa độ của cả Layer, không phải của từng tile. `plant_wind.gdshader` cũ dựa vào `MODEL_MATRIX` của từng Sprite sẽ lập tức gãy hoàn toàn.
- **Rủi ro Seam/Bleeding khi Atlas động (8 frames)**: Atlas dùng sub-UV. Nếu dịch chuyển đỉnh (`VERTEX`) mà không có padding an toàn (ít nhất 2–4px gutter giữa các frame trong atlas), texture filtering (kể cả Nearest khi camera zoom fractional) sẽ gây lem pixel từ frame lân cận.
- **Hỗn hợp 16px và 16x32**: Không thể dùng phép toán thô như `mod(VERTEX.y, 16.0)` trong vertex shader để tìm chân tile vì rác hình học của tile 32px sẽ bị cắt làm đôi hoặc neo sai điểm gốc.

#### (2) MultiMesh khổng lồ vs Y-Sort & Frustum Culling
- **Tử huyệt Y-Sorting trong Godot 2D**: `MultiMeshInstance2D` là **MỘT** `CanvasItem`. Cơ chế Y-Sort của Godot chỉ sắp xếp giữa các `CanvasItem` với nhau. **Toàn bộ hàng chục ngàn instance cỏ trong một MultiMesh sẽ nằm hoàn toàn đè lên HOẶC nằm hoàn toàn dưới chân Actor**. Không thể có chuyện Actor đi xuyên qua và đè lên cỏ phía sau nhưng bị cỏ phía trước che chân nếu dùng chung 1 MultiMesh.
- **Culling thất bại**: Một MultiMesh khổng lồ phủ toàn bộ map lớn buộc GPU phải xử lý toàn bộ đỉnh trong vertex shader ngay cả khi 95% map nằm ngoài màn hình, làm tê liệt băng thông WebGL/Mobile.

#### (3) Uniform Array (16 slots) vs Spatial Interaction Texture
| Tiêu chí | Fixed Actor Uniform Array (8–16 slots) | Spatial Texture (SubViewport RTT) |
| :--- | :--- | :--- |
| **Độ phức tạp CPU** | $O(N)$ culling khoảng cách với Camera, lấy Top K gần nhất | $O(N)$ render các actor footprint vào SubViewport |
| **Độ phức tạp GPU** | $O(V \times K)$ (Số đỉnh $\times$ số slot) trong Vertex Shader | $O(V)$ vertex texture fetch + $O(F)$ fill-rate cho SubViewport |
| **Web/Mobile** | Rất nhẹ, hỗ trợ chuẩn xác trên WebGL2/Compatibility | **Tử huyệt**: Thêm 1 render pass, context switch, vỡ băng thông tile-based GPU |
| **Giới hạn** | Giới hạn số vật tương tác đồng thời (max 16–32) | Không giới hạn số vật, nhưng giới hạn độ phân giải/vùng bao phủ |

*Kết luận*: Với tối đa 87 actor và phần lớn offscreen, Uniform Array 16 slot thắng tuyệt đối về hiệu năng và tính tương thích WebGL.

#### (4) Stateless Analytic Bend vs Persistent Spring Field
- **Persistent Field (Vết lún/Hồi phục trễ)**: Bắt buộc dùng ping-pong textures hoặc Compute Shader. WebGL2/Compatibility không có Compute Shader. Dùng SubViewport ping-pong trên Mobile sẽ gây pipeline stall và hao pin khủng khiếp.
- **Stateless Analytic**: Tính trực tiếp độ uốn bằng hàm suy giảm khoảng cách (`smoothstep`). Nhược điểm: cỏ lập tức bật lại khi actor vừa bước khỏi bán kính ranh giới, không có dao động tắt dần tự nhiên trừ khi mã hóa thêm vector vận tốc vào uniform.

#### (5) Định vị "0 hoặc 1 Scene Node"
- Khái niệm "1 Node" chỉ có ý nghĩa: Gom toàn bộ logic CPU query về **duy nhất 1 Node quản lý (Interaction Coordinator)** để tránh phân mảnh `_process`.
- Không được huyễn hoặc rằng 1 Node đồng nghĩa 1 Draw Call. `TileMapLayer` nội bộ vẫn chia quadrant; `MultiMesh` nếu chia chunk vẫn là nhiều RID rendering.

#### (6) Tiêu chí bác bỏ (Rejection Criteria) & Kế hoạch Benchmark
- **Tiêu chí bác bỏ ngay**:
  1. Draw call trên Web export vượt quá 60 calls cho toàn bộ hệ thống cỏ.
  2. Thời gian CPU culling + upload uniform của Coordinator vượt quá **0.5ms** trên thiết bị mobile tầm trung.
  3. Xuất hiện texture bleeding tại viền tile khi camera zoom out/in.
  4. Lỗi thứ tự hiển thị: Chân nhân vật bị cỏ phía sau đè lên đầu (sai Y-sort).
- **Benchmark plan**: Đo bằng Godot Profiler (CPU Frame Time, VisualServer sync time) và RenderDoc/Chrome Tracing trên Web build với:
  - Stress test 87 actor cùng tụ tập tại 1 màn hình.
  - Test culling: 87 actor chạy rải rác ngoài màn hình, kiểm tra mảng uniform có bị cập nhật lãng phí không.

---

### 3. Đề xuất Kiến trúc Cụ thể

#### A. Kiến trúc render (Dựa trên yêu cầu Y-Sort):
1. **Phân tách Layer**:
   - Tách cỏ trang trí thành một `TileMapLayer` riêng (`DecorGrassLayer`), **tuyệt đối không để chung tile 16x32 với 16x16** nếu muốn dùng chung logic vertex offset.
   - Bật `y_sort_enabled = true` trên Layer này. Đây là cách duy nhất giữ được khả năng Y-sort tự nhiên với Actor trong Godot 2D mà không cần sinh hàng trăm Node/MultiMesh thủ công.
2. **Cơ chế Vertex Shader**:
   - Dùng tọa độ thế giới (`MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)`) kết hợp hàm lượng giác để tạo gió nền.
   - Nhận mảng `uniform vec4 u_actors[16]` (xy: world pos, z: radius, w: push_strength).
   - Neo chân ngọn cỏ: Chỉ uốn đỉnh phía trên bằng cách nội suy theo vị trí cục bộ của vertex trong tile (xác định qua phép tính phân kỳ tọa độ hoặc ánh xạ cấu trúc quad).

#### B. Bộ điều phối CPU (`GrassInteractionCoordinator` - 1 Node duy nhất):
- Không kế thừa logic nặng; chạy ở `_physics_process` hoặc tick rate giới hạn (30Hz thay vì 60Hz/144Hz).
- Sử dụng AABB của Camera + margin: Lấy danh sách Actor lọt vào view.
- Sort nhanh lấy 16 actor gần tâm camera/player nhất, pack thành `PackedVector4Array`, nạp 1 lần duy nhất vào `RenderingServer.material_set_param`.

---

### 4. Lộ trình triển khai phân kỳ (Phased Rollout)

- **Pha 1 (Proof of Concept trên 1 TileMapLayer cô lập)**:
  - Tạo shader canvas_item nhận mảng 4 actor tĩnh. Kiểm tra xem đỉnh 16px có bị trôi khỏi gốc tile hoặc rách atlas không.
- **Pha 2 (Bộ điều phối CPU & Benchmarking sơ bộ)**:
  - Dựng coordinator gom tọa độ Player + 10 animal test. Đánh giá chi phí upload uniform trên Web export.
- **Pha 3 (Thử nghiệm ranh giới Y-Sort & Cắt tỉa)**:
  - Cho Player đi qua cụm cỏ dày: xác nhận Y-sort đúng ở cả 4 hướng tiếp cận. Thử nghiệm scale lên 87 actor xem CPU overhead có dưới ngưỡng 0.5ms.

---

### 5. Các điểm nghi vấn kỹ thuật cần làm rõ

1. **Chiều cao đồ họa của cỏ**: Toàn bộ cỏ trong `my_decor_grass_tileset.tres` là 16x16 chuẩn hay có đan xen 16x32?
2. **Mức độ quan trọng của Y-Sort**: Cỏ trang trí này là "thảm cỏ bẹp dưới đất" (đạp lên trên, không cần Y-sort) hay "bụi cỏ cao" (cần che khuất chân nhân vật khi đứng sau)?
3. **Atlas Padding**: Atlas 8 frame hiện tại có pixel margin/gutter giữa các frame không, hay được xếp sát cạnh nhau (0px margin)?

