# Kế hoạch: sâu, cỏ dại trên cây ruộng và bệnh ở vật nuôi

Ngày phân tích: 30/10/2026. Người dùng đã yêu cầu triển khai. Cơ chế đã thực hiện và hướng dẫn sử dụng nằm tại [farm_health.md](farm_health.md); phần dưới giữ lại thiết kế và tiêu chí nghiệm thu ban đầu.

## 1. Phạm vi

- Đã chốt với người dùng: cây trên ruộng trước; chưa áp dụng cho hoa, cây ăn quả và cây lấy gỗ.
- Cây có hai cờ độc lập: bị sâu và bị cỏ dại. Có đủ bốn tổ hợp, kể cả cùng tồn tại.
- Vật nuôi có cờ bị bệnh độc lập với chỉ số no/nước, tuổi và trạng thái hành vi. Đói, khát, bệnh có thể cùng tồn tại.
- Các thông số cân bằng bên dưới là đề xuất thử nghiệm, chưa phải yêu cầu đã chốt.
- Đợt đầu không có lây lan, mức độ nặng/nhẹ, cây chết hoặc chết vì bệnh.

## 2. Hiện trạng đã đối chiếu mã

- `components/crop.gd`: tiến độ theo timestamp, bốn giai đoạn; đã có tưới, phân bón, thuốc rễ và phẩm chất. Không gộp sâu/cỏ vào biến stage.
- `components/farming_controller.gd`: `harvest_amount()` đang kết hợp sản lượng giống cây với đất màu mỡ; cả người chơi và worker cần dùng chung kết quả cuối.
- `components/animals/animal_needs_component.gd`: tính khoảng thời gian được cung cấp đủ thức ăn/nước trước khi trừ chỉ số. Hết một trong hai thì không ghi nhận thời gian sản xuất.
- `components/animals/animal_actor.gd`: cắt khoảng thời gian sản xuất theo trưởng thành, tuổi thọ và một số tác động thời tiết.
- `components/animals/animal_production_component.gd`: tích lũy giây tiến độ rồi sinh số nguyên sản phẩm theo lô; có thuốc bổ tăng sản phẩm một chu kỳ.
- `components/animals/pen_offline_model.gd` và `pen_offline_simulation.gd`: mô phỏng theo ranh giới sự kiện, không chạy lại từng frame.
- `components/workers/worker_world_bridge.gd`: đồng bộ thời gian và chọn việc thu hoạch dựa vào sản lượng/sức chứa kho.
- `persistence/world_state_adapter.gd` và `save_schema.gd`: lưu trạng thái cây/vật nuôi; schema hiện tại là v36.
- `project.godot`: cấu hình offline progress hiện là false. Tính năng mới phải đi theo cùng chính sách thời gian, không tự bật tiến trình offline.

Nguồn: graph project `home-dungnguyen-Projects-test-js`, generation được kiểm tra `2026-10-30T01:48:35Z`, trace các đường tính sản lượng, đối chiếu trực tiếp source. Các đường mã liệt kê đã kiểm tra coverage; tín hiệu coverage chỉ là best effort.

## 3. Luật gameplay đề xuất

### Cây trên ruộng

| Tình trạng | Hệ số sản lượng kỳ vọng |
| --- | --- |
| Bình thường | 100% |
| Bị sâu | 80% |
| Bị cỏ dại | 85% |
| Cả hai | 68% = 80% × 85% |

- Tính sản lượng nền sau bonus đất màu mỡ, rồi áp dụng từng hệ số. Phẩm chất Normal/Silver/Gold tiếp tục do cơ chế chăm sóc hiện có quyết định.
- V1 dùng trạng thái tại lúc thu hoạch. Trị sâu/dọn cỏ trước khi thu hoạch sẽ phục hồi hệ số tương ứng, không lưu tổn thất vĩnh viễn trong vụ.
- Cây đã chín vẫn giữ sâu/cỏ cũ cho đến khi xử lý; không phát sinh đợt mới sau khi chín. Cây vẫn có thể thu hoạch khi đang bị ảnh hưởng.
- Phát sinh sâu và cỏ bằng hai lượt kiểm tra độc lập tại các mốc tiến độ, chẳng hạn sâu ở 1/3 và cỏ ở 2/3. Xác suất ban đầu thử nghiệm: mỗi loại 15% mỗi vụ. Mốc/xác suất nằm trong Resource để cân bằng.
- Chuẩn bị và lưu kết quả ngẫu nhiên của vụ ngay lúc trồng. Đi qua một mốc nhiều lần hoặc mở UI không được roll lại. Phân bón làm vượt mốc vẫn phải xử lý đúng một lần.
- Không tái nhiễm cùng loại trong cùng vụ ở V1. Vụ trồng lại có dữ liệu mới.

### Sản lượng lẻ: quyết định bắt buộc

Không dùng `max(1, floor(yield))`: cây có sản lượng nền 1 sẽ hầu như không chịu ảnh hưởng.

Đề xuất làm tròn xác suất nhưng cố định theo vụ: `floor(y) + (roll < phần_lẻ(y) ? 1 : 0)`. `roll` được chuẩn bị từ lúc trồng, lưu cùng cây, và chỉ đọc khi preview/thu hoạch. Ví dụ kỳ vọng 0,68 cho kết quả 0 hoặc 1, trung bình đúng 0,68; đọc tooltip, đổi người thu hoạch hay reload không làm đổi roll. Dùng cùng một roll cho các hệ số để chữa trị không khiến kết quả xấu hơn.

Hệ quả cần chốt trước triển khai: một cây có thể thu được 0 sản phẩm. Thu hoạch 0 vẫn là thao tác thành công, giải phóng cây và báo “Mất mùa do sâu/cỏ”; không đi vào nhánh `accepted == 0` hiện tại rồi giữ cây mãi. Nếu không muốn mất trắng cây sản lượng 1, phải chọn thiết kế khác (ví dụ giảm tốc độ sinh trưởng), không che vấn đề bằng làm tròn tối thiểu 1.

### Vật nuôi

- Bệnh làm tốc độ sản xuất còn 50% trong thời gian bị bệnh; mỗi lô vẫn tạo số nguyên sản phẩm như hiện nay. Chu kỳ 60 giây trở thành 120 giây nếu bệnh suốt chu kỳ và luôn đủ ăn/uống.
- Đủ ăn + đủ nước + bệnh: vẫn sản xuất với tốc độ giảm.
- Đói hoặc khát + bệnh: vẫn giữ cả các tình trạng; sản xuất dừng theo luật hiện tại. Cho ăn/uống không chữa bệnh, thuốc chữa bệnh không hồi no/nước.
- Trị bệnh khôi phục tốc độ từ thời điểm dùng thuốc; không bù sản phẩm cho thời gian bệnh trước đó và không trừ sản phẩm đã hoàn thành.
- V1 đề xuất chỉ phát bệnh ở con trưởng thành, có thời gian bảo vệ sau khi mua/trưởng thành và sau chữa trị. Con non vẫn lớn theo luật cũ.
- Lịch kiểm tra bệnh theo thời gian mô phỏng, không theo frame; thời điểm kiểm tra kế tiếp và trạng thái RNG phải lưu. Có thể tăng nguy cơ khi thiếu ăn/nước nhưng cần playtest thời gian sống thực tế trước khi chọn xác suất.
- Thuốc bổ đang có vẫn tác động vào lô hoàn thành kế tiếp; thuốc chữa bệnh là vật phẩm riêng.

## 4. Chăm sóc và hiển thị

- Dọn cỏ: thao tác nhổ/dọn miễn phí, có animation/thời gian thực hiện ngắn. Không dùng lại thao tác cuốc phá cây mà thiếu phân biệt ngữ cảnh.
- Trị sâu: vật phẩm thuốc trừ sâu; chữa bệnh: thuốc thú y. Mỗi lần xử lý một mục tiêu hợp lệ, tiêu hao một đơn vị tại thời điểm hành động có hiệu lực.
- Kiểm tra còn mục tiêu, đúng tầm/Area theo cơ chế hiện có, đúng tình trạng và còn vật phẩm trước khi commit. Hủy hành động, mục tiêu đã được chữa hoặc load lại không làm mất thuốc/nhân đôi hiệu lực.
- Tích hợp vật phẩm vào catalog cửa hàng, túi đồ và quy tắc Kho hạt giống/vật tư; không mặc định rằng các bộ lọc hiện có đã nhận loại mới.
- Hai icon sâu/cỏ có thể cùng hiện trên cây; bệnh hiện cùng đói/khát trên vật nuôi. Không dùng một nhãn duy nhất khiến các tình trạng che nhau.
- Tooltip cây hiển thị hệ số/thiệt hại kỳ vọng và cách xử lý. Panel vật nuôi hiển thị đủ các lý do, ví dụ “Đói · Khát · Bị bệnh”, kèm tốc độ sản xuất khi đủ điều kiện.
- Cỏ dại trên cây là dữ liệu chăm sóc của cây đó, không dùng chung cỏ trang trí/ô đất chưa khai hoang.
- Art có thể bắt đầu bằng icon placeholder; chưa cần tiêu lượt PixelLab trong giai đoạn phân tích.

## 5. Thiết kế kỹ thuật

- Thêm `CropConditionState` quản lý hai cờ, các mốc đã xử lý, các roll cố định; `AnimalHealthComponent` quản lý bệnh, thời gian bảo vệ và lịch kiểm tra tiếp theo.
- Thêm Resource cấu hình thông số. Các định nghĩa giống cây/loài có thể tham chiếu cấu hình hoặc dùng mặc định; không sửa Resource dùng chung để chứa trạng thái từng cá thể.
- Luật phát sinh, chữa trị và hệ số tách khỏi sprite/UI; phát signal sau khi đổi trạng thái để cập nhật icon, tooltip và lịch worker.
- Một đường tính sản lượng cây dùng chung cho preview, kiểm tra sức chứa, người chơi và worker. Query chỉ đọc sau khi đã đồng bộ thời gian; không roll trong `harvest_amount()`.
- Bệnh được đưa vào pipeline lifecycle dưới dạng thời gian sản xuất hiệu dụng. Chia khoảng thời gian ở các mốc phát bệnh/chữa bệnh/bảo vệ, đồng thời giao với đoạn trưởng thành, còn sống, đủ thức ăn/nước và thời tiết; không nhân hệ số hiện tại cho toàn bộ khoảng quá khứ.
- Scheduler dùng các sự kiện đã định lịch. Không quét mọi cây/vật nuôi mỗi frame, không phát sinh một lượt ngẫu nhiên cho mỗi lần refresh.
- Đồng bộ trạng thái trước capture, thu hoạch, chữa trị và sự kiện worker. Trị bệnh phải chốt phần thời gian cũ trước khi xóa cờ bệnh.
- Khi offline progress tắt, đóng băng/rebase cả lịch bệnh/cỏ/sâu theo cùng đồng hồ của gameplay. Khi bật, xử lý cùng chuỗi sự kiện như chạy online và giữ thứ tự ổn định theo ID.
- Save thêm các cờ, lịch/mốc/RNG/roll cần thiết. Tăng version kế tiếp khi triển khai (v37 nếu schema vẫn ở v36); migration đưa save cũ về khỏe/sạch và có thời gian bảo vệ, không tạo một đợt bệnh ngay lúc nâng cấp.

## 6. Worker và phạm vi tự động hóa

- V1 phải tương thích worker hiện có: dùng cùng sản lượng, xử lý thu hoạch 0, không kẹt claim khi cây thay đổi hoặc bị xóa, tooltip/sức chứa không lệch với kết quả commit.
- Đề xuất tùy chọn “Chờ xử lý sâu/cỏ trước khi thu hoạch” cho worker ruộng, mặc định bật; có chỉ báo đang chờ chăm sóc để người chơi không hiểu nhầm worker bị lỗi. Khi tắt, worker thu hoạch với thiệt hại đúng như người chơi.
- Tự động dọn cỏ/phun thuốc/chữa bệnh là giai đoạn mở rộng riêng: thêm việc vào scheduler, ưu tiên, tồn thuốc và tiêu hao qua cùng API chăm sóc. Không ngầm cấp thuốc miễn phí cho worker.

## 7. Các mốc triển khai

1. **Chốt luật và dữ liệu:** xác nhận làm tròn cho phép sản lượng 0; khóa phạm vi, công thức và cách chăm sóc; viết test trạng thái tổ hợp, hệ số và RNG cố định. Chốt bằng playtest các xác suất, không hard-code vào scene.
2. **Cây ruộng hoàn chỉnh:** state + scheduler + icon + thao tác dọn cỏ/phun thuốc + sản lượng + xử lý thu hoạch 0 + tương thích worker.
3. **Vật nuôi hoàn chỉnh:** bệnh + lịch kiểm tra + thuốc + status panel + tích hợp sản xuất online và mô phỏng theo sự kiện.
4. **Persistence và catch-up:** xây cùng mỗi lát tính năng từ bước 2–3; mốc này hoàn thiện migration, restore, rollback khi save lỗi, chính sách offline và benchmark, trước khi coi tính năng sẵn sàng dùng.
5. **Cân bằng và nghiệm thu:** chạy trên scene thật, chuột/phím/mobile nếu hỗ trợ; kiểm tra ruộng lớn/đàn lớn; cập nhật hướng dẫn chơi và bản dịch.

## 8. Tiêu chí nghiệm thu

- Đủ bốn tổ hợp trên cây và tám tổ hợp đói/khát/bệnh ở con trưởng thành; chữa một tình trạng không xóa tình trạng khác.
- Sâu/cỏ và phẩm chất/phân bón/đất màu mỡ kết hợp đúng; không sửa bonus cũ ngoài công thức mới đã chốt.
- Thu hoạch thủ công/worker cho cùng kết quả; sản lượng 0 kết thúc vụ đúng một lần; thiếu sức chứa không xóa cây hoặc đổi roll.
- Preview/refresh/reload không đổi kết quả ngẫu nhiên; nhiều tick nhỏ và một lần catch-up cho cùng kết quả nếu cùng chuỗi sự kiện/cấu hình thời gian.
- Phát bệnh/chữa bệnh giữa chu kỳ, vượt trưởng thành/chết, đói/khát giữa đoạn mô phỏng, hết nước trong mưa/nắng đều tính đúng khoảng hiệu dụng.
- Thuốc bổ không bị tiêu hai lần; bệnh không xóa sản phẩm đã sinh hoặc tạo sản phẩm sau khi con vật chết.
- Migration save cũ giữ inventory, phẩm chất, tiến độ và sản phẩm; save mới round-trip các cờ/mốc/RNG; dữ liệu lỗi bị từ chối trước khi thay world.
- Khi offline tắt, không tự phát sinh sâu/cỏ/bệnh chỉ vì đóng game lâu.
- Có kiểm thử thao tác chăm sóc thành công, hủy, ngoài tầm, sai mục tiêu, hết thuốc và worker cạnh tranh cùng mục tiêu.
- Không có hồi quy hiệu năng do quét mỗi frame; gameplay log của các luồng thay đổi không có error/warning mới.

## 9. Quyết định còn mở

Quan trọng nhất: có chấp nhận cây sản lượng nền 1 đôi khi mất trắng khi bị ảnh hưởng không? Đề xuất hiện tại là có, kèm thông báo rõ và quyền chữa trước thu hoạch để tránh mất sản phẩm. Nếu không chấp nhận, cần đổi cơ chế giảm sản lượng cây trước khi viết pipeline thu hoạch.

Các điểm còn lại có thể hiệu chỉnh qua Resource/playtest: xác suất phát sinh, hệ số, giá thuốc, thời gian hành động, thời gian bảo vệ và worker chờ chăm sóc mặc định.
