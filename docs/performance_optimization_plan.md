# Kế hoạch tối ưu hiệu năng Fantasy Farm

Mục tiêu: giảm công việc thừa và hiện tượng khựng hình, đồng thời giữ nguyên kết quả gameplay, dữ liệu lưu và cách tương tác.

Đã có [baseline native dev có render](dev_performance_baseline_2026-10-22.md) và [kết quả triển khai đợt đầu ngày 22/10/2026](performance_optimization_results_2026-10-22.md). Đã sửa khóa StringName trong save tổ ong và triển khai các mục 1–3. Test chức năng đã qua; chưa định lượng được mức tăng FPS vì phép đo lại bị nhiễu bởi stall xuất hiện cả ở source cũ và mới. Chưa profile đến từng hàm hoặc triển khai các mục 4–8.

## 0. Đo hiệu năng trước khi thay đổi

- [x] Ghi lại máy thử, độ phân giải, mức zoom và cấu hình đồ họa trong báo cáo baseline native dev.
- [ ] Chuẩn bị các cảnh thử có thể lặp lại:
  - Đứng yên và đi quanh map đã decor, có 48 bướm.
  - Ruộng có nhiều cây; hai vườn có nhiều cây lâu năm.
  - Nhiều vật nuôi đang đi lại, ăn và uống.
  - Chuyển thời tiết, mưa và ban đêm.
  - Thu hoạch liên tiếp, click di chuyển và đặt/xóa vật cản.
  - Autosave khi world có nhiều dữ liệu.
- [ ] Đo thời gian frame, script, physics, rendering, số node và bộ nhớ; ghi cả các đợt tăng đột biến.
- [ ] Chọn phần cần tối ưu từ số đo. Không xem FPS trung bình là chỉ số duy nhất.
- [ ] Dùng cùng một kịch bản và cấu hình để so sánh trước/sau từng thay đổi.

## 1. Cho hiệu ứng thời tiết nghỉ khi không hoạt động

**Ưu tiên:** cao. **File chính:** `components/weather/weather_effects.gd`.

Hiện `_process()` vẫn cập nhật vùng camera, âm lượng và gọi `queue_redraw()` khi hiệu ứng bằng 0.

- [x] Xác định điều kiện phần hình ảnh thực sự không cần cập nhật.
- [x] Ngừng công việc hình ảnh khi không có hiệu ứng và không còn chuyển tiếp.
- [x] Đánh thức lại khi bắt đầu chuyển thời tiết; giữ đầy đủ fade out/fade in.
- [ ] Chỉ cập nhật âm lượng khi cần, nếu số đo cho thấy đáng làm.

**Giữ nguyên logic:** WeatherManager, lịch thời tiết, đồng hồ, mưa tưới đất và ảnh hưởng lên cây/ong vẫn chạy. Không tắt toàn bộ hệ thống thời tiết.

**Kiểm tra:** nắng → mưa → nhiều mây → gió → nắng; kiểm tra hình ảnh, âm thanh, tưới đất và load tiến độ thời tiết.

## 2. Cho camera zoom nghỉ khi đạt đích

**Ưu tiên:** cao. **File chính:** `components/camera_zoom_component.gd`.

- [x] Dừng callback nội suy khi zoom đã đạt đích.
- [x] Đánh thức lại khi nhận thao tác zoom.
- [x] Tính lại clamp khi cửa sổ hoặc giới hạn camera thay đổi.
- [x] Giữ cách nội suy theo thời gian hiện tại.

**Giữ nguyên logic:** giới hạn map, zoom tối thiểu, xử lý input khi mở menu và độ mượt theo FPS.

**Kiểm tra:** zoom liên tục, đổi kích thước cửa sổ, mở/đóng menu, di chuyển ở bốn mép map và thử nhiều FPS.

## 3. Cập nhật UI theo thay đổi dữ liệu

**Ưu tiên:** cao. **File chính:** `components/hotbar_ui.gd`, `components/ui_scale_component.gd`.

- [x] Cập nhật tên và tooltip khi lựa chọn hoặc dữ liệu liên quan thay đổi.
- [x] Giảm việc lấy feedback, dịch chuỗi và dựng tooltip mỗi frame.
- [x] Có cơ chế làm mới khi feedback hết hạn, kể cả người chơi không thao tác.
- [x] Rà phần scale UI: tận dụng sự kiện resize và chỉ giữ kiểm tra dự phòng cần thiết cho thay đổi stretch/DPI.
- [x] Tránh gán lại thuộc tính UI khi giá trị không đổi.

**Giữ nguyên logic:** đổi slot, booster, feedback tương tác, bản dịch và kích thước UI trên cửa sổ nhỏ.

**Kiểm tra:** thay đổi túi đồ, đổi vật phẩm/ngôn ngữ, feedback xuất hiện rồi hết hạn, resize và mở các menu.

## 4. Giảm việc lấy lại danh sách đối tượng

**Ưu tiên:** trung bình. **File cần rà:**

- `components/context_bars_component.gd`
- `components/interaction/interaction_resolver.gd`
- `components/animals/trough_interaction_component.gd`
- `components/animals/animal_foraging_component.gd`
- `components/flowers/flower_interaction.gd`

- [ ] Đo số lần gọi `get_nodes_in_group()` và số đối tượng được duyệt.
- [ ] Với danh sách ít thay đổi, cân nhắc registry hoặc cache tham chiếu.
- [ ] Đăng ký/hủy đăng ký khi đối tượng vào/rời world.
- [ ] Xử lý node đang bị xóa và khi load/thay world.
- [ ] Chỉ cache danh sách; vẫn đọc vị trí/trạng thái mới của đối tượng di động.

**Giữ nguyên logic:** ưu tiên tương tác, mục tiêu gần nhất, loài tương thích và reservation tại máng. Cache không được giữ đối tượng đã bán hoặc bỏ sót đối tượng mới mua.

**Kiểm tra:** mua/bán/xóa vật nuôi, thêm máng, load game và tương tác với mục tiêu đang di chuyển.

## 5. Giảm mảng và đối tượng tạm khi tìm mục tiêu

**Ưu tiên:** trung bình. **File chính:** `components/context_bars_component.gd`, `components/interaction/interaction_resolver.gd`.

- [ ] Đo cấp phát trong quá trình hover/focus.
- [ ] Tái sử dụng bộ đệm hoặc xét ứng viên trực tiếp nếu có lợi.
- [ ] Tránh dựng nhiều danh sách cho cùng một lượt truy vấn khi có thể dùng chung kết quả hợp lệ.
- [ ] Giữ việc tra cây trồng theo ô đất hiện có.

**Giữ nguyên logic:** hit-test theo sprite, thứ tự ưu tiên, cách xử lý khoảng cách bằng nhau, hover khi camera di chuyển và mục tiêu vừa bị xóa.

**Kiểm tra:** các sprite chồng nhau, tán cây vượt ô gốc, chuột đứng yên nhưng camera/mục tiêu di chuyển, thu hoạch hoặc bán đúng lúc đang hover.

## 6. Làm mới navigation theo vùng

**Ưu tiên:** trung bình; cần test đường đi kỹ. **File chính:** `components/player_navigation_component.gd` và các nơi gọi `invalidate_cache()`.

- [ ] Đo số physics query và các đợt xóa toàn bộ cache.
- [ ] Tận dụng `invalidate_region()` khi biết chính xác phạm vi vật cản thay đổi.
- [ ] Bao phủ cả vùng cũ và mới nếu di chuyển vật cản, cùng khoảng đệm cho chân va chạm.
- [ ] Kiểm tra dữ liệu ô bị chặn, cache và đường đang đi đều được cập nhật nhất quán.
- [ ] Giữ full invalidation khi không xác định được phạm vi hoặc footprint nhân vật thay đổi.
- [ ] Giữ ngân sách sampling và nguyên tắc ô chưa kiểm tra được xem là bị chặn.

**Giữ nguyên logic:** player không đi xuyên vật cản; vẫn tiếp cận đúng mục tiêu, xử lý đích di động và hủy lệnh tương tác cũ.

**Kiểm tra:** đặt/chặt/bứng cây, đặt tổ ong, đổi TileMap va chạm, chặn đường đang đi và click tới mục tiêu ở vùng chưa có cache.

## 7. Giảm animation trang trí ngoài màn hình

**Ưu tiên:** sau khi đo. **File cần rà:** `components/landscape/butterfly_roamer.gd`, `components/landscape/butterfly_swarm.gd` và các visual decor.

- [ ] Đo chi phí animation và cập nhật visual ngoài camera.
- [ ] Tách công việc hình ảnh khỏi trạng thái mô phỏng nếu cần.
- [ ] Cân nhắc tạm dừng vỗ cánh hoặc hiệu ứng phụ ngoài màn hình; tiếp tục khi quay vào.
- [ ] Không thêm notifier/cơ chế quản lý phức tạp nếu chi phí lớn hơn phần tiết kiệm được.

**Giữ nguyên logic bướm:** vẫn di chuyển và phát hiện đi qua vườn; lượt lượn kết thúc sau 30 giây; cooldown kéo dài 300 giây sau lượt lượn. Không tắt toàn bộ `_process()` của bướm hoặc bù bằng một delta lớn khi quay vào camera.

**Kiểm tra:** rời camera giữa lượt lượn/cooldown, quay lại, pause/resume và thử ở 15/60/144 FPS. Giữ test `tests/unit/test_butterfly_roaming.gd`.

## 8. Tái sử dụng hiệu ứng ngắn nếu có spike cấp phát

**Ưu tiên:** sau khi đo. **File cần rà:** `components/harvest_burst.gd`, `components/item_gain_popup.gd`.

- [ ] Đo khi thu hoạch và nhận nhiều vật phẩm liên tiếp.
- [ ] Chỉ thêm pool nếu tạo/xóa node gây khựng đáng kể.
- [ ] Giới hạn kích thước pool.
- [ ] Reset timer, tween, signal, texture, đích, transform và alpha trước mỗi lần dùng lại.
- [ ] Giữ giới hạn tối đa 3 icon đại diện cho một hiệu ứng thu hoạch.

**Giữ nguyên logic:** giao dịch cộng đồ đã hoàn tất trước hiệu ứng. Hiệu ứng kết thúc hoặc được tái sử dụng không được cộng vật phẩm lần nữa.

**Kiểm tra:** yield lớn, nhận đồ liên tiếp, túi đầy, đích bị xóa và load/chuyển world trong lúc hiệu ứng chạy.

## Những tối ưu hiện có cần giữ

- Cây trồng cập nhật theo lịch mốc tăng trưởng thay vì refresh toàn bộ mỗi frame.
- Hover cây tra theo ô và vùng lân cận thay vì duyệt cả ruộng.
- Một số hệ thống focus/tương tác đã có chu kỳ cập nhật 0,05 giây; không giảm tần suất tiếp nếu chưa đo độ trễ.
- Navigation đã có cache và ngân sách sampling.
- Ong đã có cơ chế nghỉ visual ngoài màn hình.
- Hiệu ứng thu hoạch đã giới hạn số icon và tách khỏi giao dịch vật phẩm.
- Bướm dùng tài nguyên SpriteFrames chung và không tham gia physics/navigation.

## Những thay đổi cần tránh trong đợt đầu

- Giảm physics tick chỉ để tăng FPS.
- Đóng băng toàn bộ vật nuôi ngoài camera.
- Bỏ kiểm tra va chạm, điều kiện tương tác hoặc kiểm tra sức chứa túi.
- Đổi đồng hồ tăng trưởng, sản lượng, deadline hoặc cách tính tiến độ offline.
- Thay đổi thứ tự commit giao dịch, khóa chống gọi lại, revision hoặc quy trình phục hồi save.
- Gom mọi render/animation thành một hệ thống lớn khi chưa xác định bottleneck.

## Điều kiện hoàn tất mỗi mục

- [ ] Có số đo trước/sau trong cùng kịch bản; ghi rõ lợi ích và chi phí phát sinh.
- [ ] Không có lỗi parse/runtime mới hoặc vấn đề resource.
- [ ] Test liên quan và các trường hợp biên đã chạy qua.
- [ ] Kết quả gameplay, thời gian và dữ liệu lưu đáp ứng các điều kiện giữ nguyên ở trên.
- [ ] Không mở rộng phạm vi sang hệ thống khác nếu không cần thiết.

**Đợt triển khai đầu đề xuất:** đo baseline → hiệu ứng thời tiết → camera zoom → UI. Sau đó dùng số đo mới để quyết định có tiếp tục với registry, navigation, culling và pooling hay không.
