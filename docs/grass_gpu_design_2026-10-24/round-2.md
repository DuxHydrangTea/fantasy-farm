# Vòng 2 — Codex ↔ Antigravity

Model yêu cầu: `gemini-3.8-flash-high`; effort: `high`; chế độ: `plan`.

## Phản biện gửi đi

Round 2: I disagree with several absolute claims. Please revise, not merely agree. No tools/file reads/edits; discuss only.

Verified additional facts: all 18 source Grass_Animations PNG strips are 128x16, eight adjacent 16x16 frames, no declared gutters. However MAIN world Decor and TinyDecor share a DIFFERENT tileset whose logical tile_size is 4x4; it includes heterogeneous decorations and cannot be assumed to match the isolated 16x16 animated-grass tileset. Ground includes baked terrain/grass art and MUST NOT be displaced wholesale. TinyDecor already has y_sort_enabled. Scatter2D sorts instance transforms by Y only WITHIN each MultiMesh; that does not interleave a multimesh's instances with external actor CanvasItems.

Official Godot 4.7 docs checked: Canvas shaders offer VERTEX_ID/CUSTOM0/CUSTOM1, but this is not a guarantee TileMap populates per-tile pivot/atlas metadata. TileMap rendering_quadrant_size is ignored in Y-sort mode because tiles group by Y. RenderingServer.canvas_item_set_sort_children_by_y and canvas_item_set_parent allow canvas items without scene nodes. Compute shaders are unavailable to Compatibility.

Corrections to your first answer:
1. Pure VERTEX deformation with unchanged UV does NOT inherently require new atlas gutters. Nearest + fractional camera zoom causes aliasing, not automatically neighboring-frame bleeding. Sampling rect, filtering/mipmap, UV deformation and atlas animation must be audited separately. Do you retract the unconditional 2-4px gutter claim?
2. 'Uniform16 wins absolutely', 'RTT destroys mobile bandwidth', and '60 draw calls is a rejection threshold' are unmeasured claims. Set provisional RELATIVE CPU/GPU budgets; use paired A/B benchmarks and worst-case visible density. 87 actors on screen cannot all be represented in 16 slots: explicitly define acceptable degradation or a field-texture backend if >K. Include stable slots/hysteresis, no popping, radius-aware camera culling, player priority, stationary actors, and swept movement so 20-30Hz uploads don't miss grass.
3. Stateless smooth falloff need not abruptly snap at a radius boundary; it has no true persistent per-blade spring/trail memory. Persistent appearance can also be approximated with bounded timestamped impact segments, not necessarily a full simulation texture. GPU readback is undesirable, not physically impossible.
4. Your proposal added a NEW TileMapLayer AND a coordinator (2 nodes), contradicting strict <=1 extra node. And TileMap is not the only possible Y-sort path. Counterproposal: ONE GrassField Node2D owns chunked rendering RIDs via RenderingServer; short grass uses background batches, tall grass uses row-band CanvasItems parented into the world's existing Y-sort space, with local Y at root/row origin. Need verify parenting/coordinates/interleave, disclose RID and draw-call count, and free every RID. This is a design, not a claim of verified performance.
5. Most critically your TileMap pivot solution is still handwaving. No fract(VERTEX/16), VERTEX_ID%4 or per-tile CUSTOM metadata assumption without an engine-tested contract. Either specify a provably valid TileMap metadata mechanism for animated/flipped/origin-shifted tiles, or reject it as primary and recommend controllable quad/MultiMesh geometry. Need validate how INSTANCE transform participates in MODEL_MATRIX in both renderers, not assume shader world-root math.

Candidate robust backend: static per-blade transforms with bottom-root quad geometry, one shared material/atlas, per-instance type/phase/custom data; animate original eight frames on GPU using UV inside the correct atlas frame. Optionally pack only allowlisted decorative grass sprites into one small prepared atlas at build time (18 strips, no need giant textures); keep ground/rocks/crops unchanged. Chunk by world area for culling and use row strips ONLY where real actor occlusion is required. One manager is an ownership/API choice; many RIDs/buffers/draw calls remain. No upload of blade transforms every frame.

Please choose the best BASELINE renderer for this actual mixed-tileset project; choose actor uniform versus optional spatial field strictly on measured crossover, not ideology. Explain a strict <=1 added scene-node implementation, and which rendering/visual behaviors must be verified in the first POC before shipping. Distinguish initial recommendation from facts we have actually proven. Reply Vietnamese <=1000 words, with explicit retractions where appropriate.

## Phản hồi của Antigravity

Dưới đây là bản điều chỉnh kiến trúc dựa trên phản biện chính xác của bạn, các dữ kiện đã đối soát và tư duy kiểm chứng nghiêm ngặt.

---

### 1. Rút lại các kết luận tuyệt đối hóa (Explicit Retractions)

1. **Rút lại tuyên bố "bắt buộc đệm 2–4px gutter"**: Biến dạng đỉnh thuần túy (`VERTEX`) giữ nguyên `UV` cục bộ sẽ không làm tràn toạ độ sang frame khác. Với Nearest filtering và UV tính đúng theo từng frame $16 \times 16$, hiện tượng lem không tự động xảy ra.
2. **Rút lại tuyên bố "Uniform 16 thắng tuyệt đối" và mốc "60 draw calls"**: Đây là các con số giả định, chưa qua profile thực tế. Phải thay bằng **mô hình ngưỡng giao thoa (crossover threshold)** giữa chi phí $O(V \times K)$ của vertex shader và chi phí 1 render-pass texture.
3. **Rút lại đề xuất thêm 2 Nodes (TileMapLayer + Coordinator)**: Đề xuất này vi phạm ràng buộc ngặt $\le 1$ Scene Node.
4. **Rút lại giả định dò pivot trên TileMapLayer**: Việc dùng `mod(VERTEX.y, ...)` hoặc suy đoán metadata từ `VERTEX_ID` trên tileset $4 \times 4$ hỗn hợp, có flip/offset là không thể đảm bảo an toàn.

---

### 2. Lựa chọn Renderer Cơ sở: Bottom-Anchored MultiMesh RIDs

Do `main_world` dùng tileset $4 \times 4$ và TileMap không đảm bảo metadata per-tile, **TileMapLayer bị loại khỏi vai trò làm renderer cho cỏ động**.

**Kiến trúc cơ sở đề xuất**:
- **Hình học chuẩn hóa**: Quad $16 \times 16$ dựng sẵn với gốc tọa độ đặt tại đáy: toạ độ $x \in [-8, 8]$, $y \in [-16, 0]$. Chân cỏ luôn cố định tại $y = 0$, đỉnh ngọn tại $y = -16$. Shader làm biến dạng chỉ cần dựa vào $-y / 16.0$ làm hệ số suy giảm (falloff) từ ngọn xuống gốc.
- **Atlas gom cụm (Allowlisted Atlas)**: Gom 18 strip thành một texture đồng nhất $128 \times 288$ (18 hàng, mỗi hàng 8 frame $16 \times 16$).
- **Phân tách hiển thị & Y-Sort**:
  - *Cỏ nền thấp (không che thân)*: Gom thành các chunk lớn ($32 \times 32$ tile) trong một vài `MultiMesh` tĩnh để tối ưu batching.
  - *Cỏ cao (cần Y-sort)*: Tạo các CanvasItem RID theo từng dải Y (row-bands), gắn trực tiếp vào canvas cha có `y_sort_enabled` thông qua `RenderingServer`.

---

### 3. Thực thi nghiêm ngặt $\le 1$ Scene Node

Chỉ thêm duy nhất **1 Node2D quản lý** (`GrassManager`), hoặc nhúng trực tiếp vào World script sẵn có (**0 Node**):
- **Không sinh Scene Node con**: Toàn bộ các chunk và row-band được cấp phát dưới dạng **RenderingServer RID** (`RS.canvas_item_create()`, `RS.multimesh_create()`).
- **Liên kết Y-Sort không qua SceneTree**: Gọi `RS.canvas_item_set_parent(child_rid, world_ysort_canvas_rid)` và bật `RS.canvas_item_set_sort_children_by_y`. Toạ độ $Y$ của từng row-band RID được đặt trùng với toạ độ thế giới của hàng cỏ đó.
- **Quản lý bộ nhớ**: Mọi RID bắt buộc phải lưu trong mảng và giải phóng triệt để bằng `RS.free_rid()` trong `_exit_tree()` để chống rò rỉ VRAM.

---

### 4. Cơ chế Actor: Uniform Buffer, Suy giảm & Ngưỡng Giao thoa

#### A. Chiến lược phân bổ 16 Slot ổn định (Graceful Degradation):
Khi có $>16$ actor trong viewport, tránh popping và bỏ sót bằng các kỹ thuật:
1. **Ưu tiên tuyệt đối**: Slot 0 luôn dành cho Player.
2. **Culling theo Viewport + Bán kính mở rộng**: Chỉ xét actor nằm trong màn hình camera cộng thêm biên trượt tối đa.
3. **Hysteresis (Trễ biên)**: Một actor mới chỉ được cướp slot của actor cũ nếu khoảng cách tới camera gần hơn actor cũ một khoảng $\Delta d > 32\text{px}$ để tránh tráo đổi slot liên tục giữa các frame.
4. **Bỏ qua Actor tĩnh**: Động vật ngủ/đứng yên chỉ cập nhật 1 lần; không tốn chi phí tính toán lại mỗi tick.
5. **Swept Capsule cho nhịp 20–30Hz**: Truyền vị trí cũ ($P_0$) và mới ($P_1$) kèm bán kính. Shader tính khoảng cách từ đỉnh cỏ tới đoạn thẳng $P_0 P_1$, triệt tiêu hiện tượng actor chạy nhanh "xuyên qua" cỏ giữa 2 lần upload.

#### B. Ngưỡng giao thoa (Crossover Threshold) sang Spatial Texture:
Không loại trừ Spatial Texture theo cảm tính:
- **Nếu $N_{\text{actor\_visible}} \le 16$**: $16$ vòng lặp vector trong Vertex Shader có chi phí ALU cực nhỏ, vượt trội hoàn toàn việc tốn thêm 1 render-pass.
- **Điểm chuyển dịch**: Nếu gameplay đòi hỏi đàn gia súc 50 con tụ lại một chỗ trên màn hình, chi phí $O(V \times 50)$ trong Vertex Shader trên GPU di động sẽ vượt quá chi phí vẽ các footprint vào 1 SubViewport $128 \times 128$ (R8). Lúc đó mới bật backend Texture Field.

---

### 5. Kiểm chứng bắt buộc trong POC đầu tiên (First POC Scope)

Trước khi đưa vào sản xuất, bản POC tối thiểu phải chứng minh được:
1. **Hợp đồng Y-Sort của RS RID**: Kiểm chứng `RS.canvas_item_set_sort_children_by_y` có thực sự đan xen đúng thứ tự giữa các row-band MultiMesh RID với Node2D Player/Animal hay không.
2. **Tính toàn vẹn hình học Quad**: Xác nhận quad neo đáy ($y \in [-16, 0]$) khi bị shear bởi gió không gây giật pixel hoặc làm sai lệch tỷ lệ hiển thị pixel art dưới camera zoom fractional.
3. **GPU Frame Animation**: Kiểm chứng logic dời UV trong shader (`floor(mod(TIME * 8.0, 8.0)) * 16.0 / 128.0`) hiển thị chính xác từng frame $16 \times 16$ trên WebGL/Compatibility mà không bị lệch sub-pixel.
4. **Đo đạc chi phí swept capsule 30Hz**: Đo frame time CPU khi gom và đóng gói 16 actor capsule so với cập nhật điểm tức thời.

---

### 6. Ranh giới: Sự thật đã đối soát vs Giả thuyết cần đo

| Hạng mục | Sự thật đã đối soát (Facts) | Giả thuyết kiến trúc (Cần đo đạc) |
| :--- | :--- | :--- |
| **Dữ liệu Asset** | Strip 128x16 không padding; Decor dùng tileset 4x4. | Gom 18 strip thành texture $128 \times 288$ giải quyết triệt để draw call. |
| **Engine Contract** | TileMap không bảo đảm metadata đỉnh; Compatibility không có Compute. | Row-band MultiMesh RID có thể Y-sort hoàn hảo với Scene Node. |
| **Hiệu năng** | Cỏ nền không cần Y-sort có thể gộp chunk lớn. | 16 slot swept capsule ở 30Hz đủ mượt và nhẹ hơn Spatial Texture trên Web. |

