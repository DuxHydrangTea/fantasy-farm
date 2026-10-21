# Component chuyển động hình ảnh

`VisualMotionComponent` nằm ở [components/visual_motion_component.gd](../components/visual_motion_component.gd).
Component dùng được với `Sprite2D`, `AnimatedSprite2D` hoặc một `Node2D` chứa phần hình.
Nó chỉ điều khiển transform/material/alpha của visual được gán; không sở hữu tuổi cây,
inventory, AI, va chạm hay vòng đời của đối tượng gameplay.

## Gắn cho cây hoặc con vật khác

1. Thêm một Node con, gắn script có class_name `VisualMotionComponent`.
2. Assign `target` tới sprite hoặc node chứa hình ảnh. Chọn visual riêng, không chọn physics body.
3. Chỉnh `pivot` trong hệ tọa độ của parent của target. Ví dụ sprite ở `(0,-16)`
   và chân nằm tại origin của parent thì dùng `Vector2.ZERO`.
4. Chỉnh góc/thời gian phản ứng và scale xuất hiện/biến mất trong Inspector.
5. Nếu cần gió, assign `wind_material`. Để trống cho con vật chỉ cần phản ứng rung.
6. Trong script chủ, export một tham chiếu `VisualMotionComponent` và assign bằng Inspector,
   rồi gọi các API dưới đây khi có sự kiện tương tác.

Component không tự quét khoảng cách, nhận hover hay đổi animation của AnimatedSprite2D.
Script gameplay quyết định lúc nào focus, bị tác động hoặc biến mất.
Nếu sprite khác đang được code khác thay transform trực tiếp, nên thêm một visual wrapper
và gán target vào wrapper để mỗi phần sở hữu một transform riêng.

## Cấu hình

| Property | Mặc định | Ý nghĩa |
|---|---|---|
| `target` | Chưa gán | Visual Node2D cần tác động; hỗ trợ Sprite2D và AnimatedSprite2D. |
| `pivot` | `(0,0)` | Điểm neo trong không gian parent của visual. |
| `wind_material` | `null` | ShaderMaterial tùy chọn; dùng chung resource nếu muốn nhiều visual chung gió. |
| `reaction_degrees` | `5.0` | Góc dùng khi gọi react() mà không truyền độ nghiêng. |
| `focus_degrees` | `2.5` | Góc phản ứng khi bắt đầu focus. |
| `reaction_duration` | `0.37` | Tổng thời gian nghiêng qua lại rồi trở về. |
| `appear_duration` | `0.25` | Thời gian hiệu ứng xuất hiện. |
| `disappear_duration` | `0.16` | Thời gian co/mờ. |
| `appear_scale` | `(0.65,0.65)` | Hệ số scale bắt đầu xuất hiện, nhân với transform gốc. |
| `appear_overshoot` | `(0.9,1.1)` | Nhịp vượt trước khi trở về scale gốc. |
| `disappear_scale` | `(1.15,0.45)` | Hệ số scale cuối khi biến mất. |

## API và tín hiệu

- `set_focused(value: bool)`: phản ứng một lần khi false → true. Giữ focus không lặp Tween.
- `react(degrees: float = -1.0, direction: float = 1.0)`: rung ngắn; độ âm dùng reaction_degrees,
  direction âm đảo phía nghiêng.
- `play_appear()`: co/phồng nhẹ rồi trở về dáng gốc.
- `play_disappear()`: co và mờ; khóa các phản ứng mới cho tới reset().
- `reset()`: hủy Tween, trả transform/alpha gốc, xóa focus và khóa biến mất để có thể tái sử dụng.
- `is_animating()`: đang có Tween chạy.
- `effect_started(effect: StringName)`, `effect_finished(effect: StringName)`:
  effect là `react`, `appear` hoặc `disappear`.

Chỉ một Tween hoạt động mỗi component. Hiệu ứng mới hủy Tween cũ và bắt đầu từ dáng gốc;
không cộng dồn độ nghiêng. Transform gốc được giữ đầy đủ, bao gồm rotation/scale/skew.
Tháo component hủy Tween, khôi phục dáng/alpha và trả material cũ nếu material gió vẫn do nó quản lý.
Component không có vòng lặp _process; gió chạy bằng shader TIME.

## Tích hợp cây trồng hiện tại

`scenes/crops/crop.tscn` có node `VisualMotion`, target gán Sprite,
wind_material gán `resources/effects/crop_wind.tres`; Crop.motion được assign trực tiếp.

`Crop` chuyển focus/hover sang motion.set_focused(), ủy quyền react()/play_sprout(),
và gọi play_disappear() sau khi thu hoạch đã commit. Khi nhận effect_finished(`disappear`),
chính Crop mới queue_free. Không lưu trạng thái Tween vào save; loại bỏ component vẫn cho phép
cây lớn và thu hoạch, chỉ bỏ hiệu ứng.

Kiểm thử: [test_visual_motion_component.gd](../tests/unit/test_visual_motion_component.gd)
kiểm tra pivot với transform bất kỳ, AnimatedSprite2D của con vật, collision/animation/flip,
tháo component, material tùy chọn và reset sau biến mất. Test cây hiện có kiểm tra gốc cố định,
focus không lặp, growth/yield và vòng đời thu hoạch.
