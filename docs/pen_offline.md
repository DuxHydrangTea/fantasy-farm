# Tiêu thụ và sản xuất offline cấp chuồng — 24/10/2026

## Hành vi đã triển khai

Mỗi chuồng dùng chung các máng của chính nó. Khi tải save, toàn bộ đàn được dựng tại cùng mốc lưu trước khi tính thời gian còn thiếu. Trong phiên đang chơi, một khoảng gián đoạn lớn hơn 5 giây cũng gọi bộ tính chung; các tick ngắn vẫn dùng AI đi đến máng và phục vụ vật lý như trước.

Bộ tính tách đoạn tại thời điểm máng cạn, no/nước trong cơ thể hết, thời tiết đổi, con vật hết tuổi thọ hoặc một thành viên mới bắt đầu thuộc khoảng tính. Không chạy từng giây hay phát lại đường đi. Khi cả đàn đã hết tuổi thọ, bỏ qua phần thời gian dài còn lại.

- Máng có dự trữ hợp lệ sẽ bù mức thiếu và duy trì no/nước. Nếu phần dự trữ cuối không đủ bù cả đàn, chia theo phần thiếu của các con; không cho con đầu mảng ăn hết. Thứ tự thành viên và máng được chuẩn hóa theo ID.
- Máng cạn thì tiếp tục dùng no/nước trong cơ thể; sản xuất chỉ dừng khi một trong hai chỉ số về 0. Cả đói và khát vẫn tiếp tục diễn biến ở con vật còn sống dù nó đã tạm dừng sản xuất.
- Con non tiêu thụ thức ăn/nước nhưng chỉ được tính sản xuất cho phần thời gian đã trưởng thành. Tiến độ chưa đủ chu kỳ giữ nguyên khi đói/khát.
- Không tính tiêu thụ/sản xuất sau tuổi thọ. Sản phẩm đã hoàn thành còn lại trong kho hoặc đống sản phẩm vẫn được giữ, kể cả khi con vật chết trong chính lần capture.
- Giữ hiệu ứng trời nhiều mây giảm 25% tiêu hao nước và mưa tăng 10% tốc độ sản xuất cho thủy cầm phù hợp. Booster tiếp tục qua cơ chế vòng đời/sản xuất hiện có.
- Pond dùng máng nước uống như Coop/Barn. Đã sửa dòng nước ao không giới hạn trong master specs để đồng bộ với quyết định này.
- Không áp trần một lứa của cây quả/tổ ong cho sản phẩm vật nuôi. Giữ cơ chế đống sản phẩm/kho hiện có, không tự bán hoặc tự chuyển sản phẩm vào túi.

Trước khi thêm cám/nước hoặc mua thành viên mới, chuồng xử lý xong khoảng thời gian trước đó. Thức ăn vừa thêm và con vật vừa mua không được tính ngược về quá khứ. Thu sản phẩm và dùng tonic cũng đồng bộ thời gian trước khi hành động.

## Số liệu cơ bản

Ở tốc độ cơ bản, 100 điểm no/nước tiêu hao trong 3.600 giây, một đơn vị máng hồi 40 điểm: mỗi con dùng 60 đơn vị mỗi loại/ngày. Khi có đủ dự trữ, bộ tính duy trì cơ thể đầy; phần dư trong cơ thể chỉ giảm sau khi hết nguồn cung.

| Chuồng đầy | Mỗi loại cần trong 24 giờ | Mỗi loại dự trữ tối đa |
| --- | ---: | ---: |
| Coop, 30 con | 1.800 | 2.400 |
| Barn, 36 con | 2.160 | 2.400 |
| Pond, 20 con | 1.200 | 2.400 |

Đây là số theo tốc độ cơ bản; thời tiết nhiều mây có thể làm nước tiêu hao ít hơn. Việc nuôi kín chuồng trong 24 giờ yêu cầu máng đã được đổ đủ.

## Lưu và migration v18

- `pen_updated_at`: mốc xử lý cho từng chuồng, phải khớp `saved_at` của snapshot. Tất cả trạng thái đàn và máng được chụp tại mốc này.
- `consumed_fraction`: phần của đơn vị máng cuối đã dùng. Lượng thật còn lại là `stock - consumed_fraction`. Giữ stock nguyên cho các tương tác hiện tại và giữ phần lẻ qua các lần lưu/tải.
- Bảng quản lý tính phần trăm theo lượng thật, không làm tròn tiêu thụ mỗi lần offline. Phần lẻ dưới một đơn vị còn thiếu khi máng hiện stock tối đa được giữ đúng, không tự cấp bù.
- `feed_reserve` hiện có được giữ nguyên; phần cám giữ lại ngoài stock không tự được mở/đổ vào máng bởi mô phỏng offline.
- Save v17 trở về trước chạy migration tuần tự. Mốc bắt đầu lấy từ `saved_at`, phần lẻ ban đầu bằng 0. Giữ đàn/ID, xu, túi, sản phẩm và tiến trình cũ.
- Mốc lệch, phần lẻ sai kiểu/ngoài miền, thiếu chuồng hoặc stock không phù hợp bị từ chối trong preflight trước khi sửa thế giới.
- Capture thu thập lại entity sau khi đồng bộ needs, để không bỏ sót đống sản phẩm vừa sinh và không lưu lại con vật vừa chết.

## Mã chính

- `components/animals/pen_offline_model.gd`: bộ tính thuần với dữ liệu nguyên thủy; không phụ thuộc scene, inventory hay file save.
- `components/animals/pen_offline_simulation.gd`: gom đàn/máng trong scene, áp dụng kết quả qua needs/vòng đời/sản phẩm hiện có rồi tiếp tục AI.
- `AnimalPen`, `AnimalNeedsComponent`, `AnimalTrough`: điều phối khoảng gián đoạn, đồng bộ trước thay đổi kho và bảo toàn tiêu thụ lẻ.
- `WorldStateAdapter`, `SaveSchema`: snapshot chung, phục hồi cả đàn trước catch-up và migration.
- `PenStatus`: phần trăm máng theo stock thực; thẻ vật nuôi dùng mức no/nước và lý do tạm dừng hiện có.

## Kiểm thử

Bằng chứng: [pen_offline_2026-10-24](pen_offline_2026-10-24/).

- **137/137 test, 11.929 assertions, 14 suite**: mô hình offline, nông trại thật, vòng đời, AI ăn/uống, kinh tế, gói khởi đầu, save repository, mục tiêu, onboarding, đơn hàng, khởi tạo persistence, sản xuất và thời tiết.
- Có đối chiếu 36 con dùng 2.160 đơn vị mỗi loại trong 24 giờ; cả 7 loài trưởng thành cho đúng sản lượng theo chu kỳ thật và tổng tiêu thụ 420 đơn vị mỗi loại/ngày ở fixture trời nắng.
- Kiểm tra cạn máng rồi dùng cơ thể, chia theo đàn, đảo thứ tự thành viên, chia thời gian thành nhiều lần, phần lẻ qua nhiều vòng save/load, trưởng thành, chết, giữ sản phẩm vừa rơi, tuổi thọ trong khoảng dài một năm, không tiêu thụ sau chết và không tính con mới vào quá khứ.
- **46/46 native checks**: phục hồi 12 giờ với 3 bò trưởng thành và 1 bê, cạn thức ăn, mở bảng chuồng thật, thẻ báo tạm dừng đúng bằng EN/VI ở 1024×720 và 844×390. Đã xem ảnh bố cục điện thoại và thanh cuộn.
- Lint toàn dự án 0 lỗi/0 cảnh báo. Engine kiểm tra 19 script thuộc nhóm animals không có lỗi; còn 25 cảnh báo dependency đã có, không có chẩn đoán thuộc hai file offline mới.
- Web Compatibility export thành công. Chưa thử Android/iPhone thật trong lượt này. Các suite ngoài 14 suite nêu trên không được coi là đã xanh toàn dự án.

## Phần tiếp theo

Mẻ mật tổ ong đã hoàn thiện ở lượt sau; xem [honey_batches.md](honey_batches.md). Tiếp theo đo thu nhập theo các lịch đăng nhập, mức dự trữ và phối hợp trồng trọt/chăn nuôi.
