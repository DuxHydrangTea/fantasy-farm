# Kế hoạch triển khai cỏ tương tác GPU

Ngày: 24/10/2026 · Trạng thái: đã triển khai G0–G4 trong phạm vi desktop/vùng thử; G5 đo và chốt cấu hình thiết bị tiếp theo.

Bàn giao đợt đầu: [kết quả G0 + G1](grass_gpu_g0_g1.md). Chưa bật cỏ GPU vào MainWorld và chưa có phản ứng player/vật nuôi.

Bàn giao G2: [chunk, Y-sort và lifecycle](grass_gpu_g2.md). Đạt 74 native checks mỗi renderer, 14 unit tests; mặc định thử desktop 512, vẫn có 256. Chưa nghiệm thu browser/điện thoại.

Bàn giao G3: [player/vật nuôi làm cỏ nghiêng](grass_gpu_g3.md). Registry và GPU capsule/footprint, 48 checks mỗi renderer, 23 unit tests gồm hồi quy; adapter player + 86 AnimalActor thật đã kiểm chứng. Chưa bật vào map chính.

Bàn giao hiện tại: [80 mẫu cỏ/hoa/bụi/nấm GPU, 25/10](foliage_gpu.md), gồm hoa 16×32/32×32. Toàn bộ 815 cụm được hỗ trợ trong TinyDecor có hiệu ứng (138 chunk, 677 shader tile); vẽ thêm tự nhận khi chạy lại. Native QA 224 checks/bên, 34 GUT hồi quy; chưa nghiệm thu browser/điện thoại. [Báo cáo G4 vùng thử cũ](grass_gpu_g4.md).

Căn cứ: [quyết định kiến trúc](grass_gpu_design.md) và [ba vòng trao đổi với Antigravity](grass_gpu_design_2026-10-24/). Model đã dùng: Gemini 3.8 Flash (High).

## 1. Mục tiêu và phạm vi

Cỏ trang trí lung lay theo gió và phản ứng khi player/vật nuôi đi qua, hoạt động trên desktop Forward+ và Web Compatibility. Thiết kế hướng tới điện thoại, nhưng chỉ nghiệm thu thiết bị thật sau khi có số đo.

- Thêm tối đa **một node quản lý** so với scene gốc; không tạo node, Area2D, collider, script hay Tween theo từng bụi.
- Shader tính biến dạng và hoạt ảnh; CPU gom tọa độ actor, quản lý chunk và upload dữ liệu dùng chung.
- Renderer chia cỏ theo vùng; cỏ cần che chân actor có batch theo hàng trong cùng không gian Y-sort.
- Baseline đủ 86 vật nuôi + player = 87 actor. Mảng tối đa 96 là cấu hình để thử nghiệm, không phải cam kết nhanh trên mọi GPU.
- Chỉ thay thế cỏ được nhận diện rõ trong allowlist. Không làm rung đất nền, đá, đồ trang trí khác hoặc thay cơ chế cây trồng hiện có.
- Không thêm luật gameplay, đẩy actor bằng cỏ, mô phỏng va chạm vật lý GPU, cắt cỏ, vệt lún vĩnh viễn hoặc thay đổi save trong phạm vi này.

## 2. Các quyết định đã chốt và phần còn phải đo

| Đã chốt | Chưa chốt trước số đo |
| --- | --- |
| Một manager, shader và dữ liệu dùng chung | Chunk 256 hay 512 world-pixel, kích thước cache |
| Hình học/metadata chân cỏ do hệ thống kiểm soát | Upload actor 30Hz hay 60Hz |
| Không biến dạng TileMap hỗn hợp bằng suy đoán pivot | Mật độ cỏ và mức chất lượng cuối trên từng thiết bị |
| Không âm thầm bỏ actor hợp lệ để giữ 16 slot | Uniform có đủ nhanh hay cần texture field |
| Không phụ thuộc compute shader hoặc GPU readback | Có cần vệt phản ứng có bộ nhớ sau POC hay không |
| Kiểm tra Forward+ và Compatibility | FPS/ngân sách hiệu ứng chính thức trên điện thoại mục tiêu |

Mục tiêu sản phẩm tham chiếu là 60fps/16,67ms hoặc 30fps/33,33ms. G0 phải ghi mục tiêu cho từng nhóm thiết bị và ngân sách CPU/GPU/bộ nhớ còn lại sau baseline; không dùng một con số draw-call tùy ý làm ngưỡng nghiệm thu.

## 3. G0 — Khảo sát đúng nguồn cỏ và ghi baseline

**Công việc**

1. Xác định scene/layer thật sự cần áp dụng. MainWorld hiện không tham chiếu trực tiếp FarmLandscape; không tự gắn toàn bộ scene landscape vào game.
2. Lập manifest từng loại cỏ: texture/atlas rect, kích thước ảnh và tile logic, số frame/FPS, texture origin, chân hình ảnh, flip/scale, z-index và nhu cầu che chân actor.
3. Phân loại cỏ thấp, cỏ cao và tile không thể tách an toàn khỏi đất/đồ vật. Giữ nguyên các tile chưa được nhận diện.
4. Đo scene hiện tại: số node, grass instances/cells, draw calls, frame time, bộ nhớ; ghi engine/build/renderer/độ phân giải/GPU/thiết bị.
5. Chốt camera path, mật độ và số actor chuẩn cho các phép A/B. Ghi thiết bị điện thoại cần thử, những thiết bị hiện chưa có và mục tiêu 30/60fps tương ứng.

**Bàn giao:** manifest nguồn cỏ, ảnh đánh dấu chân, danh sách layer được chuyển, baseline và bảng ngân sách theo thiết bị.

**Đạt khi:** biết chính xác loại cỏ sẽ thay, vị trí chân, cách lấy dữ liệu mà không đụng Ground/soil/đá; fixture đo có thể lặp lại. Chưa bật hệ thống vào map chính.

## 4. G1 — POC hình học, gió và atlas trong scene riêng

**Quy mô:** 100–500 bụi; một manager, dữ liệu thử, actor giả lập để kiểm tra tọa độ. Những actor trong fixture không được tính thành node của tính năng cỏ.

**Công việc**

- Tạo renderer thử với quad/MultiMesh và metadata rõ ràng, một atlas/material dùng chung khi phù hợp.
- Hiển thị cỏ tĩnh trước, đối chiếu vị trí/kích thước với bản authoring. Sau đó thêm shader gió và hoạt ảnh frame trên GPU.
- Neo theo chân thật: ảnh cỏ đã audit có opaque bottom tại dòng 10/12/15 trong ảnh 16px. Xử lý phần trong suốt dưới chân; không clamp hai đỉnh đáy theo cách làm chân opaque trượt.
- Thử đủ frame, chân/texture origin, flip và scale; thử camera zoom nguyên/lẻ và parent transform. Kiểm tra coordinate transform trên cả renderer, tránh nhân world transform hai lần.
- So sánh tám frame hoạt ảnh kết hợp shear với cách chỉ shear để chọn độ rung không quá mạnh. Kiểm tra pause, time scale và TIME rollover.

**Bàn giao:** scene POC, shader, dữ liệu atlas/pivot, ảnh trước/sau và kết quả kiểm tra Forward+/Compatibility.

**Đạt khi:** hình đứng yên khớp nguồn; chỉ ngọn uốn, chân không trượt; không lem frame, không rách hình, không rung đất nền. Nếu không chứng minh được hợp đồng hình học, sửa POC trước khi chuyển bước.

## 5. G2 — Chia vùng, xếp lớp và vòng đời tài nguyên

**Công việc**

- Chia dữ liệu thành chunk; thử 256/512 world-pixel như hai ứng viên ban đầu.
- Cỏ thấp batch nền theo vùng. Cỏ cao batch theo cùng Y chân thực và z-index, parent canvas item vào đúng nhóm Y-sort của World/actor, kể cả actor dưới AnimalPen.
- Kiểm tra actor đi trước/sau và đi ngang các hàng. Sort instance bên trong MultiMesh không được coi là đã chứng minh Y-sort với actor bên ngoài.
- Mở rộng bounds bằng toàn bộ hình ảnh và dịch chuyển shader tối đa; kiểm tra rìa màn hình, zoom và biên chunk.
- Xây/upload instance buffer khi nạp hoặc đổi chunk; không quét mọi ô cỏ hay cập nhật transform từng bụi mỗi frame.
- Quản lý vùng đang nhìn thấy và vùng dự phòng bằng chỉ mục chunk. Có giới hạn cache/bộ nhớ GPU; không biến việc culling thành vòng lặp qua toàn bộ thế giới mỗi frame.
- Xử lý hide/disable/reload. Free canvas RID tự tạo đúng một lần; giữ đúng ownership của Mesh/MultiMesh/Texture Resource.

**Bàn giao:** renderer chunk/row, báo cáo node/RID/buffer/draw calls và kiểm tra vòng đời.

**Đạt khi:** thêm đúng tối đa một scene node; xếp lớp đúng; không biến mất sớm ở mép nhìn; tăng phần bản đồ ngoài màn hình không làm tăng tương ứng tải vẽ; reload không tăng tài nguyên vô hạn. Phân biệt cache khởi động hợp lệ với rò rỉ tăng tuyến tính.

## 6. G3 — Player và vật nuôi làm cỏ nghiêng

**Công việc**

1. Manager lấy điểm chân/radius từ actor hiện có. Duy trì registry/cache theo spawn, chết, bán và rời cây scene; không thêm component riêng vào mỗi con chỉ để xử lý cỏ.
2. Lọc bằng vùng camera mở rộng theo bán kính/biên chuyển động. Giữ đầy đủ actor còn ảnh hưởng cỏ, kể cả đứng yên; danh sách ổn định và có xử lý vào/ra biên.
3. Baseline tối đa 96 interactor; kiểm tra limit và biên dịch thật trên Compatibility. Nếu số lượng vượt khả năng đã kiểm chứng phải báo và chọn phương án hỗ trợ, không cắt danh sách âm thầm.
4. Shader tính gió cộng ảnh hưởng footprint/capsule, giữ nguyên chân và giới hạn tổng lực. Tránh normalize vector 0, NaN và độ nghiêng vượt bounds.
5. Thử vị trí trước/hiện tại để không bỏ sót quãng chạy nhanh. So sánh 30/60Hz bằng số đo và độ trễ hình ảnh; thống nhất hệ thời gian gửi lên GPU, không trộn timestamp không cùng gốc.
6. Xử lý actor đứng yên, quay hướng, teleport, sinh/chết, player đổi scene và nhiều con chồng lên nhau. Teleport không tạo một vệt capsule dài xuyên bản đồ.
7. Dùng falloff trơn cho hồi phục. Chỉ thêm dấu tương tác có timestamp nếu hình ảnh thực sự cần; chưa làm spring simulation/ping-pong field.

**Bàn giao:** tương tác player/animals trong fixture, bộ đếm eligible/uploaded actor và kiểm tra đường đi.

**Đạt khi:** đủ 87 actor được xét khi thuộc vùng tác động; không rớt slot/popping, không xuyên bỏ sót ở tốc độ chạy kiểm thử, actor đứng yên vẫn tạo áp lực. Không có distance loop/Tween/physics theo từng bụi trên CPU và không GPU readback.

## 7. G4 — Tích hợp thử một vùng nông trại

**Công việc**

- Đưa hệ thống vào đúng một vùng cỏ đã xác định ở G0. Giữ TileMap làm dữ liệu authoring để vẫn chỉnh map được.
- Chuyển đúng các ô trong allowlist sau khi renderer chuẩn bị thành công. Tránh vừa vẽ nguồn cũ vừa vẽ instance mới; không ẩn cả layer có chứa đá/hoa/đồ vật.
- Có công tắc bật/tắt/khôi phục hiển thị nguồn cũ. Nếu renderer không khả dụng, hiển thị cỏ gốc thay vì để hở map hoặc làm game lỗi.
- Nối hướng/cường độ gió với thời tiết hiện có, dùng tham số chung. Kiểm tra ánh sáng/ngày đêm, pause và các menu khi chơi.
- Thử player và đàn thật. Đo cả fixture chuyển động cố định để tách tải renderer lẫn gameplay chạy AI đầy đủ.
- Kiểm tra save/load và reload scene; dữ liệu cỏ trang trí không bị đưa thành dữ liệu kinh tế hoặc làm thay đổi tiến trình.
- Mọi QA chạy bằng scene/hồ sơ cách ly. Không dùng save cá nhân làm fixture.

**Bàn giao:** một vùng tích hợp có toggle, video/ảnh đối chiếu, xác nhận restore nguồn gốc và hồi quy gameplay.

**Đạt khi:** bản đồ không mất/nhân đôi decor; thời tiết và tương tác đúng; cây trồng, collision và save hiện có vẫn hoạt động; bật/tắt không để lại RID hay state mồ côi.

## 8. G5 — Benchmark và chốt cấu hình hiệu năng

**Ma trận**

| Trục | Các mức |
| --- | --- |
| Cỏ nhìn thấy | 1k / 10k / 50k bụi |
| Actor đồng thời | 1 / 8 / 16 / 32 / 64 / 87 |
| Hiệu ứng | Cỏ tĩnh / chỉ gió / gió + tương tác |
| Upload actor | 30Hz / 60Hz |
| Chunk | 256 / 512 world-pixel, rồi điều chỉnh nếu cần |
| Renderer | Forward+ desktop / Compatibility desktop / Web |
| Thế giới ngoài màn hình | Nhỏ / tăng mạnh trong khi vùng nhìn thấy giữ nguyên |

**Phương pháp**

- Cùng seed, camera path, actor trajectory và độ phân giải cho A/B. Warm-up shader/cache rồi đo release export, tránh lấy frame khởi động làm kết quả steady-state.
- Ghi CPU manager/upload, render CPU, GPU time khi công cụ hỗ trợ, p95/p99 frame time, draw calls, vertices, VRAM và phân bổ bộ nhớ. Ghi rõ phép đo không khả dụng; không suy GPU time từ CPU time/FPS.
- Đo thêm cold load, chuyển chunk, pan/zoom nhanh và teleport camera để bắt spike do build/upload buffer.
- Chạy điện thoại thật đủ lâu để quan sát nhiệt và tụt xung. Ghi model máy, OS, trình duyệt và thời lượng. Không gọi resize desktop là nghiệm thu mobile.
- Các mức 50k/87 là stress test để tìm giới hạn, không là cam kết mọi máy đều đạt target ở mức này. Profile phát hành phải nói rõ phạm vi hỗ trợ.

**Nhánh quyết định**

- Uniform đạt ngân sách G0 ở cấu hình phát hành: giữ baseline, chốt chunk/nhịp upload/mật độ.
- Uniform không đạt: xác định nút thắt CPU, vertex ALU, fill-rate, draw calls hay bộ nhớ trước khi đổi kiến trúc.
- Chỉ làm POC texture field nếu có lý do từ số đo. Field vector phải có encoding đa kênh và render-target format hỗ trợ thật; R8 đơn lẻ không trực tiếp lưu vector. Đo cả chi phí render pass và stamp actor, giữ ràng buộc số node qua RenderingServer nếu dùng nhánh này.
- Có thể giảm mật độ cỏ, chi tiết hoặc tần số trên profile nhẹ. Không tự giảm số actor hợp lệ để làm số đo đẹp. Không mặc định triển khai cả hai backend vào bản phát hành.

**Bàn giao:** báo cáo số đo thô/tóm tắt, cấu hình được chọn, phạm vi thiết bị đạt/chưa đạt và lý do chọn backend.

**Đạt khi:** profile phát hành đạt ngân sách đã ghi; artifact và quy trình đo lặp lại được; không có tuyên bố FPS trên máy chưa thử.

## 9. G6 — Hồi quy, mở rộng phạm vi và bàn giao

- Mở rộng dần sang các vùng cỏ đã audit sau khi G5 đạt. Tile không hỗ trợ vẫn hiển thị theo nguồn cũ.
- Chạy kiểm tra hình ảnh/neo chân/atlas/Y-sort, danh sách actor, culling, resource lifetime, interaction, thời tiết, save/load và export tương ứng phạm vi thay đổi.
- Lint và engine validation shader; native render kiểm tra pixel/ảnh. Test logic cho chunk mapping, packing/completeness và ownership phải kiểm tra invariant thực, không chỉ lặp lại phép gán của implementation.
- Soak test di chuyển liên tục, tụ đàn, pause/resume, đổi cảnh và reload nhiều lần. Kiểm tra tính năng tắt và fallback.
- Xuất Web/desktop từ mã cuối; ghi riêng tình trạng Android/iPhone thật. Cập nhật tài liệu dùng cỏ, cấu hình, giới hạn và đường dẫn bằng chứng.

**Đạt khi:** không còn lỗi làm mất decor, sai xếp lớp, rò tài nguyên hoặc ảnh hưởng gameplay; build tải được; giới hạn còn lại được ghi rõ.

## 10. Cấu trúc mã dự kiến

Tên là dự kiến, phải đối chiếu convention dự án trước khi tạo:

| Thành phần | Vai trò |
| --- | --- |
| `components/grass/grass_field.gd` | Một Node2D quản lý, lifecycle và tích hợp World |
| `components/grass/grass_source_catalog.gd` | Resource mô tả artwork, frame, pivot và allowlist |
| `components/grass/grass_chunk_builder.gd` | RefCounted xây dữ liệu chunk/row và metadata |
| `components/grass/grass_renderer.gd` | RefCounted sở hữu canvas RID và resource render |
| `components/grass/grass_interaction_feed.gd` | RefCounted quản lý actor, culling và upload chung |
| `shaders/grass_field.gdshader` | Gió, atlas animation và tương tác trên GPU |
| Scene/test/benchmark trong `tests/` | Fixture độc lập với save cá nhân |
| Asset/manifest sinh ra và bằng chứng trong thư mục riêng | Có nguồn gốc, tái tạo được, không ghi đè ảnh gốc |

Chỉ manager là node mới. Tách module dữ liệu/renderer/feed để tránh dồn mọi trách nhiệm vào một script lớn; ràng buộc một node không buộc phải có một file duy nhất.

## 11. Tiến độ và thứ tự thực hiện

| Giai đoạn | Phụ thuộc | Trạng thái |
| --- | --- | --- |
| G0 — Audit + baseline | Thiết kế đã chốt | Đã có manifest và baseline desktop; allowlist map cuối và ngân sách điện thoại còn mở |
| G1 — POC pivot/atlas/gió | G0 | Đạt gate hình học hai renderer: 189 checks/bên, 4/4 unit tests; xem báo cáo G0/G1 |
| G2 — Chunk/Y-sort/lifecycle | G1 đạt | Đã triển khai trong scene thử; hai renderer đạt, cache ba giới hạn và benchmark 4.096/65.536 bụi |
| G3 — Player/animals | G2 đạt | Đạt fixture hai renderer, đủ 87/96 slots; upload 60Hz mặc định, có 30Hz; xem báo cáo G3 |
| G4 — Tích hợp map thật | G3 đạt | Đã mở toàn map và 80 mẫu cỏ/hoa/bụi/nấm: 815 cụm, 138 chunk + 677 shader tile; hoa nhiều tile giữ đúng kích thước; weather/light, F10/fallback, save/load và AI thật; xem verification cuối trong báo cáo foliage |
| G5 — Benchmark/chốt backend | G4, thiết bị đo | Chưa bắt đầu |
| G6 — Hồi quy/export/mở rộng | G5 đạt cho profile tương ứng | Chưa bắt đầu |

**Đợt triển khai đầu tiên:** G0 + G1. Bàn giao một scene thử có 100–500 bụi, baseline/manifest và bằng chứng neo chân/gió/atlas chạy trên hai renderer. Sau khi gate hình học đạt mới triển khai chunk/Y-sort và actor đầy đủ. Không mở rộng toàn map ngay trong POC.
