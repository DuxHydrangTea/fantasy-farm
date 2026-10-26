# Mở ô cây lâu năm — 2026-10-26

Hai khu cây ăn quả và cây lấy gỗ nâng độc lập: khởi đầu 9 ô, mỗi lần mua mở một cột 9 ô từ trái sang phải, tối đa 153 ô/khu (17 cấp, 16 lần mua). Bố cục 17 cột × 9 hàng và tọa độ cây xen kẽ giữ nguyên.

Bảng quản lý ở mép dưới mỗi khu, dùng cùng hệ tương tác E/click/chạm và khóa menu của game. Hiển thị số ô đã mở, đã trồng, còn trống, coins, giá nâng tiếp và trạng thái tối đa/thiếu coins. Các ô khóa có dấu khóa trên mặt đất và không thể trồng hay làm mất cây giống.

Giá nằm trong `resources/trees/plot_upgrades.tres`. Khu cây ăn quả bắt đầu 30.000 coins, tăng tới 1.380.000 coins/lần nâng cuối; khu cây lấy gỗ bắt đầu 40.000, tăng tới 1.465.000. Đây là giá khởi tạo có thể điều chỉnh trong resource.

Save schema 35 lưu `tree_plot_upgrades` riêng cho mỗi khu. Migration từ 34 trở xuống mở đến cột xa nhất đang có cây, giữ nguyên coins, vị trí và trạng thái cây. Save cũ 306 cây mở tối đa cả hai khu. Chặt/nhổ cây không khóa lại đất. Save mới có cây nằm trên ô khóa bị từ chối trước khi thay đổi thế giới.

Giao dịch kiểm tra readiness/coins/giá và cấp dự kiến; commit coins + tiến độ trước thông báo, chống giao dịch lồng nhau, hoàn tiền nếu commit thất bại, yêu cầu lưu sau khi hoàn tất. Nếu ghi file lỗi, tiến độ vẫn ở bộ nhớ và có thể lưu lại mà không mua lần nữa.

## Xác minh

- 44/44 kiểm thử, 1.409 assertions: nâng ô cây, nâng chuồng, save repository, tương thích máng và ranh giới chuồng (`tests.log`).
- 27/27 mục kiểm tra trong cửa sổ Godot: resolver E/click, thao tác mua bằng chuột/cảm ứng, chống chạm lặp, thiếu coins, max, giao diện desktop/mobile dọc/ngang (`ui-verification.json`, ảnh PNG).
- Linter: 0 lỗi, 11 cảnh báo đường dẫn ảnh QA tồn tại từ trước (`lint.json`). Có các cảnh báo UID tài nguyên cũ nhưng Godot tải được qua đường dẫn văn bản.
- Toàn bộ kiểm tra chạy với user-data và cache thử nghiệm riêng, không ghi vào save thật. Fixture save thật được đọc từ bản sao trong thư mục kiểm thử nâng chuồng.

Chạy lại: `python3 tests/run_tree_tests.py --godot <Godot binary> --suite tests/integration/test_tree_plot_upgrades.gd --suite tests/integration/test_pen_upgrades.gd --suite tests/unit/test_save_repository.gd --suite tests/integration/test_trough_save_compatibility.gd --suite tests/unit/test_animal_pen.gd`.
