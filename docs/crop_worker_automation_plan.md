# Kế hoạch Crop worker v2 — tự cuốc, lấy hạt bất kỳ, gieo lại và bón phân

Ngày cập nhật: 25/10/2026. **Trạng thái: W0–W5 đã triển khai và kiểm chứng; save v26.**

Hướng dẫn hiện hành và kết quả: [Crop worker v2](crop_worker_automation.md). Các mục dưới lưu thiết kế đã thống nhất; cấu trúc DTO thực tế nằm trong `CropAutomationState.capture()`.

## 1. Yêu cầu đã được người chơi làm rõ

Worker tự dùng hạt giống có sẵn trong kho vật tư. Người chơi **không cần chọn giống, gán giống cho từng vùng, vẽ vùng hay đặt hạn mức mỗi ngày** để worker bắt đầu trồng. Miễn còn ô đất hợp lệ trong phần ruộng đã mở và còn hạt cây trồng trong kho, worker có thể tự chuẩn bị đất và gieo.

Mỗi ô gieo thành công tiêu **đúng một hạt**. Cuốc và gieo là hai bước có thời gian riêng nhưng không trừ hạt hai lần: cuốc không mất hạt; hạt được trừ ở commit gieo thành công. Nếu cuốc xong rồi thiếu hạt/bị ngắt, giữ đất đã cuốc và chưa trừ hạt.

Bản này **thay thế** đề xuất trước về một vùng/một giống, giới hạn vùng 144 ô và quota vật tư theo ngày. Không triển khai UI chọn vùng, UI chọn giống worker hoặc hạn mức trong lượt v2 này.

## 2. Vòng chơi

1. Player gửi các loại hạt cây trồng vào kho vật tư như hiện tại.
2. Crop worker tự tìm ô có thể trồng trên ruộng đã mở.
3. Ô chưa cuốc thì cuốc; ô đã cuốc thì đi thẳng tới bước gieo.
4. Worker tự lấy một loại hạt hợp lệ đang còn trong kho và gieo một cây, trừ một hạt.
5. Tiếp tục tưới, bón nếu chế độ bón được bật và đủ điều kiện, rồi thu nông sản vào Warehouse.
6. Khi ô trống trở lại, tiếp tục gieo bằng hạt hợp lệ đang còn. Giống ở vụ sau có thể khác vụ trước.

Một người Crop vẫn làm từng ô; không hưởng vùng 6×6 của nông cụ player. Nước tưới giữ cơ chế miễn phí. Không tự mua hạt/phân hoặc tự bán nông sản để lấy tiền lương.

## 3. Phạm vi đất

- Dùng toàn bộ phần farmland **đã mở** theo LandExpansionState, tương tự phạm vi chăm/thu hiện tại.
- Không mở đất thay player, không trồng vào đường, khu cây ăn quả, chậu hoa, công trình hoặc ô bị chặn.
- Luôn kiểm tra API `can_till`/`can_plant` với actor worker; tọa độ nằm trong REGION chưa đủ để coi là trồng được.
- Mở thêm cột đất thì worker tự xét phần mới; không cần sửa cấu hình vùng.
- Không phá cây sẵn có, kể cả cây khác giống/player gieo. Chăm và thu như hiện tại; chỉ gieo khi ô thực sự trống.
- Không thêm Node/Area2D cho mỗi ô và không cần chế độ chọn vùng trên touch.

## 4. Tự lấy hạt — quy tắc đơn giản, ổn định

Kho vật tư có cả feed nên phải lọc đúng `ItemType.SEED` có `CropDefinition` hợp lệ và số lượng >0. Không coi FEED, phân, tonic, hạt hoa hoặc cây giống lâu năm là hạt trồng ruộng.

**Đề xuất lấy loại hạt hợp lệ xuất hiện trước trong thứ tự slot của kho.** Khi loại đó hết, tự chuyển sang loại hợp lệ tiếp theo. Không chọn theo giá/lợi nhuận, không yêu cầu người chơi sắp giống theo vùng, không phụ thuộc giống đang chọn bằng G.

Đây là thứ tự kỹ thuật để online/offline và load cho kết quả ổn định; không phải bảng ưu tiên giống cần người chơi cấu hình. Cùng một loại nằm nhiều stack được tính theo tổng tồn kho.

Task gieo chốt `seed_item_id` khi bắt đầu. Trước commit vẫn kiểm tra lại stock và ô. Nếu hạt đó đã bị rút hết, hủy lượt gieo chưa thành công rồi lập lượt mới với hạt còn lại; không trừ nhầm item khác trong slot đã đổi và không tạo cây miễn phí. Ô đất đã cuốc tiếp tục được dùng, không phải cuốc lại.

Không giữ hạt trong giỏ worker, không dự trữ/trừ hạt ngay khi chọn việc, không dùng túi player làm nguồn dự phòng.

## 5. Cuốc–gieo và luân phiên ô

Ưu tiên gieo ô đã chuẩn bị trước khi tiếp tục cuốc ô mới. Trước khi cuốc cũng kiểm tra có ít nhất một hạt cây trồng trong kho. Khi hết hạt, dừng cuốc/gieo nhưng vẫn tưới/thu/gom.

Giữ tối đa một ô worker đang chuẩn bị dở để tránh cuốc hàng loạt khi không gieo tiếp được. Nếu ô đó bị player trồng hoặc trở nên không hợp lệ, bỏ trạng thái dở sau kiểm tra, không nhổ cây/khôi phục terrain cũ.

Cần tránh worker chỉ thu–trồng lại vài ô gần mình trong khi phần ruộng xa không bao giờ được trồng. Dùng dấu lượt gieo/cursor ổn định: ô chưa được gieo bởi worker ưu tiên trước, rồi tới ô có lượt gieo cũ nhất, sau đó mới xét khoảng cách/ID ô. Dữ liệu chỉ giới hạn theo số ô của REGION, không tăng vô hạn theo số vụ.

Nguồn hạt hữu hạn là giới hạn tiêu hao tự nhiên. Không thêm quota ngày, số vụ/ngày hoặc reset ngân sách khi thuê lại.

## 6. Chọn việc

| Thứ tự | Công việc | Điều kiện |
|---:|---|---|
| 0 | Thu hoạch cây chín | Kho chứa được cả đợt sản phẩm |
| 1 | Tưới cây bị khô | Theo API tưới hiện có |
| 2 | Bón phân | Được bật, cây hợp lệ, dưới 50%, chưa bón, còn phân |
| 3 | Gom sản phẩm rơi | Chỉ chuyển phần Warehouse nhận được |
| 4 | Gieo ô đã cuốc | Tự trồng bật, ô trống hợp lệ, có hạt trong kho |
| 5 | Cuốc ô chưa chuẩn bị | Có hạt để gieo, không tạo thêm nhiều ô đang chuẩn bị dở |
| 9 | Chờ/đi tuần | Chưa có việc hợp lệ |

Mỗi bước trả đủ travel + thời gian làm hiện tại (mặc định 2 giây). Ưu tiên công việc bảo toàn cây/sản phẩm trước mở rộng gieo trồng. Không hứa trồng phủ toàn ruộng ngay lập tức khi số cây vượt công suất một worker.

**Warehouse đầy chỉ chặn thu/gom theo sức chứa.** Cây chín giữ nguyên, không bị xóa. Worker vẫn tưới, bón hợp lệ và có thể gieo trên ô trống bằng hạt còn trong kho theo yêu cầu tự động; không âm thầm thêm điều kiện phải giữ chỗ cho sản phẩm tương lai. UI hiện lý do chờ kho đối với việc thu.

## 7. Bón phân

Giữ yêu cầu bón phân từ plan trước nhưng không cần gán giống/vùng hoặc quota:

- Có nút bật/tắt tự bón; đề xuất tắt mặc định để người chơi chủ động tiêu phân.
- Nguồn là kho vật tư. Mở filter cho đúng `BOOSTER + FERTILIZER`, vẫn từ chối tonic và booster khác.
- Dùng loại phân hợp lệ còn hàng trong kho theo thứ tự slot, không yêu cầu cấu hình loại phân nếu catalog hiện chỉ có một loại.
- Một lần/cây, chỉ khi tăng trưởng dưới 50%; tái dùng API hiện tại giảm 20% thời gian, không chép công thức mới vào worker.
- Tự bón trước mắt chỉ áp dụng cây do worker gieo, không tự dùng phân lên cây player gieo. Ghi nhận lứa bằng cell + crop_id + planted_at để không bón nhầm khi player trồng cây mới vào cùng ô.
- Hết phân hoặc đến nơi đã lỡ cửa sổ thì bỏ lượt bón, không trừ phân, không chặn cuốc/gieo/tưới/thu.
- Player bón phân giữ luồng túi hiện tại; nếu đổi cả player sang kho phải là thay đổi riêng.

Theo catalog hiện tại phân `crop_fertilizer` giá 5 xu; cà rốt có thời gian gốc 60 giây nên giảm tối đa 12 giây tăng trưởng, trong khi bón vẫn tốn thời gian đi/làm. Tự bón không bảo đảm tăng lợi nhuận cho mọi giống; sẽ đo trước khi đổi giá/lương.

## 8. Điều khiển và tương tác player

UI Crop được đơn giản hóa còn:

- **Tự cuốc và gieo lại**: bật/tắt. Với người mới thuê, đề xuất bật để chỉ cần có hạt trong kho là làm; có thể tắt để giữ chế độ chăm/thu.
- **Tự bón phân**: bật/tắt, mặc định tắt.
- **Tạm dừng / Tiếp tục** toàn bộ việc của Crop; tạm dừng không tự miễn lương của hợp đồng.
- Thông tin hạt/phân trong kho, việc đang làm và lý do chờ (hết hạt, kho đầy cho thu hoạch, chưa đến được ô, thiếu lương…).

Không có chọn giống, chọn vùng hay bộ đếm quota ngày. Player chọn giống bằng G vẫn chỉ điều khiển lượt gieo của player.

Player được cuốc/gieo/tưới/thu/bón hoặc rút vật tư bất kỳ lúc nào. Worker kiểm tra lại trước commit; mục tiêu đã xử lý thì bỏ, không lặp phần thưởng. Không hoàn tác việc player đã làm và không phá cây để lấy lại vùng.

Tắt tự trồng thì dừng nhiệm vụ cuốc/gieo chưa commit, giữ đất/cây đã tạo, tiếp tục chăm/thu. Pause/resume giữ phần thời gian làm còn lại; thời gian nghỉ không được tính thành công việc.

## 9. API và khóa giao dịch

Hiện `FarmStorageService.plant_from_storage()` là lệnh player, kiểm tra giống/revision của player. Worker cần lệnh riêng, không giả lập hotbar, không đổi lựa chọn G.

Lệnh worker phải kiểm tra role/hợp đồng, cờ bật/tạm dừng, task, cell, vật tư và thời điểm. Dùng actor worker cho va chạm; gieo qua `FarmingController.apply_area` với một ô và nguồn kho; bón qua logic fertilizer hiện có.

Giữ khóa worker/kho/farming qua thông báo. Chỉ trừ đúng một hạt hoặc một phân khi hành động đó thành công. Nếu dựng trạng thái mới thất bại, trả phần đã trừ im lặng trước khi phát signal. Không để callback tạo cây/lợi ích trước rồi tiêu đồ hai lần.

Không gọi settle lồng trong callback. Thay đổi cờ tự động phải settle tới hiện tại theo cờ cũ rồi mới áp dụng, không cho cấu hình mới hoạt động hồi tố trong thời gian offline đã qua.

## 10. Save v26

Hiện schema v25. Đề xuất `workers.crop_automation` với các trường tối thiểu:

```text
revision
auto_plant_enabled
auto_fertilize_enabled
manually_paused
prepared_cell: null hoặc [x, y]
plot_history/cursor: dữ liệu hữu hạn theo REGION
managed_crops: token lứa cây để quyết định tự bón
```

Task mới: `till`, `plant`, `fertilize`; lưu cell, seed/fertilizer ID đã chốt và token lứa khi cần. Không lưu zone/seed assignment hoặc quota vì đã bỏ khỏi yêu cầu. Không chép tồn kho vào task/model.

Migration v25 → v26 giữ nguyên kho/túi/giỏ/xu/lương/hợp đồng/đất/cây/Chef/nông cụ và giống G của player. Đề xuất giữ cờ tự trồng tắt cho Crop đã có trong save cũ để không tự tiêu kho sau cập nhật; bảng worker có nút bật một lần. Worker thuê mới mặc định tự trồng bật. Cách bật cho save cũ cần được nói rõ lúc bàn giao, không tạo các bước chọn giống/vùng.

Giữ task chăm/thu dở của v1, không reset hoặc tính lại phí thời gian đã đi. Validate cell và vị trí theo land_columns trong save; metadata lứa phải thuộc REGION và đúng kiểu. Snapshot trước gieo/bón chưa commit không tiêu đồ trước; load lặp không nhân cây hoặc trừ thêm hạt/phân.

## 11. Offline và hiệu năng

Phạm vi có thể đạt toàn bộ REGION 48×34 = 1.632 ô, lớn hơn vùng 144 ô trong đề xuất đã bỏ. Do đó không quét 1.632 ô mỗi frame hoặc sinh node quản lý cho từng ô.

- Dùng timeline rời rạc của WorkerService cho cả cuốc/gieo/bón; không thêm offline simulator riêng.
- Cache nền/đất mở và cập nhật tập ô trống/đã chuẩn bị qua sự kiện; đọc lại stock và trạng thái thực trước commit.
- Wake theo kho thay đổi, soil/crop thay đổi, growth, moisture, mở đất, cờ tự động và bình minh/lương.
- Bón thay deadline phải cập nhật growth schedule và next wake ngay, không đợi mốc chín cũ.
- Không rút gọn hàng nghìn vụ thành doanh thu trung bình hoặc bỏ sự kiện rồi đánh dấu đã catch-up xong.
- Đo 24/48 giờ với vùng mở lớn, giống mọc nhanh, hỗn hợp giống, hết hạt, thiếu phân, kho đầy, ong/mưa và thiếu lương. Nếu quá chậm, tối ưu indexing/event scheduling trước khi nghĩ tới giới hạn gameplay mới; không tự thêm quota trái yêu cầu.
- Kiểm tra online với vật cản; offline logic chia đoạn phải nhất quán nhưng không hứa va chạm vật lý giống từng frame.

## 12. Lộ trình mới

| Mốc | Nội dung | Nghiệm thu |
|---|---|---|
| **W0** | Model cờ tự động, policy lấy hạt bất kỳ và luân phiên ô | Test lọc hạt, chọn nguồn ổn định, không có cấu hình giống/vùng/quota |
| **W1** | UI tối giản và save v26 | Bật/tắt/pause–save–load đúng; giữ hành vi cũ cho profile cũ |
| **W2** | Cuốc và gieo từ kho | Worker đi và làm thật; mỗi ô thành công chỉ trừ một hạt, cuốc riêng không tiêu hạt |
| **W3** | Trồng lại, đổi tự động sang hạt còn lại và offline | Thu xong trồng tiếp; hết loại A tự dùng B; không chỉ lặp ô gần nhất |
| **W4** | Bón từ kho và filter phân | Một lần/cây, dưới 50%, lỡ điều kiện không mất phân, không bón nhầm lứa |
| **W5** | Hồi quy ba vai/player/kho/save, đo hiệu năng và kinh tế | Test/ảnh/log/benchmark/build; ghi giới hạn thiết bị và fixture lịch sử |

Persistence và khóa giao dịch đi cùng từng mốc; không chờ W5 mới sửa offline hoặc bảo toàn đồ.

## 13. Ca kiểm thử bắt buộc

1. Có hạt và ô trống: worker tự làm mà không chọn giống/vùng. Hạt chỉ có trong túi không được dùng thay kho.
2. Kho hỗn hợp seed/feed/phân: chỉ lấy hạt CropDefinition để gieo; hạt hoa/cây lâu năm không bị lấy nhầm.
3. Loại A hết → chuyển B; stack A bị chuyển slot/rút trước impact không trừ nhầm đồ hoặc tạo cây miễn phí.
4. Một hạt cuối: cuốc rồi gieo chỉ trừ một; hết hạt sau cuốc giữ đất chuẩn bị, không cuốc hàng loạt vô ích.
5. Player trồng/thu/đặt vật cản trước worker commit: kiểm tra lại, không xóa cây hoặc nhân kết quả.
6. Mở thêm đất thì worker xét phần mới; đất khóa/đường/khu cây không bị cuốc. Nhiều ô và cây mọc nhanh không làm bỏ quên toàn bộ ô xa.
7. Thu được cả yield mới xóa cây; kho đầy giữ cây, vẫn chăm/gieo ô khác theo điều kiện. Rút kho làm worker xét việc thu lại.
8. Phân trước/đúng/sau 50%, đã bón, hết phân, player thay cây trong cùng ô; không trừ khi thất bại, không bón nhầm lứa/player.
9. Bón cùng ong, đất khô và mưa; deadline, lịch tăng trưởng và offline tuân đúng API hiện hành.
10. Tắt/pause/sa thải/hết lương sát impact, đổi trạng thái sát bình minh; giữ công việc dở, không cộng thời gian nghỉ.
11. Save trước/sau từng bước, load lặp, callback tái nhập: bảo toàn cây/hạt/phân/nông sản. Giống G của player không bị đổi.
12. So 24/48 giờ một lần với chia đoạn; thử ruộng lớn, nhiều giống, nguồn hữu hạn/hết nguồn, kho đầy và thiếu lương; đo CPU và số giao dịch.
13. Native PC/touch với UI chỉ bật/tắt: gửi hạt vào kho → worker cuốc/gieo → chăm/thu → tự gieo tiếp → xem sản phẩm trong Warehouse; không dùng save cá nhân để QA.

Đã triển khai runtime, UI, save v26 và kiểm thử. Không sửa save cá nhân hoặc giá/lương. W0–W5 hoàn thành trong phạm vi tính năng; số đo hiện tại dùng nguồn hữu hạn, cân bằng kinh tế dài hạn tiếp tục theo dõi.
