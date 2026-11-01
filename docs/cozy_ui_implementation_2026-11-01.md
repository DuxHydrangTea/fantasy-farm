# Triển khai UI Đồng quê ấm áp — 01/11/2026

Người dùng chốt concept trong phiên này; đã áp dụng vào game.

- FarmUI tạo theme vector bằng StyleBoxFlat, kem/nâu/xanh lá; font hệ thống hỗ trợ tiếng Việt. Các kiểu panel, slot, thẻ chi tiết và nút chính có hình thức riêng.
- Đồng hồ capsule, tiền và nút cài đặt tròn; hotbar nổi có nhãn vật phẩm dạng pill phía trên và hướng dẫn phía dưới. Sprite vật phẩm giữ nearest filtering.
- Thẻ nhiệm vụ có tiêu đề, tiến độ, thưởng và nhận thưởng trực tiếp khi sẵn sàng. Khung thấp dùng bố cục gọn để giữ hướng dẫn onboarding.
- Túi, cài đặt, cửa hàng và thông báo lưu dùng ngôn ngữ thiết kế mới qua theme dùng chung. Giữ logic input, modal và lưu hiện có.
- Không dùng PixelLab hoặc tạo ảnh AI. Không tạo commit.

## Kiểm chứng

- 41/41 test, 1091 assertion: cozy_final_tests.log (UI completion, hotbar, objectives, small window, mobile, onboarding).
- Sau chỉnh chiều rộng nhãn hotbar và thêm ca nhận thưởng trực tiếp/chống nhận lặp: 21/21 test, 267 assertion, cozy_claim_tests.log. Tổng 42 ca khác nhau qua hai lần chạy.
- Lint cuối: không lỗi/cảnh báo, cozy_implementation_lint.json.
- Preview thật chạy không có script error ở 1280×720 và 1920×1080, tiếng Việt/Anh; ảnh cozy_hud_vi_1280.png, cozy_hud_vi_1920.png, cozy_settings.png, cozy_inventory.png.
- Whole-project validator không sạch: quét cả output/flower_scene_refactor_backup gây trùng global class cùng các cảnh/plugin ngoài phạm vi UI (cozy_validation.json). Không có error/parse_error/script_error gắn đường dẫn res://components/ trong báo cáo đó. Không tuyên bố toàn repo sạch lỗi.
- Các lỗi kho/migration và scheduler patrol ghi trong bản bàn giao chưa được xử lý trong đợt này.

Font dùng SystemFont Segoe UI/Noto Sans/Arial; máy khác có thể có khác biệt nhỏ về nét chữ. Theme không sửa asset pixel cũ; được tạo và cache lúc chạy.

## Bubble và font đồng bộ

Theo yêu cầu tiếp theo: bubble NPC và bubble chữa bệnh động vật dùng FarmUI.speech, khung kem bo góc, chữ nâu và đuôi giữa bằng vector. game_font.tres dùng chung SystemFont Segoe UI/Noto Sans/Arial, thay font pixel cũ cho các nhãn game. Icon tình trạng vẫn là sprite.

Kiểm chứng: các suite shop/boosters/small window/UI qua trong cozy_speech_tests.log; ca kiểm tra bubble động vật cũ đã cập nhật đường dẫn theo container mới, 7/7 qua trong cozy_speech_care_checks.log. UI/mobile/onboarding 19/19 qua trong cozy_speech_followup.log, có thêm ca kiểm tra font và chữ tiếng Việt trong khung. Lint cuối 0 lỗi/cảnh báo. Preview thật tiếng Việt/Anh: ui_after_speech_vi.png, ui_after_speech_en.png. Preview có cảnh báo UID main_world.gd dùng text path; không có script error.
