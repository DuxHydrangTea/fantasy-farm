# Nâng cấp nông cụ — bàn giao U1

> Tài liệu lịch sử tại thời điểm U1. Bản hiện tại đã bật mua ở NPC và hoàn thành U1–U6: [hướng dẫn hiện tại](tool_upgrades.md).

Ngày 25/10/2026. Đã triển khai lại U1 theo [kế hoạch](tool_upgrade_implementation_plan.md), sau khi đối chiếu trạng thái workspace hiện tại.

## Phần đã có

- `ToolUpgradeState`: ba loại `hoe`, `watering_can`, `sowing`; cấp 1–3 và phạm vi đã chọn 1–cấp hiện tại. Snapshot là dữ liệu nguyên thủy, được sao chép độc lập và validate chặt chẽ.
- `ToolUpgradeCatalog` / `ToolUpgradeOffer`: sáu offer cấu hình tại `resources/tools/upgrades.tres`, dùng giá và gate thử nghiệm trong plan. Gate tính số cột mua thêm theo starting_columns của từng profile.
- `ToolUpgradeService`: quote/mua một cấp, kiểm tra giá/cấp mong đợi, số xu, gate và trạng thái profile. Wallet và cấp cùng commit trước signal; khóa ở model ngăn mua lại qua callback hoặc một vendor khác.
- FarmWorld lắp service trong `_ready`, khi Player đã tạo wallet. Model/service là RefCounted, không thêm node xử lý mỗi frame.
- Save schema **v21** lưu `tool_upgrades`. Migration v20 → v21 cấp mặc định 1×1, không sửa DTO đầu vào; chuỗi v19 → v20 → v21 vẫn đầy đủ.
- WorldStateAdapter capture/restore state và thông báo sau restore hoàn tất. Dữ liệu nâng cấp không hợp lệ hoặc đang có giao dịch sẽ bị từ chối trước khi thay đổi World.
- GameSaveManager đồng bộ trạng thái sẵn sàng: chặn giao dịch khi đang tải/ghi, lỗi tải hoặc mất quyền lưu.

## Giới hạn của U1

`purchasing_enabled` mặc định **false**. U1 cung cấp nền tảng và kiểm thử qua harness; NPC chưa bán nâng cấp. Thao tác đất và preview hiện vẫn theo luồng đang có. U2 mở rộng thao tác nhiều ô, U3 bổ sung preview/chọn phạm vi, U4 mới bật mục nâng cấp tại NPC.

Nâng cấp gieo hạt là tiến trình chung của profile, không thay ID hạt giống, không tạo thêm item nông cụ hay cấp miễn phí vào túi.

## Kiểm chứng

**43/43 tests, 568 assertions**, chạy trong project/userdata tạm riêng:

- Unit state/service: mặc định độc lập, nâng từng loại đến cấp tối đa, đổi phạm vi, gate cho profile bắt đầu 1 hoặc 4 cột, thiếu tiền, quote cũ, catalog lỗi, profile chưa sẵn sàng, mua tái nhập qua vendor khác và dữ liệu JSON sai.
- Save repository: hồi quy đọc/ghi, backup, revision, migration và các trường hợp lỗi.
- Integration: v19/v20 migration không thay đầu vào; mua → lưu file → reset model → tải lại đúng cấp/phạm vi/xu; từ chối v21 thiếu/hỏng dữ liệu; chặn restore trong callback mua; chặn giao dịch trong lúc ghi và sau lỗi tải.
- Hồi quy 12 máng: đúng persistent ID/capacity, stock 600 giữ nguyên, quyền lưu phục hồi; preview World không bind SaveManager cá nhân.

Lint toàn project không lỗi/cảnh báo; engine validation của module đạt. Web export thành công. Probe dùng bản sao save thực đã migrate v20 → v21 và restore thành công; giữ nguyên xu, item/count trong từng slot và DTO đầu vào. Probe không ghi file save cá nhân.

Bằng chứng đã loại dữ liệu profile riêng tư: [tool_upgrade_u1_2026-10-25](tool_upgrade_u1_2026-10-25/). Bản sao profile phục vụ QA nằm trong `.godot/tool-upgrade-u1-qa/`, không đưa vào Git hoặc báo cáo.

## Tiếp theo: U2

Tạo policy footprint chung cho 1×1 / 2×2 / 3×3 và batch till/water/plant tại impact frame. U2 đọc cấp/phạm vi từ ToolUpgradeState; giữ nguyên chi phí một hạt mỗi ô và bỏ qua các ô không hợp lệ. UI chọn vùng và panel NPC theo đúng thứ tự U3/U4 trong kế hoạch.
