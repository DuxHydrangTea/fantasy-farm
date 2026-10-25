# Kế hoạch kho nông sản và kho vật tư dùng chung

Ngày lập: 25/10/2026. **Trạng thái: S0–S5 đã triển khai; luồng kho v1 dùng save v25.** Triển khai lần lượt từng mốc; hoàn thành và chơi thử mốc đang chọn trước khi chuyển tiếp.

## 1. Mục tiêu và hiện trạng

Hai công trình người chơi vừa đặt trong MainWorld:

| Node hiện tại | Vị trí | Đề xuất tên code | Tên trong game |
|---|---|---|---|
| Warehouse | (932, 199) | ProduceWarehouse | Kho nông sản |
| SeedInventory | (1047, 199), variant 5 | FarmSupplyStorage | Kho vật tư |

Cả hai đang là instance của scene Barn. Giữ hình ảnh, màu và vị trí người chơi đã bố trí. Rà tham chiếu trước khi đổi tên; dùng component tương tác hoặc scene kế thừa để giữ script chọn variant của công trình.

Code hiện tại: worker thu vào giỏ 16 slot, stack tối đa 100; Ranch lấy feed từ giỏ; player gieo từ stack hạt đang chọn trên hotbar; save schema v23. Worker Crop chỉ tưới/thu/gom, không tự cuốc/gieo.

Luồng đích:

```
Túi player → gửi hạt/feed → Kho vật tư → gieo cây / tiếp thức ăn
Worker thu hoạch hoặc gom sản phẩm → Kho nông sản → player rút về túi
```

Sản phẩm worker chuyển vào kho ngay khi commit thành công. **V1 không thêm chuyến vận chuyển tới nhà kho.** Worker vẫn đi tới cây/máng/pickup và trả đủ thời gian làm việc như hiện tại.

## 2. Quy tắc đề xuất cho v1

| Hạng mục | Quy tắc |
|---|---|
| Kho nông sản nhận | ItemType.PRODUCE: rau củ, trái, sản phẩm vật nuôi, gỗ, mật và món nấu có thể gửi thủ công |
| Kho vật tư nhận | Hạt cây trồng có CropDefinition và item FEED |
| Ngoài phạm vi v1 | Hạt hoa, cây giống lâu năm, phân/tonic, tool và công trình đặt được; tiếp tục dùng túi và luồng hiện tại |
| Nguồn gieo/cho ăn khi tích hợp xong | Kho vật tư; không âm thầm fallback sang túi player/giỏ worker |
| Người chơi tương tác kho | Đến gần, E/click hoặc nút tương tác cảm ứng; gửi/rút phải ở gần công trình |
| Worker sử dụng kho | Dùng nguồn/đích chung từ xa theo chính sách v1, không phải đi lấy/giao hàng |
| Thu hoạch thủ công của player | Vẫn vào túi; muốn cất thì gửi tại kho |
| Chef và tổ ong | Giữ cách nhận hiện có; người chơi có thể gửi thành phẩm vào kho, chưa tự nối đầu ra |
| Nước | Giữ nguồn nước miễn phí/bình tưới hiện tại; không thêm item nước vào kho |
| Kho đầy | Ngừng nhiệm vụ thu tương ứng; worker vẫn làm được việc khác như tưới/tiếp máng |
| Thiếu feed/hạt | Không tiêu hao và không tạo kết quả; báo rõ loại vật tư thiếu |
| Bán hàng | Không tự bán từ kho; rút về túi rồi bán như hiện tại |

Sức chứa là cấu hình độc lập, có giới hạn, tái dùng InventoryComponent. **Đề xuất thử ban đầu:** kho nông sản 128 slot, kho vật tư 64 slot, stack theo ItemDefinition. Các số này chưa phải cân bằng cuối; mốc S5 phải đo vì bỏ giới hạn giỏ worker sẽ làm sản lượng tự động tăng mạnh.

Cấu hình mặc định áp cho profile mới. Nếu thay đổi sức chứa sau khi đã có save, cần migration rõ ràng; không cắt slot/stack đang chứa đồ. Chưa có nâng cấp kho trong v1.

## 3. Lộ trình triển khai

### S0 — Chốt hợp đồng dữ liệu và tương tác (đã hoàn thành)

- Rà hai node, lối tiếp cận, script variant, collision và tham chiếu tên.
- Chốt ID bền vững `produce_warehouse` / `farm_supply_storage`, độc lập tên node.
- Đặt filter vật phẩm và cấu hình sức chứa trong dữ liệu, tránh phân loại theo tên item.
- Xác định một dịch vụ giao dịch chung cho gửi/rút, nhập sản phẩm và tiêu thụ vật tư.

**Kết quả:** cấu trúc rõ ràng để S1 làm đúng, chưa đổi gameplay hay save cá nhân.

### S1 — Hai kho gửi/rút thủ công, có lưu game (đã hoàn thành)

Xem [hướng dẫn và kiểm chứng S1](farm_storage_s1.md). Giữ tên node do người dùng đặt, dùng ID kho để định danh.

Đây là **mốc chơi thử đầu tiên**, gồm model + giao diện + persistence trong cùng phần bàn giao.

- Tạo state/service kho, tham chiếu từ FarmWorld; không gắn logic lưu vào sprite công trình.
- Giữ visual của hai building, thêm điểm tương tác ở cửa và tên kho rõ ràng.
- Mở panel hai phía: túi player và kho, có icon, số lượng, sức chứa, cuộn nội dung.
- Chọn vật phẩm và số lượng; có gửi/rút một phần và gửi/rút tất cả phù hợp.
- Khóa vật phẩm sai nhóm bằng phản hồi rõ; không xóa item không chứa được.
- Transaction kiểm tra lại nguồn, đích và capacity lúc bấm; khóa tái nhập qua signal, commit dữ liệu trước thông báo UI.
- Save **v24** thêm hai kho. Migration v23 → v24 khởi tạo kho rỗng, giữ nguyên túi, giỏ worker, xu, cooking, nông cụ và tiến trình khác.
- Hai kho được restore trước các hệ thống có thể dùng chúng. Mốc này worker vẫn dùng giỏ, gieo/cho ăn vẫn dùng luồng cũ.

**Nghiệm thu:** player gửi/rút đúng số lượng ở cả hai kho, thiếu chỗ giữ phần dư; mở lại game thấy đúng đồ. UI dùng được ở PC và cảm ứng.

### S2 — Worker đưa nông sản thẳng vào Warehouse (đã hoàn thành)

Xem [hướng dẫn và kiểm chứng S2](farm_storage_s2.md). Schema vẫn v24; hình dạng dữ liệu không đổi.

- Tách rõ `output_inventory` khỏi `feed_inventory`; tránh đổi một biến giỏ rồi vô tình cho Ranch ăn nông sản trong kho.
- Crop, Orchard và Ranch gom WORLD_DROP đều dùng kho nông sản làm đích.
- Candidate scan và commit cùng kiểm tra capacity kho. Worker khác/player có thể thay đổi kho giữa hai bước, nên luôn kiểm tra lại khi commit.
- Cây/crop thu nguyên đợt: không đủ cho cả yield thì giữ nguyên cây/sản phẩm. Ví dụ đợt 300 quả không được xóa cây rồi chỉ nhận 100.
- Pickup được chuyển phần thực nhận; phần dư còn trên đất theo API hiện tại.
- Không đặt hàng vào giỏ worker mới rồi chuyển lần hai: đích giao dịch là Warehouse ngay từ đầu.
- Đổi badge/panel worker để nói rõ sản phẩm về kho; giữ trạng thái việc/kho đầy. Hiệu ứng thu hoạch không được báo đồ vào túi player khi thực tế vào kho.
- Di trú PRODUCE trong giỏ worker cũ vào kho theo sức chứa. Phần chưa chuyển được vẫn ở giỏ cũ và có nút nhận lại; không mất đồ, không gửi trùng khi load lại.
- Kho đổi sức chứa khả dụng thì đánh thức worker đang chờ; không quét toàn map mỗi frame.

**Nghiệm thu:** ba vai thu/gom vào đúng một kho chung, giỏ cũ không mất hàng. Kho đầy thì nguồn nguyên vẹn, rút bớt thì worker làm tiếp. Kiểm tra luôn online/offline và save dở tại mốc này.

### S3 — Ranch và thao tác cho ăn lấy feed từ kho vật tư (đã hoàn thành)

Xem [hướng dẫn S3–S5](farm_storage_s3_s5.md).

- Ranch chọn feed đúng item mà máng yêu cầu từ kho vật tư; không mua feed tự động.
- Player tiếp thức ăn bằng luồng tương tác hiện có cũng đọc nguồn kho vật tư; UI hiển thị lượng trong kho và lỗi thiếu loại feed.
- Không tự fallback sang giỏ/túi để tránh số dư kho hiển thị sai với lượng thực sự tiêu thụ.
- Đồng bộ mô phỏng chuồng trước khi thay đổi máng. Chỉ trừ số gói thực sự nạp được, giữ semantics gói nguyên và reserve đang có.
- Gỡ nạp feed mới vào giỏ worker. Bảng worker hiển thị nguồn chung và hướng người chơi bổ sung ở kho.
- Di chuyển feed còn trong giỏ cũ sang kho theo capacity; phần dư được giữ và rút lại bằng lệnh tương thích, không xóa khi sa thải/load.
- Nguồn nước và lượt mang nước của Ranch giữ nguyên.
- Stock thay đổi làm worker đang thiếu feed xét việc lại; không tạo nhiệm vụ tiêu hao giả khi kho vẫn thiếu.

**Nghiệm thu:** worker/player tiếp máng đều trừ đúng feed trong kho, không đụng loại sai; hai máng hoặc hai thao tác không dùng trùng gói cuối. Thiếu kho thì dừng an toàn.

### S4 — Player chọn và gieo hạt từ kho, hỗ trợ 1×1 đến 6×6 (đã hoàn thành)

Đây là phần riêng vì hiện code đang gắn hành động gieo với một slot inventory thật.

- Thêm bộ chọn giống/Gieo từ kho: liệt kê giống hợp lệ, icon và lượng khả dụng trong kho.
- **Tách việc chọn loại hạt khỏi việc sở hữu stack trên hotbar.** Gửi hết hạt vào kho vẫn chọn và gieo được; không yêu cầu giữ một hạt làm token.
- Chọn nông cụ/hotbar khác thì thoát chế độ gieo từ kho, tránh vô tình gieo khi muốn cuốc/tưới.
- Giữ vùng theo hướng nhìn và cấp nông cụ hiện tại. Preview dùng lượng khả dụng thực tế của kho, không dùng count cũ trong túi.
- Khóa seed ID/nguồn/phạm vi cho động tác; kiểm tra lại nguồn và ô ở impact. Đổi giống hoặc mở menu trước impact hủy thao tác như hiện tại.
- Gieo một hạt cho mỗi ô thành công, bỏ qua ô sai. Có 5 hạt với 36 ô hợp lệ thì chỉ gieo 5; không âm số lượng hoặc tạo cây miễn phí.
- Nếu vật tư bị rút trước impact thì dùng lượng còn hợp lệ theo quy tắc đã chốt, không hoàn tác các thao tác khác của người chơi.
- Lưu giống đang chọn nếu hợp lệ. Nếu v24 đã phát hành ở S1, trạng thái bền vững mới này dùng migration **v24 → v25**; không sửa ngược ý nghĩa v24.
- Hạt hoa/cây lâu năm ngoài phạm vi gieo từ kho v1; giữ luồng túi hiện có cho chúng.

**Nghiệm thu:** gieo từ kho được khi túi không có hạt; đúng vùng 1/4/9/16/25/36 ô, trừ đúng số cây tạo ra, chọn giống và load lại ổn định trên PC/touch.

**Không tự mở rộng Crop worker sang cuốc/gieo.** Việc đó là giai đoạn sau, cần chỉ định giống, vùng và quy tắc trồng lại.

### S5 — Kiểm thử xuyên suốt, offline và cân bằng bước đầu (đã hoàn thành)

- So chạy liên tục và catch-up chia đoạn/nhảy một lần ở 24–48 giờ cho cả ba vai.
- Các biên bắt buộc: kho sản phẩm đầy, kho vật tư hết, máng cạn, sản phẩm chín, bình minh thiếu lương và giao dịch ngay lúc đang lưu.
- Cùng timestamp có nhiều yêu cầu: thứ tự xử lý ổn định; không để hai worker cùng tin rằng còn chỗ cho đợt cuối.
- Load lặp không nhân sản phẩm hoặc tiêu thụ lặp. Save khi đang có animation gieo không ghi trạng thái nửa giao dịch.
- Hồi quy hai kho với farming, nông cụ 6×6, worker, máng, Chef, mục tiêu và persistence.
- Native QA click/ScreenTouch ở desktop và 844×390; build Web. Ghi rõ phần chưa thử trên điện thoại thật/trình duyệt.
- Đo CPU catch-up, số giao dịch, số lượng sản phẩm, stock cuối và lương. So với baseline worker v1 bị giới hạn bởi giỏ; không dùng baseline cũ để khẳng định kinh tế sau nối kho đã cân bằng.
- Nếu cần chỉnh slot/stack/lương, ghi rõ thông số và đường migration cho save có hàng; không giảm sức chứa gây mất đồ.

**Nghiệm thu:** luồng hoàn chỉnh túi → kho vật tư → gieo/tiếp máng → worker thu → kho nông sản → rút túi bảo toàn số lượng ở cả online/offline.

## 4. Các bất biến cần giữ xuyên suốt

1. Chuyển giữa hai nơi: nguồn giảm đúng lượng đích tăng. Thu hoạch: đầu ra cộng đúng lượng nguồn đã được thu. Tiêu thụ: chỉ trừ vật tư cho hành động thành công.
2. Không có hai bản tồn kho để trừ độc lập; UI chỉ đọc model, không dùng số lượng hiển thị cũ làm sự thật.
3. Không mất đồ khi kho/túi đầy, đổi scene, đóng menu, tạm nghỉ/sa thải hoặc migration.
4. Các transaction phải khóa qua thông báo observer. Không gọi `worker.advance` lồng trong callback kho đổi số lượng.
5. Player gửi/rút feed phải settle worker đến mốc hiện tại trước khi đổi stock, để feed mới không nuôi ngược khoảng offline đã qua.
6. Trình tự restore: kho → trạng thái world/chuồng/worker tại checkpoint → xử lý đồ giỏ cũ → catch-up theo timeline → mở lại input.
7. Mọi thay đổi đều kiểm thử với userdata/bản sao riêng; không reset save cá nhân để chạy QA.

## 5. Thứ tự làm việc đã đề xuất

**S0 + S1 → S2 → S3 → S4 → S5.** S0 được thực hiện cùng lượt chuẩn bị S1, không cần một lần bàn giao chỉ có đổi tên node.

Mỗi mốc bàn giao gồm: code chơi được, cách thử ngắn, kết quả kiểm thử và cập nhật tài liệu. Persistence và tính đúng online/offline phải đi cùng phần thay đổi gameplay tương ứng; S5 là kiểm tra xuyên suốt, không phải lúc mới bắt đầu sửa offline.

Hiện đã hoàn thành S0–S5. Phạm vi kiểm chứng và các fixture cũ cần cập nhật được ghi trong tài liệu S3–S5.
