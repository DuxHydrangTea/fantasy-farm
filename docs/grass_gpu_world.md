# Cỏ GPU trên toàn map

**Đã mở rộng tiếp:** [80 mẫu cỏ/hoa/bụi/nấm, 815 cụm trên map](foliage_gpu.md). Có cả hoa 16×32 và 32×32. Bốn loại và số liệu bên dưới là bản bàn giao trước khi mở rộng palette.

Ngày 25/10/2026. Thay thế giới hạn vùng thử của [G4](grass_gpu_g4.md). `MainWorld` mặc định bật hiệu ứng cho **toàn bộ 169 cụm cỏ hiện có trong TinyDecor**, không còn `grass_trial_region`.

## Tự vẽ thêm cỏ

1. Mở `world/main_world.tscn`, chọn TileMapLayer **TinyDecor**.
2. Chọn texture `assets/Outdoor decoration/Outdoor_Decor.png` trong palette.
3. Vẽ bằng các tile cỏ tại atlas coords **(6,2), (6,3), (7,3), (8,3)**.
4. Lưu scene rồi chạy lại. Hệ thống tự nhận cả những ô nằm ngoài giới hạn map cũ; không cần thêm node, collider, hay chỉnh vùng cho từng cụm.

Đây là cỏ đi xuyên qua được, nghiêng khi player/vật nuôi đến gần và lay theo thời tiết. Không thêm vật cản đường. Trong editor vẫn là các tile gốc. F10 trong debug tắt/bật toàn hiệu ứng; `gpu_grass_enabled` ở World là công tắc tổng. Scene `tests/support/grass_gpu_farm_preview.tscn` cho thử bằng F6 mà không bind save cá nhân.

## Toàn bộ cỏ đều phản ứng

- **138 cụm** dùng renderer chunk hiện có, culling theo camera và ngân sách cache.
- **31 cụm** chồng hoa/đồ trang trí cùng hàng Y-sort dùng vertex shader trực tiếp trên tile, giữ nguyên thứ tự vẽ của TileMap. Không còn để các cụm này đứng yên như bản vùng thử.
- Cả hai đường render dùng chung công thức gió, lực nghiêng, dữ liệu player/vật nuôi và ánh sáng. Tính biến dạng nằm trên GPU. Vẫn chỉ thêm **một node GPUGrass**, không thêm node/physics/process cho từng cụm.
- Nhóm TileMap dùng bốn ShaderMaterial dùng chung cho bốn loại cỏ; adapter đồng bộ uniform tới bốn material, không duyệt từng cụm mỗi frame. Đây là chi phí CPU cố định bên cạnh feed actor hiện có, không phải toàn bộ gameplay chạy trên GPU.

`GrassSourceTransfer.prepare` mặc định quét cả layer; tham số region chỉ còn phục vụ các phép kiểm tra nhỏ. Guard overlap tiếp tục phân loại thứ tự vẽ, không giới hạn phạm vi hiệu ứng.

`GrassTileMaterials` duplicate TileSet cục bộ cho World đang chạy, gắn material đúng bốn tile cỏ. Không sửa asset TileSet dùng chung hoặc file scene. Tắt hiệu ứng, fallback và exit trả lại TileSet gốc cùng toàn bộ source cells. Thiếu atlas/shader, vượt cache/actor capacity hoặc headless vẫn giữ nguồn gốc.

## Kiểm chứng

- **33/33 GUT, 451 assertions**: hồi quy cỏ G1–G4, quét toàn map, vẽ thêm ô rất xa vùng cũ rồi tự nhận, suppress/restore, TileSet clone không thay material nguồn và restore lặp an toàn.
- **60/60 native checks mỗi renderer** Compatibility/Forward+: tổng 169 cụm; 138 chunk + 31 shader tile; đối chiếu ảnh nguồn ngày/đêm, zoom 0,8/1,25, bốn vị trí camera trên map; fallback, save/restore và đàn 86 con thật.
- Kiểm tra riêng 31 cụm: ẩn toàn bộ chunk grass, xác nhận ảnh thay đổi khi bật gió và khi chỉ có lực actor. Không lấy chuyển động của nhóm chunk làm bằng chứng thay cho nhóm tile.
- Hồi quy shader G1: 189 checks mỗi renderer. Lint toàn project sạch; engine validation và Web export đạt. Chưa kiểm thử runtime trên browser/điện thoại trong đợt này; chưa tuyên bố ngân sách hiệu năng mobile.

Ảnh, log và số đo thô: [bằng chứng toàn map](grass_gpu_world_2026-10-25/). G5 benchmark dài vẫn là việc tiếp theo để tối ưu cấu hình, không còn là điều kiện bật cỏ toàn map.
