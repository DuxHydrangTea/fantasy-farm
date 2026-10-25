# Nấu ăn với NPC Chef Chloe

Đã triển khai ngày 25/10/2026 tại NPC **Chef** người chơi đã đặt trong MainWorld. Đến gần rồi nhấn E hoặc click/tương tác cảm ứng như NPC thương nhân. Chọn món và số lượng, giao nguyên liệu, sau đó quay lại nhận món.

## Quy tắc hiện tại

- Chọn công thức rõ ràng trước khi giao nguyên liệu; hiển thị đang có / cần cho số lượng chọn.
- Mỗi món mất **4 giờ thực**, nấu **lần lượt**, kể cả offline. Ví dụ giao 3 món: món đầu xong sau 4 giờ, món cuối sau 12 giờ.
- Tối đa **20 món tổng cộng** trong hàng chờ và khay thành phẩm. Không tự động nấu thêm ngoài lượng đã giao.
- Nguyên liệu trừ ngay khi xếp hàng; không mất xu và không thể hủy đơn nấu ở bản này.
- Túi đầy: thành phẩm còn lại ở Chef. Có thể nhận một phần nếu còn chỗ cho một số món.
- Nấu và thu đều khóa tái nhập, chống callback trừ/nhận lặp. Save sau thao tác dùng SaveManager đang bind đúng World; autosave vẫn hoạt động.
- Món là PRODUCE, bán được tại người mua nông sản. Giá món = ceil(2,2 × tổng giá bán nguyên liệu) theo catalog hiện hành, không dùng các giá đề xuất cũ.

| Món | Nguyên liệu/món | Giá bán |
|---|---|---:|
| Trứng chiên | 1 trứng gà | 18 |
| Trứng ngỗng hấp | 1 trứng ngỗng | 62 |
| Bánh mì | 2 lúa mì + 1 trứng vịt | 165 |
| Salad trái cây | 1 táo + 1 đào | 121 |
| Bánh mì mật ong | 1 mật ong hoa + 1 lúa mì | 946 |

## Dữ liệu và lưu

`CookingRecipe` Resource cấu hình nguyên liệu, output và thời gian; năm công thức ở `resources/kitchen/recipes`. `ChefCooking` giữ mô hình độc lập với NPC/UI. `ChefMerchant` tái dùng tương tác thương nhân; `CookingMenu` dùng TradeMenu, theme và điều khiển số lượng cảm ứng có sẵn.

Save **v22** thêm `cooking` (schema hiện tại v23 bổ sung workers và giữ nguyên cooking), gồm hàng chờ với timestamp hoàn thành tuyệt đối, danh sách món đã xong và mốc cập nhật. Migration v21 → v22 khởi tạo rỗng, giữ nguyên xu, túi và nâng cấp nông cụ; các migration cũ vẫn chạy tuần tự. Restore tính offline từ trạng thái lưu, không cộng lặp. Validation chặn recipe lạ, timestamp sai hoặc quá sức chứa trước khi sửa World.

Thiết kế bếp tự đặt trước đây được thay bằng luồng trực tiếp với Chef theo yêu cầu hiện tại. Chưa thêm vật phẩm bếp đặt trên map, tiêu thụ món để hồi sức hoặc đơn hàng món ăn.

## Kiểm chứng

- 39/39 bài test, 500 assertions: nấu/thu/bán cả 5 món, nguyên liệu thiếu, buffer đầy, túi đầy và nhận một phần, khóa tái nhập, offline, migration, lưu file và UI cảm ứng.
- 10 kiểm tra native đạt trên mỗi renderer Compatibility và Forward+, gồm click và ScreenTouch nấu đúng một lần, nhận món, mở/đóng modal và bố cục 844×390.
- Lint: 0 lỗi/cảnh báo. Engine: không có diagnostic mới thuộc Chef; cảnh báo nền của project vẫn được giữ trong báo cáo. Web export thành công.
- Chưa thử trên điện thoại vật lý hoặc chạy bản Web trong trình duyệt. Mọi QA dùng World con/staging và userdata tách biệt, không sửa save cá nhân.
- [Bằng chứng và ảnh giao diện](chef_2026-10-25/).

Mở lại game để nạp script mới, đến Chef ở vị trí đã đặt trên map rồi E/click. Không cần mua bếp riêng.

## Thanh tiến độ trên Chef

Chef hiển thị tên món và % của món đầu hàng chờ trên đầu NPC. Khi có món hoàn thành, hiện số món chờ nhận; nếu vẫn đang nấu món tiếp theo thì hiển thị cả hai. Thanh ẩn khi bếp trống, mở menu nấu hoặc đang hiện bong bóng hội thoại. Dùng timestamp chung, cập nhật 4 lần/giây, không tạo node mới mỗi frame.

Bổ sung này được kiểm tra qua 12 bài test Chef (126 assertions), gồm mốc 0/50/100%, chuyển món và ẩn sau thu; 14 kiểm tra native đạt trên mỗi renderer. [Ảnh và bằng chứng](chef_status_2026-10-25/).
