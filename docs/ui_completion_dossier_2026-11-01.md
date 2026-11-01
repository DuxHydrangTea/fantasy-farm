# Hồ sơ hoàn thiện UI — Fantasy Farm

Ngày: 01/11/2026 · Trạng thái: đề xuất thiết kế và kế hoạch triển khai, chưa thay đổi gameplay/UI.

## 1. Kết luận thiết kế

Mục tiêu là giao diện nông trại pixel ấm áp, đọc nhanh, giúp người chơi biết **đang chọn gì, làm được gì, việc gì cần chú ý** mà vẫn nhìn rõ thế giới.

Ưu tiên đầu tiên: tổ chức lại HUD, chuẩn hóa chữ/nút/khung, làm rõ thao tác và phản hồi. Giữ bảng màu kem–nâu, hình ảnh vật phẩm và phong cách pixel đang có. Chưa cần vẽ lại toàn bộ tài nguyên.

Hồ sơ lấy desktop chuột/bàn phím làm phạm vi chính. Dự án có hỗ trợ touch nên thay đổi nền tảng phải giữ tương thích; thiết kế mobile riêng nằm ở đợt sau. Các mức P0/P1/P2 dưới đây thuộc **đợt hoàn thiện UI này**, không phải backlog tối ưu worker trước đó.

## 2. Cơ sở và giới hạn đánh giá

- Quan sát trực tiếp ảnh người dùng gửi: HUD gameplay, thanh công cụ, nhiệm vụ, đồng hồ, tiền, thông báo lưu và thông tin trong thế giới.
- Đã đọc cấu hình viewport 1920×1080, `canvas_items`, theme chung, theme Cozy HUD, font, cơ chế UI scale, hotbar, slot vật phẩm, HUD thời tiết/tiền, vòng đời menu và một phần menu worker.
- Có sẵn các scene túi đồ, cửa hàng, bán hàng, nhân công, đơn hàng, nấu ăn, ghép cây, thông tin động vật. Danh mục bên dưới bao phủ chúng ở mức yêu cầu thiết kế; chưa khẳng định đã kiểm tra trực quan toàn bộ màn hình và trạng thái.
- Thanh điều khiển “Input / 2D / 3D” ở trên cùng thuộc cửa sổ debug của Godot, không thuộc HUD sản phẩm. Không đưa nó vào phạm vi thiết kế game.
- Nút “Công cụ debug” trong game đang được tạo có điều kiện ở debug build trên desktop. Cần kiểm tra bản phát hành, không kết luận đây là lỗi lộ debug ở release.

## 3. Những vấn đề cần xử lý

| Quan sát | Ảnh hưởng với người chơi | Hướng xử lý |
|---|---|---|
| Nhiệm vụ ở trái, “Giống trong kho · G” ở phải, tiền ở góc phải | Mắt phải quét nhiều nơi để hiểu tình hình | Quy hoạch mỗi góc một vai trò; chuyển truy cập kho về cụm thao tác |
| “Chờ nhận thưởng”, dấu `+`, dấu `?` nổi như các nút ngang hàng | Chưa rõ nhiệm vụ nào, phần thưởng gì, nút nào chính | Một thẻ mục tiêu có tên, tiến độ và nút nhận khi đủ điều kiện |
| “Đã lưu tiến trình” nổi ở giữa phía trên | Trạng thái hệ thống tranh sự chú ý với gameplay | Trạng thái lưu nhỏ, tự ẩn; dành vùng thông báo cho sự kiện đáng chú ý |
| Nhãn worker, tên/vạch trạng thái trong thế giới nhỏ ở góc nhìn rộng | Khó đọc, dễ lẫn khi nhiều đối tượng | Chế độ xem xa gọn; chỉ mở chi tiết cho đối tượng đang focus |
| Hotbar có phím, icon, số lượng, chất lượng cùng một ô nhỏ | Các lớp thông tin dễ chồng và khó nhận ô đang chọn | Quy định vị trí từng lớp, làm rõ lựa chọn và tên vật phẩm |
| Tiền hiển thị số rất dài | Chiếm chiều ngang, khó đọc nhanh khi quy mô lớn | Xem số rút gọn ở HUD, số chính xác trong tooltip/menu |
| Bubble từng đúng căn chữ nhưng lệch cả khung | “Căn giữa” đang thiếu tiêu chí hình học rõ ràng | Phân biệt tâm chữ, tâm khung, điểm neo NPC và giới hạn màn hình |
| Dự án có theme chung, Cozy HUD và nhiều override cục bộ | Nguy cơ độ dày viền, khoảng cách và cỡ chữ không đồng đều | Một bộ quy chuẩn dùng chung; giữ biến thể theo loại thành phần |

Các nhận xét về hotbar và khả năng đọc là đánh giá từ ảnh và cấu trúc mã, cần xác nhận thêm ở kích thước hiển thị thật. Không dùng ảnh thu nhỏ để kết luận chắc chắn về độ tương phản hay cỡ chữ thực tế.

## 4. Bố cục HUD mục tiêu

| Khu vực | Nội dung chính | Quy tắc |
|---|---|---|
| Trên trái | Đồng hồ + icon thời tiết | Một cụm; chi tiết thời tiết qua hover/click; không thêm lịch/mùa nếu gameplay chưa có |
| Dưới đồng hồ | Mục tiêu đang theo dõi | Tối đa một thẻ mở rộng; có thu gọn; badge khi nhận thưởng được |
| Trên phải | Tiền + truy cập menu hệ thống | Số gọn; bấm/hover xem đầy đủ; không xếp mọi chức năng thành nút lớn |
| Cạnh phải | Thông báo ngắn, xếp hàng | Tối đa 3 thông báo; không che hotbar hoặc panel đang mở |
| Dưới giữa | Hotbar + nút túi đồ | Giữ vị trí quen thuộc; tên vật phẩm và hành động nằm sát thanh |
| Trên hotbar | Gợi ý tương tác của mục tiêu hiện tại | Một mục tiêu chính; phím và tên hành động rõ; không hiện xuyên menu |
| Trong thế giới | Bubble, icon trạng thái, thanh tiến độ | Neo theo đối tượng; tự tránh cạnh màn hình; hạn chế chữ thường trực |

Ở cửa sổ nhỏ, thẻ mục tiêu thu gọn trước; sau đó giảm nhãn phụ. Không thu nhỏ toàn bộ UI đến mức chữ không đọc được. Không bắt người chơi di chuyển camera để thấy nút UI.

Luồng điển hình: **chọn thuốc → thấy tên và cách dùng → focus cây có cỏ → gợi ý “Dùng thuốc diệt cỏ” → click → icon cỏ bay lên → số thuốc giảm**. Nếu hết thuốc, chỉ rõ “Hết thuốc diệt cỏ” và nơi bổ sung; không báo chung chung “Không thể thực hiện”.

## 5. Bộ quy chuẩn giao diện

Các số dưới đây là điểm khởi đầu tại hệ tọa độ UI thiết kế, chưa phải số đo màn hình vật lý. Cần chốt bằng ảnh render sau khi áp dụng `UIScaleComponent`; không nhân scale thêm riêng lẻ ở từng màn hình.

| Thành phần | Quy chuẩn đề xuất |
|---|---|
| Màu nền/khung | Kem sáng, nâu gỗ; chữ nâu đậm; giữ tài nguyên Cozy HUD đang có |
| Màu trạng thái | Xanh: hoàn thành; vàng: cần chú ý; đỏ: lỗi/thiếu; luôn kèm icon hoặc câu chữ |
| Khoảng cách | Nhịp 4/8/12/16/24; khoảng cách giữa nhóm lớn hơn khoảng cách trong nhóm |
| Chữ | 4 cấp: tiêu đề 24–28, nội dung 18–20, nhãn 16–18, ghi chú 14–16; không dùng chữ phụ cho hành động quan trọng |
| Font | Giữ font hiện có nếu đủ dấu và rõ; thử các chuỗi “Khỏe quá!”, “Chờ nhận thưởng”, số lớn và tên dài |
| Nút | Một kiểu chung với normal/hover/pressed/focus/disabled; hành động chính nổi rõ; disabled có lý do |
| Vùng bấm | Desktop đề xuất tối thiểu 36–40; touch tối thiểu 48 đơn vị logic sau xác nhận scale |
| Panel | Header, nội dung, footer rõ; nút đóng nhất quán; không tạo thêm nhiều lớp viền trang trí |
| Icon | Giữ tỉ lệ; không ép kéo méo; thống nhất kích thước hộp icon thay vì ép mọi sprite cùng tỉ lệ hình |
| Tooltip | Tên → công dụng → phím/chi phí/điều kiện; xuất hiện sau hover khoảng 0,35 giây, không che mục tiêu |
| Số | Căn phải trong bảng; thống nhất phân tách theo ngôn ngữ; số chính xác ở giao dịch; HUD được phép rút gọn |
| Chuyển động | Mở/đóng khoảng 120–180 ms; không khóa thao tác vì animation; tùy chọn giảm chuyển động ở đợt sau |

Không đổi font, dùng ảnh raster mới hoặc tạo icon mới trước khi kiểm kê tài nguyên hiện có. Các khung cần co giãn dùng nine-patch với viền cố định; không kéo cả bitmap khiến góc và đuôi bị méo.

## 6. Yêu cầu theo màn hình

### HUD, hotbar và thông báo

- Hotbar: phím ở góc trên trái, số lượng ở dưới phải, chất lượng ở vị trí riêng; icon không chạm chữ. Ô chọn có khác biệt về khung ngoài, không chỉ khác màu nhẹ.
- Tên vật phẩm được chọn hiện gần hotbar, không đặt xa ở một góc khác. Tooltip giải thích hành động; thông tin phụ có thể ẩn khi người chơi đã quen.
- “Giống trong kho · G” trở thành lối tắt trong cụm quản lý/kho hoặc thông tin theo ngữ cảnh. Giữ phím G nếu đang là binding thật; hiển thị theo mapping thay vì ghi cứng.
- Trạng thái lưu: đang lưu/đã lưu/lưu thất bại phân biệt rõ. Thành công nhỏ và tự ẩn; thất bại cần thông báo đọc được và cách xử lý thực sự có hỗ trợ.
- Thu hoạch số lượng lớn: gộp các thông báo cùng loại trong cửa sổ ngắn; không tạo hàng chục dòng che nông trại.

### Túi đồ và kho

- Header có tên kho/túi, sức chứa; tìm kiếm và lọc theo loại nếu số vật phẩm đủ lớn.
- Khu chi tiết có icon, tên, loại, công dụng, số lượng và chất lượng. Không chỉ dựa vào icon để phân biệt các loại thuốc.
- Thao tác chuyển một/chuyển cả chồng phải nhất quán; phím tắt được ghi đúng theo khả năng đang có.
- Phân biệt “không có vật phẩm”, “không có kết quả lọc”, “kho đầy”. Không để vùng trống không giải thích.

### Cửa hàng và bán hàng

- Luồng rõ: danh mục → chọn món → số lượng → tổng giá → xác nhận. Giữ tiền hiện tại ở vị trí dễ đối chiếu.
- Món không đủ tiền/đất/điều kiện có lý do tại chỗ. Bán hàng phải phân biệt số lượng, chất lượng và tiền nhận.
- Thuốc diệt cỏ, diệt sâu và thuốc thú y có tên, công dụng, nơi sử dụng; danh mục đủ rõ để người chơi tìm ra.
- Giao dịch thất bại giữ lựa chọn và giải thích nguyên nhân. Thành công phản hồi một lần; không chồng toast và bubble cùng nội dung.

### Quản lý worker

- Tóm tắt đầu màn hình: tổng số, đang làm, đang chờ, đang nghỉ, thiếu vật tư. Phân biệt công việc với nguyên nhân đang chờ.
- Danh sách: số/tên worker, việc hiện tại, vị trí hoặc khu vực, trạng thái. Click mở chi tiết và thao tác hiện có.
- Khu vật tư hiển thị thuốc, thức ăn, hạt giống, phân bón cùng số lượng và cảnh báo sắp hết; có đường dẫn bổ sung nếu game hỗ trợ.
- Trong thế giới chỉ giữ dấu nhận diện/icon gọn; mở chi tiết khi focus. “Đi tuần” khi di chuyển, “Nghỉ” khi nghỉ là yêu cầu về độ đúng của trạng thái, cần xử lý logic kèm theo.
- Thuê/cho nghỉ/ưu tiên công việc có thứ bậc rõ. Xác nhận chỉ dành cho thao tác mất mát đáng kể; không thêm hộp xác nhận cho thao tác thường ngày.

### Cây trồng, vật nuôi và NPC

- Cây: tên/tiến độ/độ ẩm/tình trạng xuất hiện theo ngữ cảnh; thông tin có thể hành động nằm trước thông tin mô tả.
- Vật nuôi: đói/khát/bệnh dễ phân biệt; trạng thái sản xuất và thông tin chi tiết không lấn át cảnh báo cần chăm sóc.
- NPC: chữ căn giữa trong vùng nội dung; **tâm khung** nằm trên NPC; đuôi trang trí không quyết định tâm khung. Khi sát cạnh màn hình, ưu tiên giữ toàn bộ khung trong vùng nhìn và điều chỉnh neo phù hợp.
- Bubble chữ tạm thời không chồng lên bubble trạng thái; câu ngắn, tối đa hai dòng trong tình huống thông thường. Câu dài dùng khung phù hợp, không giảm font đến quá nhỏ.
- Khi zoom xa, dùng icon/gộp thông tin; không hiển thị đầy đủ nhãn của mọi worker/động vật cùng lúc.

### Đơn hàng, nấu ăn, nâng cấp và hệ thống

- Đơn hàng: tách đang làm/đủ điều kiện/đã nhận; một hành động chính rõ ở mỗi trạng thái.
- Nấu ăn: công thức → nguyên liệu có/thiếu → thời gian → hàng đợi → nhận món. Hàng đợi và thành phẩm không bị hiểu nhầm.
- Nâng cấp: trước/sau, chi phí, điều kiện, lợi ích; thiếu điều kiện phải thấy ngay trước khi bấm.
- Menu hệ thống: tối thiểu có đường truy cập các thiết lập đang được hỗ trợ và cách quay lại game. Cỡ UI/âm lượng/phím tắt chỉ đưa vào khi thực sự được triển khai.
- Onboarding: giới thiệu theo thao tác đầu tiên (mua hạt, gieo, tưới, thu hoạch, chăm bệnh), không phủ một bảng hướng dẫn dài lên màn hình đầu.

## 7. Backlog có thể giao triển khai

P0: nền tảng và khả năng sử dụng. P1: hoàn thiện các luồng chính. P2: mở rộng và đánh bóng. Ước lượng S/M/L là độ lớn tương đối, không phải cam kết thời gian.

| ID | Mức | Công việc | Kết quả nghiệm thu chính | Cỡ |
|---|---|---|---|---|
| UI-01 | P0 | Kiểm kê màn hình, state và tài nguyên | Có ảnh baseline và danh mục thành phần dùng chung | S |
| UI-02 | P0 | Chốt theme, khoảng cách, cấp chữ | Có một màn hình mẫu với đủ trạng thái nút, slot, tooltip, panel | M |
| UI-03 | P0 | Quy hoạch HUD bốn vùng | Cụm không chồng nhau ở 1280×720 và 1920×1080 | M |
| UI-04 | P0 | Làm lại thẻ mục tiêu/nhận thưởng | Hiểu mục tiêu, tiến độ, điều kiện và phần thưởng mà không đoán dấu `+`/`?` | M |
| UI-05 | P0 | Chuẩn hóa hotbar | Ô chọn rõ; icon/số lượng/chất lượng/phím không đè nhau | M |
| UI-06 | P0 | Chuẩn hóa prompt tương tác | Chỉ một mục tiêu chính; đúng hành động/phím; ẩn khi mở menu | M |
| UI-07 | P0 | Chuẩn hóa bubble và nhãn thế giới | Đúng tâm, vừa chữ, không tràn màn hình, không chồng trạng thái | M |
| UI-08 | P0 | Luồng thông báo và trạng thái lưu | Gộp trùng, giới hạn số dòng, lỗi có ý nghĩa, thành công tự ẩn | M |
| UI-09 | P0 | Kiểm tra input và focus menu | Click UI không dùng công cụ ngoài thế giới; Escape đóng đúng lớp | M |
| UI-10 | P0 | Kiểm tra UI scale và tiếng Việt | Không cắt chữ/hỏng dấu tại các kích thước hỗ trợ; không scale lặp | M |
| UI-11 | P1 | Túi đồ/kho và chi tiết vật phẩm | Người chơi tìm và chuyển đúng món, thấy lý do kho đầy | L |
| UI-12 | P1 | Cửa hàng/bán hàng thống nhất | Hiểu tổng giá, số lượng, điều kiện và tìm được các loại thuốc | L |
| UI-13 | P1 | Dashboard worker và vật tư | Biết worker đang làm gì, chờ vì sao, cần bổ sung gì | L |
| UI-14 | P1 | Panel cây/vật nuôi theo ngữ cảnh | Phân biệt nhu cầu, bệnh và sản xuất; thao tác chữa rõ ràng | M |
| UI-15 | P1 | Đơn hàng/nấu ăn/nâng cấp | Có empty/loading nếu có tác vụ chờ/error/success phù hợp với từng luồng | L |
| UI-16 | P1 | Menu hệ thống và mức cỡ UI | Người chơi điều chỉnh các tùy chọn thực sự có; lựa chọn được lưu | M |
| UI-17 | P1 | Hướng dẫn theo ngữ cảnh | Người mới hoàn thành một vòng trồng–thu hoạch và xử lý một bệnh | M |
| UI-18 | P1 | Kiểm tra đồng bộ các menu còn lại | Ghép cây, ong, trồng cây, mở đất và chuồng cùng quy chuẩn | L |
| UI-19 | P2 | Bộ bố cục touch riêng | Safe area, nút chạm, menu hẹp và thao tác touch được xác nhận trên thiết bị | L |
| UI-20 | P2 | Điều khiển bàn phím/gamepad đầy đủ | Focus nhìn rõ, thứ tự hợp lý, nhãn phím theo thiết bị | L |
| UI-21 | P2 | Giảm chuyển động và tùy chọn trợ năng | Không phụ thuộc riêng màu sắc; cỡ chữ và motion có tùy chọn phù hợp | M |
| UI-22 | P2 | Âm thanh và chuyển động UI | Phản hồi nhẹ, nhất quán, không làm chậm thao tác hoặc gây spam | M |
| UI-23 | P2 | Lối tắt quản lý tổng quan | Chỉ bổ sung dashboard/bản đồ nếu thử nghiệm cho thấy người chơi khó định hướng | L |

UI-07 bao gồm kiểm tra lại các sửa bubble đã làm, không có nghĩa mọi phần đều chưa triển khai. UI-09 cần giữ các chặn input và lifecycle menu đang có, chỉ chỉnh phần thiếu hoặc không nhất quán.

## 8. Chia đợt triển khai

**Đợt A — chốt giao diện mẫu:** UI-01, UI-02; dựng một HUD có dữ liệu giả và một màn hình component mẫu. Chụp 1280×720, 1920×1080, tiếng Việt/Anh. Chốt hình thức trước khi áp dụng hàng loạt.

**Đợt B — gameplay dễ đọc:** UI-03 đến UI-10; hoàn thiện màn hình người chơi nhìn thường xuyên nhất. Chạy đầy đủ các trạng thái bình thường, thông báo dồn, thiếu vật tư, zoom xa và gần cạnh màn hình.

**Đợt C — quản lý nông trại:** UI-11 đến UI-14; ưu tiên túi/kho → cửa hàng → worker → thông tin cây/vật nuôi. Dùng cùng mẫu panel, slot và thông báo đã chốt.

**Đợt D — hoàn thiện các luồng:** UI-15 đến UI-18; rà các menu còn lại, thiết lập và hướng dẫn người mới. P2 tách riêng sau khi phần desktop ổn định.

Không ước lượng số ngày từ ảnh hiện tại. Sau đợt A mới đo khối lượng từng màn hình và ước lượng thời gian đáng tin cậy.

## 9. Bản đồ mã nguồn liên quan

Đường dẫn dưới đây tính từ gốc dự án `C:/projects/fantasy-farm`.

| Nhóm | Điểm cần xem khi triển khai |
|---|---|
| Theme và font | `resources/ui/game_theme.tres`, `resources/ui/cozy_hud/`, `resources/ui/game_font.tres` |
| Scale và viewport | `project.godot`, `components/ui_scale_component.gd` |
| HUD | `components/weather/weather_hud.gd`, `components/wallet_hud.gd`, `components/hotbar_ui.gd`, `scenes/ui/hotbar.tscn` |
| Slot và túi | `components/inventory_slot.gd`, `components/inventory_ui.gd`, `scenes/ui/inventory.tscn` |
| Menu chung | `components/trade_menu.gd`, `components/modal_slide.gd` |
| NPC/bubble | `components/shop_merchant.gd`, `scenes/ui/merchant_interaction.tscn`, `scenes/characters/*merchant.tscn` |
| Bubble động vật/trạng thái | `components/animals/animal_care_bubble.gd`, `components/condition_badges.gd` |
| Worker | `components/workers/worker_actor.gd`, `worker_behaviour_component.gd`, `worker_menu.gd`, `scenes/ui/workers.tscn` |
| Thông tin trong thế giới | `components/context_bars_component.gd`, `components/animal_info_panel.gd`, `scenes/ui/animal_info.tscn` |
| Dịch | `localization/vi.po`, `localization/en.po`, `components/game_text.gd` |

Ưu tiên mở rộng theme và thành phần dùng chung. Giảm override cục bộ theo từng đợt có ảnh so sánh, không thay toàn bộ theme một lần rồi sửa lỗi rải rác. Giữ tương thích dữ liệu lưu và gameplay; thay đổi chức năng mới phải có phạm vi riêng.

## 10. Tiêu chí nghiệm thu cuối

- [ ] Có bộ ảnh baseline và sau sửa cho từng màn hình thuộc phạm vi, cùng độ phân giải, ngôn ngữ và trạng thái.
- [ ] Kiểm tra 1280×720, 1366×768, 1920×1080 và 2560×1440; cửa sổ hẹp hơn chỉ cam kết nếu nằm trong cấu hình hỗ trợ đã chốt.
- [ ] Tiếng Việt/Anh, tên vật phẩm dài, số tiền lớn, số lượng lớn, túi/kho đầy không gây cắt chữ hoặc chồng nội dung.
- [ ] HUD vẫn đọc được ở cỡ cửa sổ nhỏ; UI không đổi kích thước theo camera zoom ngoài quy tắc đã thiết kế.
- [ ] Bubble được kiểm tra tâm khung/chữ, animation, cạnh màn hình, camera zoom và tình huống nhiều đối tượng gần nhau.
- [ ] Chuột bấm UI không gây tưới/cuốc/chữa ở nền; menu mở không còn prompt thao tác thế giới gây hiểu nhầm.
- [ ] Mỗi thao tác chính có phản hồi; lỗi nói rõ nguyên nhân; không tạo đồng thời nhiều thông báo trùng nhau.
- [ ] Các màn hình có trạng thái trống, thiếu điều kiện và thành công; chỉ thêm loading cho tác vụ thật sự có chờ.
- [ ] Luồng trồng–thu hoạch–bán–mua vật tư–chăm bệnh–quản lý worker hoàn thành mà không phải hỏi nút nằm ở đâu.
- [ ] Lint/Godot compile không lỗi; chạy các test liên quan theo phạm vi thay đổi; không coi test logic là thay thế kiểm tra hình ảnh.
- [ ] Đo cùng cảnh trước/sau với 15 worker: không thêm dò toàn bộ thế giới mỗi frame, không tạo tween/thông báo liên tục do refresh.
- [ ] So sánh frame time p95 và chi phí UI trên cùng máy/cùng cảnh; điều tra nếu p95 toàn cảnh tăng quá 5%, không dùng FPS từ hai cảnh khác nhau làm bằng chứng.

## 11. Gói bàn giao cho mỗi đợt

1. Scene mẫu hoặc màn hình hoàn chỉnh và tài nguyên dùng chung.
2. Ảnh trước/sau, có ít nhất một trường hợp tiếng Việt dài và một cửa sổ nhỏ.
3. Danh sách trạng thái đã kiểm tra và kết quả test liên quan.
4. Danh sách ID backlog hoàn thành, phần còn lại và giới hạn cụ thể.

**Phạm vi nên triển khai đầu tiên:** đợt A và B. Đây là phần cải thiện trực tiếp ảnh hiện tại: HUD có trật tự, hotbar dễ đọc, mục tiêu rõ, bubble đúng vị trí và thông báo không chen ngang gameplay.
