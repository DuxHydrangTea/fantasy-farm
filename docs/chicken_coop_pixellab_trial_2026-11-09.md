# Chuồng gà mới — PixelLab trial

## Thiết kế

Chuồng gà gỗ kê trên chân thấp, mái rơm hai tầng lệch cao, cửa nhỏ kèm cầu dẫn, cụm ổ đẻ nhô bên hông. Giữ phong cách pixel, bảng màu gỗ và độ đậm viền của building hiện có, tạo silhouette và kiến trúc riêng.

## Cấu hình đã chuẩn bị

- Tool: `create_object_pro_flash`, một hướng.
- Canvas: 192 × 160 px; phí theo schema hiện tại: 6 generations.
- Reference: `assets/Buildings/Buildings/Unique_Buildings/Inn/Inn_Red.png`, chỉ tham chiếu style.
- Output: sprite nền trong suốt, chưa thay building trong game.

## Prompt

Create one original chicken coop game-world sprite for a cozy rural fantasy pixel-art farming RPG. Use the reference ONLY for its crisp native pixel density, dark colored outlines, compact shading clusters, warm timber palette and material detail; invent an entirely different building silhouette and layout. A small raised wooden poultry house on short sturdy posts, two offset golden straw roof sections with a low upper ventilation cap, broad horizontal front facade, small chicken entrance with a short wooden ramp, projecting side nesting boxes with lift-up lids, woven bamboo vent panels, a tiny wooden chicken-shaped emblem without letters. Modest footprint, readable agricultural construction, sparse straw at the base. No inn architecture, no tall central gable, no dormer row, no blue window grid, no chimney, no surrounding fence or scenery. Straight-on, front-facing 2D game view, horizontal front facade, with the roof visible from slightly above; no isometric, diagonal, or three-quarter side view. Complete silhouette within a 192x160 native pixel canvas, isolated on transparent background. No text, UI, blur, antialiasing, smooth gradients, painterly rendering or 3D rendering.

## Trạng thái

Đã tạo sau khi người dùng cập nhật `.env`. Object ID: `53894fac-d00b-4a5c-b3d7-5781fafab8cf`. Kết quả: `docs/chicken_coop_pixellab_2026-11-09.png`, canvas 192 × 160, nền trong suốt. Đã xem ảnh: mặt tiền ngang, mái nhìn hơi từ trên xuống, kiến trúc chuồng gỗ mái rơm có cầu dẫn và ổ đẻ hai bên, khác silhouette nhà trọ tham chiếu. Chưa tích hợp vào game.

Ảnh tham chiếu được crop nguyên pixel về 192 × 160 để phù hợp giới hạn tool. Receipt ước tính 6 generations; balance trước/sau là 1518,40 và 1511,40, chênh lệch thực tế 7 generations. Dùng 1 khóa trả phí, không ghi giá trị khóa vào tài liệu.
