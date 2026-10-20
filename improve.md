# Kế Hoạch Cải Thiện Codebase (Improvement Roadmap) - Fantasy Farm

Tài liệu tổng hợp các hạng mục cần tái cấu trúc, dọn dẹp kỹ thuật và tối ưu hóa hiệu năng cho dự án **Fantasy Farm** (Godot 4.7 GDScript).

---

## 1. Dọn dẹp Code chết & Rác cấu hình (Ưu tiên P0 - Quick Wins)

* **Hiện trạng:**
  * Thư mục `components/controllers/` (`controller.gd`, `chicken_ai_controller.gd`, `player_input_controller.gd`, `player_ui_component.gd`) là tàn dư từ phiên bản cũ. Các file này tham chiếu tới các lớp không tồn tại: `CharacterBase`, `Player`, `ChickenCoop`, `InventoryPanel`, `Hotbar`, `IdleState`, `WalkState`.
  * File `components/animal_needs_component.gd` (`LegacyAnimalNeedsComponent`) bị trùng lặp chức năng với `components/animals/animal_needs_component.gd` (`AnimalNeedsComponent`).
  * `project.godot` vẫn còn block `[dotnet]` và thư mục `tests/Core/bin/` còn tàn dư build của .NET runtime cũ dù toàn bộ dự án hiện tại là thuần GDScript.
* **Hành động đề xuất:**
  * [ ] Xóa bỏ thư mục `components/controllers/`.
  * [ ] Xóa bỏ file `components/animal_needs_component.gd`.
  * [ ] Xóa bỏ phần cấu hình `[dotnet]` trong `project.godot` và thư mục `tests/Core/bin/`.
  * [ ] Cập nhật các liên kết trong `docs/` nếu có tham chiếu đến các file đã xóa.

---

## 2. Khắc phục nghẽn hiệu năng khi Tìm đường (Ưu tiên P1 - Critical)

* **File liên quan:** `components/player_navigation_component.gd`
* **Hiện trạng:**
  * Trong `_build_path_in_region()`, mỗi lần người chơi click để di chuyển, hàm tạo mới `AStarGrid2D` và duyệt qua toàn bộ vùng `region`.
  * Với mỗi ô cell, hàm gọi `_point_clear()` -> tạo mới đối tượng `PhysicsShapeQueryParameters2D` và gọi `direct_space_state.intersect_shape()`.
  * Một vùng $30 \times 30$ đến $60 \times 60$ ô sẽ kích hoạt từ **900 đến 3.600 physics queries đồng bộ trong 1 frame**, gây hiện tượng khựng khung hình (micro-stutter / frame drop) rõ rệt.
* **Hành động đề xuất:**
  * [ ] Chuyển sang sử dụng `NavigationServer2D` / `NavigationAgent2D` tích hợp sẵn của Godot 4 kết hợp NavigationLayer trên TileMapLayer.
  * [ ] *Hoặc phương án nhẹ hơn:* Khởi tạo `AStarGrid2D` một lần, bake chướng ngại vật từ TileMapLayer/Pen bounds khi load màn chơi, và chỉ cập nhật điểm cell cục bộ khi có công trình/chướng ngại vật xuất hiện thay vì query physics liên tục từng ô.

---

## 3. Tối ưu I/O và Main Thread khi Autosave (Ưu tiên P1 - Performance)

* **File liên quan:** `persistence/local_save_repository.gd`, `persistence/save_manager.gd`
* **Hiện trạng:**
  * Hàm `write_profile()` chạy hoàn toàn đồng bộ trên Main Thread.
  * Mỗi chu kỳ autosave (30 giây/lần), code thực hiện:
    1. Đọc file chính để kiểm tra revision (đọc đĩa + hash SHA256 + parse JSON).
    2. Ghi ra file tạm `.tmp`.
    3. Đọc lại file tạm `.tmp` để kiểm tra toàn vẹn.
    4. Đọc lại file chính một lần nữa trước khi đổi tên sang `.bak`.
  * Tổng cộng: **3 lần đọc + 1 lần ghi + 2 lần hash SHA256 + 3 lần JSON parse** cho mỗi lần lưu. Khi file save lớn dần, việc này sẽ gây khựng game định kỳ.
* **Hành động đề xuất:**
  * [ ] Cache `current_revision` ngay trên RAM trong `GameSaveManager`/`LocalSaveRepository` để tránh lần đọc đĩa ban đầu.
  * [ ] Tận dụng `WorkerThreadPool` của Godot để đưa tác vụ serialize JSON, hash SHA256 và ghi đĩa xuống thread ngầm, tránh chặn Main Thread.

---

## 4. Chuẩn hóa Input System & Accessibility (Ưu tiên P2 - Usability)

* **File liên quan:** `components/state_component.gd`, `components/inventory_ui.gd`
* **Hiện trạng:**
  * Phím `KEY_E` (thu hoạch) và sự kiện chuột trái/phải đang bị kiểm tra trực tiếp bằng keycode/button index trong `StateComponent.gd`.
  * Phím `KEY_I` và `KEY_ESCAPE` bị kiểm tra cứng trong `InventoryUI.gd`.
  * `InventoryUI.gd` gọi `get_viewport().set_input_as_handled()` nuốt trọn mọi phím khi túi đồ đang mở, vô tình chặn các phím tắt hệ thống (chụp ảnh màn hình, toggle full screen, debug console).
* **Hành động đề xuất:**
  * [ ] Đăng ký các action rõ ràng trong `project.godot`: `interact`, `harvest`, `ui_cancel`, `toggle_inventory`.
  * [ ] Đổi toàn bộ kiểm tra `physical_keycode` sang `Input.is_action_just_pressed(...)` để hỗ trợ đổi phím (remapping) và tay cầm (gamepad).
  * [ ] Giới hạn việc `set_input_as_handled()` trong UI chỉ với các phím liên quan đến hành vi trong inventory.

---

## 5. Giảm phân bổ bộ nhớ & Polling trong Game Loop (Ưu tiên P2 - Architecture)

* **File liên quan:** `components/inventory_component.gd`, `components/farming_controller.gd`, `components/flowers/flower_garden.gd`, `components/farming_action_component.gd`
* **Hiện trạng:**
  * `InventoryComponent.slot(index)` luôn gọi `.duplicate()`. Trong `InventoryUI._refresh()`, nó bị gọi 25 lần mỗi khi túi đồ thay đổi, tạo ra các Dictionary tạm không cần thiết.
  * `FarmingController` và `FlowerGarden` đều nối tín hiệu `time_manager.tick` (tần suất 10Hz - mỗi 0.1s) để lặp toàn bộ mảng dictionary `_crops.values()` và `pots.values()`.
  * `FarmingActionComponent` dùng biến tĩnh `impact_frame: int = 3`. Nếu sprite thay đổi animation có ít hơn 3 frame, hành vi canh tác sẽ bị kẹt vĩnh viễn.
* **Hành động đề xuất:**
  * [ ] Thêm các hàm truy vấn trực tiếp không clone: `is_empty_slot(index) -> bool`, `get_slot_item(index) -> ItemDefinition`, `get_slot_count(index) -> int`.
  * [ ] Chuyển cơ chế kiểm tra tăng trưởng cây trồng sang dạng hàng đợi theo thời gian (Event-driven / Timer theo mốc gần nhất) thay vì duyệt mảng 10 lần mỗi giây.
  * [ ] Kiểm tra an toàn cho `impact_frame`: `mini(impact_frame, animation.animated_sprite.sprite_frames.get_frame_count(...) - 1)` hoặc dùng AnimationPlayer track thay vì phụ thuộc chỉ số frame cứng.
