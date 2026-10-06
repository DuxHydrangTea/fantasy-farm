# Resource Weather Effects

Nguồn: `res://assets/Weather effects`, gồm 4 PNG.
Vùng chọn được xác định trước: Clouds chia thành 4 canvas 64 × 64,
Rain_Drop là một ảnh 16 × 16, hai sheet animation dùng frame 16 × 16.
Giữ khoảng trong suốt quanh hình để các frame không nhảy vị trí.

| Resource | Loại | Vùng / animation |
|---|---|---|
| `res://weather/clouds/cloud_01.tres` … `cloud_04.tres` | AtlasTexture | 64 × 64; trên trái, trên phải, dưới trái, dưới phải |
| `res://weather/rain_drop.tres` | AtlasTexture | 16 × 16 |
| `res://sprite_frames/weather/rain_drop_impact_frames.tres` | SpriteFrames | `impact`: 7 frame, 12 FPS, chạy một lần |
| `res://sprite_frames/weather/wind_frames.tres` | SpriteFrames | `gust`: 14 frame, 12 FPS, chạy một lần |

Clouds.png chứa các bóng mây tối bán trong suốt, là 4 mẫu riêng để di chuyển
trên map. Dùng AtlasTexture cho `Sprite2D.texture` hoặc texture của particle.
Rain_Drop là ảnh giọt mưa tĩnh, có thể dùng làm texture cho particle mưa.

Gán SpriteFrames vào `AnimatedSprite2D.sprite_frames`, rồi phát `impact` hoặc `gust`.
Chuỗi `impact` có cả giọt đang rơi ở 3 frame đầu và gợn nước ở 4 frame sau;
không cắt bỏ phần đầu sheet. Gió tạo thành vệt cong rồi tan dần.
Sau `animation_finished`, bộ phát hiệu ứng có thể ẩn hoặc xoá node;
chủ động phát các lần mới để tạo mưa/gió liên tục. Tần suất phát, di chuyển mây
và phân bố particle được điều khiển trong scene/gameplay.

Tất cả resource tham chiếu PNG gốc, AtlasTexture bật `filter_clip`.

## Tạo lại

```sh
godot --headless --path . --script res://scripts/setup/setup_weather_resources.gd
```

Generator kiểm tra danh sách 4 PNG, kích thước sheet và vùng cắt trước khi lưu
5 AtlasTexture cùng 2 SpriteFrames.
