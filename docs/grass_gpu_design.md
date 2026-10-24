# Cỏ tương tác GPU — quyết định kiến trúc 24/10/2026

Kế hoạch thực hiện: [grass_gpu_implementation_plan.md](grass_gpu_implementation_plan.md).

Cập nhật triển khai: [G0 + G1](grass_gpu_g0_g1.md) đã có POC gió/atlas một node, kiểm tra native trên hai renderer. Phản ứng actor và tích hợp map vẫn thuộc các bước sau.

[G2](grass_gpu_g2.md) đã thêm chunk/index/cache và row RID sắp xếp cùng actor/AnimalPen; chưa có actor bending G3.

Cập nhật tiếp: [G3](grass_gpu_g3.md) đã triển khai actor bending/capsule 96 slot, kiểm chứng player + 86 AnimalActor và shader trên hai renderer. MainWorld vẫn chờ G4 tích hợp.

[G4](grass_gpu_g4.md) đã bật 10 cụm cỏ ở BarnPen, giữ ba overlap cùng props ở nguồn. Dùng texture gốc, shader lit và fallback về TileMap. Mở rộng và nghiệm thu thiết bị tiếp tục ở G5/G6.

## Kết quả trao đổi

Đã trao đổi ba vòng thật qua Antigravity CLI với model `gemini-3.8-flash-high`, effort `high`, chế độ `plan`, cùng một conversation. Phản hồi cuối xác nhận **AGREE**. Các vòng tranh luận nguyên văn được lưu trong [biên bản](grass_gpu_design_2026-10-24/). Giai đoạn trao đổi chỉ khảo sát và viết tài liệu; kết quả triển khai tiếp theo được ghi riêng ở báo cáo G0/G1.

Chốt kiến trúc để dựng POC: **một node quản lý cỏ; các lô cỏ GPU theo vùng/hàng được sở hữu qua RenderingServer; shader làm gió và phản ứng hình ảnh; CPU chỉ lấy vị trí actor và quản lý vùng đang hoạt động.** Hiệu năng tốt nhất chưa thể tuyên bố trước benchmark.

## Điều đã xác minh trong dự án

- Godot 4.7.x; desktop Forward+, Web export hiện dùng Compatibility. Không chọn compute shader làm nền tảng vì Compatibility không hỗ trợ.
- `shaders/plant_wind.gdshader` đã tạo gió trên GPU bằng vertex deformation, TIME, pha theo world position và UV được giữ nguyên. `VisualMotionComponent` riêng vẫn dùng CPU Tween cho phản ứng/focus/xuất hiện/biến mất của cây trồng. Cỏ không nên nhân bản component/Tween này cho từng bụi.
- MainWorld đã dùng TileMapLayer để batch nhiều thứ. Thêm tương tác GPU không có nghĩa trước đó mỗi bụi cỏ đang là một node riêng.
- `Decor` và `TinyDecor` dùng tileset chung với lưới logic 4×4 và nhiều loại trang trí (hoa, đá, đồ vật...). Không gắn shader biến dạng toàn bộ layer hoặc thảm Ground.
- Có 18 strip hoạt ảnh cỏ trong assets: mỗi ảnh 128×16, gồm 8 frame 16×16. TileSet cỏ riêng được tham chiếu trong `world/farm_landscape.tscn` (MeadowGrass). MainWorld không có tham chiếu trực tiếp tới scene landscape này trong lần khảo sát; POC phải xác định đúng scene/layer đang dùng, không tự gắn thêm toàn bộ landscape.
- Alpha audit: `Grass_1_Anim.png` và `Grass_2_Anim.png` có opaque bottom tại cạnh dòng 10 ở cả tám frame; `Flower_Grass_1_Anim.png` tại cạnh dòng 12. **Đáy ảnh 16px không phải chân nhìn thấy.** Cần bảo toàn cả texture origin, offset, flip và vị trí chân theo dữ liệu authoring.
- Root MainWorld và AnimalPen đã bật Y-sort; TinyDecor cũng bật Y-sort. Plugin Scatter2D chỉ sort transform bên trong MultiMesh, không tự đan xen instance với người/vật nuôi bên ngoài.

## Phân chia CPU/GPU

| Công việc | Nơi thực hiện |
| --- | --- |
| Vị trí, di chuyển và collision gameplay hiện có của người/vật nuôi | CPU, giữ cơ chế hiện tại |
| Gom vị trí chân/radius các actor có thể ảnh hưởng vùng nhìn thấy | Một manager CPU, chi phí theo số actor |
| Gió, độ nghiêng, khoảng cách tới footprint/capsule và hình ảnh bị đè | Vertex shader GPU |
| Chọn frame hoạt ảnh cỏ theo atlas/phase | Shader GPU |
| Chuẩn bị atlas, điểm đặt và instance buffer | Editor/bake hoặc khi nạp/chỉnh chunk; không làm lại mỗi frame |

Mục tiêu là không còn xử lý phản ứng theo từng bụi trên CPU. Không gọi đó là CPU bằng 0, và không gọi biến dạng hình ảnh là thay thế collision vật lý. Không cần GPU readback trong kiến trúc này.

## Renderer đã chốt

1. Một `GrassField`/`GrassManager : Node2D` sở hữu dữ liệu, tài nguyên và các canvas RID. Đây là một node **thêm vào**; không tạo node/Area2D/script/Tween riêng theo từng bụi.
2. Lấy các loại cỏ nằm trong allowlist từ dữ liệu authoring. Ground, đất trồng, đá, hoa không thuộc phạm vi và cây trồng giữ nguyên. Loại tile trộn nhiều hình trong cùng ảnh không tự chuyển đổi nếu chưa kiểm tra được cách tách đúng.
3. Dùng quad/MultiMesh với metadata do hệ thống kiểm soát: loại ảnh, frame/phase, kích thước, hướng/scale và chân thực. Gom artwork phù hợp thành atlas nhỏ dùng chung; 18 strip có thể xếp 8 cột × 18 hàng (128×288 trước phần đệm nếu cần). Không bắt buộc sử dụng cả 18 loại nếu chúng chưa có trong scene đang chuyển.
4. Cỏ thấp nền: batch theo chunk. Cỏ cao cần che chân: batch theo hàng/dải có **cùng Y chân thực** và cùng z-index phù hợp, đặt các canvas item vào cùng không gian Y-sort của actor. Sort instance trong một MultiMesh không đủ.
5. Ban đầu thử chunk 256 và 512 world-pixel, chưa chốt một kích thước là tối ưu. Bounding rect phải tính toàn bộ hình ảnh cộng biên dịch chuyển shader. Quản lý cả culling và bộ nhớ cư trú; thế giới ngoài màn hình không được kéo chi phí vertex theo toàn bộ diện tích thế giới.
6. Buffer instance tĩnh được build/upload khi chunk thay đổi; không chạy vòng lặp biến đổi từng bụi mỗi frame. Một material/atlas dùng chung khi tương thích, tránh nhân material theo bụi.
7. Canvas RID tự tạo được giải phóng bởi owner; Mesh/MultiMesh/Texture Resource giữ đúng ownership, không free RID thuộc Resource hai lần. Owner phải xử lý hide/disable, đổi scene và reload vì các RID để Y-sort có thể được parent trực tiếp vào World chứ không dưới manager.

**Một node không đồng nghĩa một draw call, một RID, một buffer hoặc không tốn VRAM.** Các chi phí này phải được đếm trong báo cáo.

## Neo chân và shader

- Không copy giả định `MODEL_MATRIX` là gốc từng sprite sang TileMap gộp. Không đoán tile ID/pivot bằng `VERTEX_ID % 4`, modulo lưới hoặc giả định TileData custom_data tự xuất hiện trong shader.
- Quad mới có tọa độ/metadata rõ ràng; đặt origin tại chân thực và giữ UV frame hợp lệ. Chân ở dòng 10/12 phải được xử lý, không chỉ neo dòng 16.
- Nếu quad vẫn chứa đệm trong suốt dưới chân, shear phải giữ nội suy bằng 0 **tại chân opaque**. Chỉ clamp trọng số hai đỉnh đáy rồi gọi đó là neo chân có thể làm gốc opaque tiếp tục dịch chuyển. Có thể dùng shear tuyến tính qua cả phần trong suốt hoặc hình học đã cắt theo bounds, sau khi kiểm tra đủ tám frame.
- Mã nguồn Godot 4.7 của cả RD và GLES3 nhân transform instance vào model matrix trước user vertex code. Có cơ sở để lấy world root của từng instance bằng matrix; vẫn cần POC kiểm tra offset hàng, parent transform, flip/scale và camera để tránh áp transform hai lần.
- Gió chia sẻ hướng/cường độ từ thời tiết; pha theo chân thế giới và phase instance. So sánh hoạt ảnh tám frame kết hợp shear với phiên bản chỉ shear để tránh cộng hai hiệu ứng quá mạnh. Audit pause/time scale và TIME rollover.
- Biến dạng chỉ làm hình ảnh: không đẩy người/vật nuôi, không tạo collider cỏ.

## Actor: đầy đủ trước, đo tối ưu sau

Thông số chuồng hiện tại: 30 + 36 + 20 = **86 vật nuôi**, cộng player = **87 actor**. Một số phản hồi của Antigravity ghi nhầm thành 87 vật nuôi cộng player; số đúng của hợp đồng là 87 tổng cộng.

Baseline POC dùng `MAX_INTERACTORS = 96`, không âm thầm chọn 16 rồi bỏ các con còn lại. Payload có thể gồm hai vec4 mỗi actor (vị trí/radius/lực và vị trí trước/velocity), khoảng 3 KiB cho 96 slot trước overhead; phải kiểm tra giới hạn uniform thực trên các renderer/thiết bị. Shader dùng vòng lặp có giới hạn và dừng ở `active_count`, không bắt buộc thử đủ 96 cho mọi đỉnh.

CPU lọc bằng vùng camera cộng radius/biên chuyển động, dùng điểm chân trong cùng hệ tọa độ với cỏ. Player luôn được giữ, actor đứng yên vẫn phải tác động cỏ; đứng yên không có nghĩa không tốn GPU. Theo dõi enter/exit, teleport, sinh/chết và identity để tránh popping. Nếu thêm actor vượt ngân sách đã kiểm chứng, phải mở rộng/đổi backend, không lờ đi.

So sánh upload 60Hz và 30Hz. Khi giảm nhịp, footprint dạng swept capsule giữa vị trí trước/hiện tại và nội suy/ước lượng có giới hạn giúp không bỏ sót đường đi nhanh; phải đo cả latency cảm nhận. Không giả định 30Hz luôn tốt hơn.

Baseline là uốn giải tích với falloff trơn, tổng lực được clamp. Nó có thể hồi về êm theo khoảng cách, nhưng không có bộ nhớ lò xo vật lý riêng cho từng bụi. Nếu cần vệt cỏ hồi chậm, thử số hữu hạn dấu tương tác có timestamp; spring field/ping-pong là giai đoạn tùy chọn, không bắt buộc ngay.

## Khi nào dùng texture field

Giữ texture field như backend thay thế khi benchmark cho thấy tốt hơn uniform ở mật độ thực. Nó có chi phí clear/stamp/render target/update và texture fetch, không miễn phí hoặc vô hạn actor.

Field định hướng cần định nghĩa encoding đa kênh và định dạng hỗ trợ thật trên Compatibility/Web. R8 chỉ là một scalar mask, không trực tiếp chứa vector uốn hai chiều. Có thể dùng render-to-texture qua RenderingServer mà không thêm scene nodes, nhưng vẫn có render resources/passes. Không dùng compute shader hoặc GPU readback làm điều kiện bắt buộc cho Web.

Không có kết luận trước đo rằng 16 actor luôn thắng RTT, 50 actor là điểm crossover, hoặc 60 draw calls là ngưỡng hỏng.

## Gate POC và benchmark

1. Đúng ≤1 scene node thêm vào; không có script/Tween/physics per-blade; không GPU readback.
2. POC 100–500 bụi, người và vài vật nuôi: chân đứng yên khi ngọn uốn, đúng đủ frame, không lem atlas, ground/rocks không rung; camera zoom lẻ và transform vẫn đúng.
3. Cỏ cao/actor đan xen đúng cả bốn hướng, row offsets và z-index; kiểm tra cả nhóm pen trong World. Không để một MultiMesh toàn bản đồ làm mất culling/Y-sort.
4. Thử đủ 87 actor, đứng yên và chạy nhanh, không mất slot. Các trường hợp sinh/chết/teleport/out-of-view không gây giật.
5. So sánh static baseline, wind-only và wind+interaction ở 1k/10k/50k bụi **nhìn thấy**, 1/8/16/32/64/87 actor; zoom ra/vào; tăng thế giới ngoài màn hình để phát hiện chi phí không được cull.
6. Đo CPU manager/upload, render CPU, GPU frame time nếu công cụ hỗ trợ, frame-time p95/p99, draw calls, vertices, VRAM, allocations/RID lifetime. Không dùng FPS trung bình làm kết luận duy nhất; ghi rõ nếu browser không có GPU timer đáng tin cậy.
7. Ngân sách dựa trên mục tiêu sản phẩm 60fps (16,67ms) hoặc 30fps (33,33ms), thiết bị và phần thời gian còn lại của scene. Chưa chốt ngân sách chi tiết hoặc công bố số đo giả.
8. Desktop Forward+ và Compatibility, Web build, rồi Android/iPhone thật trong phạm vi hỗ trợ; chạy đủ lâu để phát hiện nhiệt, tụt xung và điện năng. Reload nhiều lần không tăng RID/VRAM. Không gọi desktop giả lập kích thước điện thoại là đã nghiệm thu thiết bị thật.

Chỉ sau các gate này mới chốt chunk size, nhịp upload, chất lượng và backend tương tác cuối. Hiện chưa triển khai POC và chưa có benchmark mới.

## Những điểm thay đổi qua phản biện

- Vòng 1 đề nghị TileMap + uniform 16 và đưa ra vài kết luận tuyệt đối về mobile/RTT. Codex bác bỏ vì thiếu metadata pivot, vi phạm số node và không có số đo.
- Vòng 2 chuyển sang một owner + chunk/row RID; rút yêu cầu padding mặc định và ngưỡng draw call tùy tiện. Codex tiếp tục bác bỏ việc bỏ actor, suy đoán crossover và R8 cho vector.
- Vòng 3 đồng ý baseline đủ actor, phân biệt dữ kiện/giả thuyết, ownership tài nguyên, yêu cầu benchmark và điều kiện chuyển field. Codex bổ sung kết quả alpha audit, scene-reference audit và sửa phép cộng actor trong tài liệu chốt.

## Nguồn kiểm chứng

- [Godot 4.7 CanvasItem shaders](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/canvas_item_shader.html): vertex space, MODEL_MATRIX, INSTANCE_CUSTOM và custom attributes.
- [MultiMesh và culling](https://docs.godotengine.org/en/4.7/tutorials/performance/using_multimesh.html): không cull từng instance, có thể chia nhiều vùng.
- [TileMapLayer](https://docs.godotengine.org/en/4.7/classes/class_tilemaplayer.html): batching và cách nhóm theo Y thay cho quadrant khi Y-sort.
- [RenderingServer](https://docs.godotengine.org/en/4.7/classes/class_renderingserver.html): canvas RID parenting, Y-sort, ownership và giới hạn lợi ích của bỏ Node.
- [Compute shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/compute_shaders.html): yêu cầu renderer RenderingDevice, không làm nền tảng cho Compatibility.
- [Canvas shader RD 4.7](https://github.com/godotengine/godot/blob/4.7/servers/rendering/renderer_rd/shaders/canvas.glsl) và [GLES3 4.7](https://github.com/godotengine/godot/blob/4.7/drivers/gles3/shaders/canvas.glsl): transform instance trước user vertex code.
