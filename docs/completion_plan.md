# Kế hoạch hoàn thiện Fantasy Farm

Ngày lập: 23/10/2026. Trạng thái: đang triển khai; xem bảng tiến độ cuối tài liệu.

## 1. Đích đến và phạm vi

Hoàn thiện một bản chơi đơn trên máy tính và điện thoại, có vòng chơi rõ ràng: người mới biết bắt đầu ở đâu, có mục tiêu tiếp theo, phát triển nông trại, lưu và tiếp tục an toàn. Giữ phong cách pixel art và các hệ thống đang có. Hỗ trợ điện thoại là điều kiện hoàn thành, không phải hạng mục tùy chọn sau phát hành.

Kế hoạch này không bao gồm âm thanh. Chưa đưa crafting, câu cá, quan hệ NPC, multiplayer, cloud save hoặc mùa vụ vào phạm vi. Chỉ bổ sung nếu chơi thử cho thấy một khoảng trống cụ thể mà tính năng hiện có không giải quyết được.

Mỗi lần triển khai chỉ làm một phần nhỏ được chọn trong bảng dưới. Kết thúc phần đó bằng bản có thể chơi thử, kết quả kiểm tra và ghi chú thay đổi; chưa chuyển sang phần tiếp theo cho tới khi người dùng chọn tiếp tục. Các lựa chọn dưới đây là đề xuất thiết kế, có thể điều chỉnh trước khi làm phần liên quan.

## 2. Điểm xuất phát đã đối chiếu

| Hạng mục | Hiện trạng | Hướng xử lý |
| --- | --- | --- |
| Trồng trọt, hoa, cây lâu năm, ong | Đã có các hệ thống riêng | Tái sử dụng; không viết lại |
| Vật nuôi, thức ăn/nước, phụ phẩm | Đã có lifecycle và tiến trình offline | Đưa vào mục tiêu sau phần trồng trọt |
| Mua bán | Có cửa hàng, bán nông sản, mua/bán vật nuôi | Giữ giao dịch nguyên tử; dùng catalog giá hiện tại làm cơ sở |
| Mở đất | 48 cột, ban đầu mở 1 cột; cột mua đầu giá 15.000 xu, giá tăng theo lũy thừa 1,8 | Đo khả năng kiếm tiền trước khi chốt cân bằng |
| Lưu game | Schema hiện tại v12, gồm tiến trình mục tiêu; autosave, load, migration, xử lý thoát | Mỗi trạng thái mới phải có save và migration trong cùng phần triển khai |
| Thời gian | `FarmClock` dùng Unix timestamp; có catch-up offline | Không giả định `SceneTree.paused` sẽ dừng tăng trưởng |
| Ngôn ngữ | Anh/Việt; API đổi ngôn ngữ có sẵn; hiện chưa lưu lựa chọn | Bổ sung vào Settings |
| Điều hướng và tương tác | Click đi tới, phím tương tác, khóa input khi menu mở | UI mới dùng chung quy tắc khóa input |
| Cổng | Có ba scene với animation tự động theo khoảng cách player | Có thể bố trí vào map khi rà soát hoàn thiện |
| Vào game | `project.godot` chạy thẳng MainWorld | Thêm luồng khởi động và quản lý phiên chơi |
| Export | Có preset Web | Xác minh khả năng lưu và chạy thực tế trên bản export; không mặc định headless pass là đủ |
| Điện thoại | Input còn phụ thuộc bàn phím/chuột; zoom dùng con lăn; UI scale hiện tại không chứng minh khả năng dùng cảm ứng | Bổ sung điều khiển, bố cục, lifecycle và kiểm thử thiết bị thật |

Nguồn chính: mã đang chạy trong `components/`, `persistence/`, `world/`, `project.godot` và catalog Resource. Một số tài liệu cũ mô tả kiến trúc/giá trước đây; khi khác nhau, ưu tiên mã hiện tại rồi cập nhật tài liệu liên quan.

## 3. Thứ tự triển khai

| Phần | Kết quả bàn giao | Phụ thuộc |
| --- | --- | --- |
| 0 | Chốt quy tắc trải nghiệm và ghi nhận baseline | Không |
| M0 | Chốt đường phát hành điện thoại, thiết bị và baseline | 0 |
| M1 | Bố cục và UI dùng được trên điện thoại | M0 |
| M2 | Điều khiển cảm ứng và chơi trọn vòng cơ bản | M1 |
| 1A | Chuỗi mục tiêu nhập môn có lưu trạng thái | M2 |
| 1B | UI mục tiêu, theo dõi và nhận thưởng | 1A |
| 1C | Bảng đơn hàng thủ công, có thể hoàn thành lặp lại | 1B |
| 2 | Hướng dẫn đầu game và trang trợ giúp | 1B; làm sau 1C theo lộ trình mặc định |
| 3A | Màn hình bắt đầu, tiếp tục, chơi mới, thoát | 1C, 2 |
| 3B | Menu Esc và Settings được lưu | 3A |
| 4 | Cân bằng tiến trình qua số liệu chơi thử | 1C, 2, 3B |
| 5 | Hoàn thiện phản hồi, tương tác và bố trí map | 4 |
| M3 | Hoàn thiện hiệu năng, chuyển nền và lưu trên điện thoại | 5; đo sơ bộ từ M0 và kiểm tra liên tục |
| 6 | Kiểm thử dài, bản export và bản ứng viên phát hành trên máy tính/điện thoại | Tất cả phần trước |

Không đợi phần 6 mới kiểm thử: mỗi phần đều có test chức năng và chơi thử riêng. Lỗi chặn tiến độ hoặc gây mất dữ liệu phải được sửa ngay trong phần phát hiện.

## 4. Phần 0 — Quy tắc và baseline

### Công việc

- Ghi nhận hồ sơ mới: xu, hạt giống/công cụ, đất mở, đàn ban đầu, các vật tư có thể nhặt.
- Lập bảng catalog hiện tại: giá mua/bán, sản lượng, thời gian lớn, chi phí thức ăn và giá mở đất. Chưa thay số.
- Chơi thử từ hồ sơ riêng, đo thời gian tới thu hoạch đầu, lần bán đầu, mua con vật đầu và mở thêm cột đất đầu.
- Xác nhận các phím, kích thước UI đang hỗ trợ, nền tảng dự kiến phát hành và phạm vi hỗ trợ tay cầm.
- Ghi lại lỗi baseline để phân biệt lỗi cũ với hồi quy mới.

### Quy tắc đề xuất

- Nhiệm vụ nhập môn và đơn hàng bản đầu không hết hạn; không phạt người chơi nghỉ game.
- Menu Esc khóa điều khiển; cây và vật nuôi tiếp tục theo thời gian thực như quy tắc offline hiện tại. Hiển thị một câu giải thích rõ. Nếu muốn tạm dừng mô phỏng thật, lập một phần riêng về clock, không chỉ bật pause tree.
- Mục tiêu là sandbox thư giãn có tiến trình; hoàn tất mục tiêu lớn vẫn tiếp tục chơi được.
- Dùng các ngưỡng cân bằng làm giả thuyết để đo, không cam kết số giờ hoàn thành toàn bộ game khi chưa có số liệu.

### Đạt khi

Có baseline và các lựa chọn nêu trên được ghi rõ; chưa đổi tiền, thời gian hoặc save thật của người dùng. Bất kỳ lựa chọn chưa chốt được đánh dấu trước phần triển khai phụ thuộc nó.

## 4A. Điện thoại — M0 đến M3

### M0 — Phạm vi hỗ trợ và đường phát hành

- Đề xuất trải nghiệm ngang màn hình làm mục tiêu đầu tiên vì map và HUD hiện có. Màn hình dọc phải có hướng dẫn xoay máy rõ ràng nếu chưa hỗ trợ; không để UI bị cắt mà vẫn cho chơi.
- Đề xuất thử Web trên Android và iPhone trước vì dự án có preset Web. Đây là hướng cần chứng minh bằng build thử, không phải bảo đảm mọi trình duyệt đều chạy được.
- Kiểm tra engine/export, renderer, bộ nhớ và backend lưu thực tế. Chọn Web nếu đạt tiêu chí; nếu không, lập nhánh Android native có phạm vi rõ. Bản iOS native cần kiểm tra môi trường build/ký riêng, không mặc định có thể xuất từ máy Windows hiện tại.
- Chốt một Android tầm trung và một iPhone thực để thử, ghi model/OS/trình duyệt tại thời điểm triển khai. Giả lập hoặc resize trên PC chỉ là kiểm tra bổ sung.
- Đo cold start, kích thước tải, thời gian tới chơi được, FPS và bộ nhớ ở farm ít/nhiều cây, thú và hiệu ứng. Ngân sách tải/bộ nhớ được chốt theo thiết bị baseline.
- Đích ban đầu đề xuất: duy trì ít nhất 30 FPS trên thiết bị tối thiểu đã chọn trong kịch bản farm chuẩn; xem frame time và thời gian đứng hình khi save, không chỉ FPS trung bình. Đo thêm sau 20–30 phút để thấy nóng máy và giảm hiệu năng.

Đạt khi có build thử trên thiết bị thật, ma trận hỗ trợ và quyết định nền tảng rõ ràng. Nếu còn lỗi engine/export chặn khởi động thì xử lý ở M0 trước khi xây UI cảm ứng trên giả định chưa kiểm chứng.

### M1 — Bố cục và UI cảm ứng

- Tính layout theo vùng màn hình sử dụng được: tai thỏ, thanh điều hướng và vùng bị thanh trình duyệt che. Làm mới layout khi xoay máy, resize hoặc trình duyệt đổi chiều cao.
- Không thu nhỏ nguyên giao diện desktop để nhét vào điện thoại. Dùng bố cục thích ứng: HUD gọn, hotbar cuộn/phân trang nếu cần, chi tiết cửa hàng chuyển thành trang hoặc panel riêng.
- Chừa vùng hai ngón tay ở hai góc dưới cho điều khiển; tránh chồng hotbar, inventory, toast hoặc nút nhận thưởng lên vùng đó.
- Chốt kích thước nút và khoảng cách bằng thử chạm trên máy thật; mục tiêu thiết kế ban đầu khoảng 48 đơn vị UI logic cho thao tác chính sau khi quy đổi scale/DPI. Không đánh đồng pixel texture với kích thước chạm thực.
- Thay tooltip phụ thuộc hover bằng chọn để xem chi tiết hoặc nút thông tin. Hành động quan trọng luôn có nhãn/biểu tượng đủ rõ khi không có con trỏ.
- Các ô số lượng có nút +/− và giới hạn hợp lệ; nếu bật bàn phím ảo thì không che phần nhập/nút xác nhận, đóng bàn phím không tự mua/bán.
- Rà inventory, shop, bán hàng, thông tin thú, mở đất và mọi menu hiện có; cùng component layout sẽ dùng cho nhiệm vụ/đơn hàng/menu mới.

Đạt khi mọi nút cần thiết chạm được, chữ EN/VI đọc được, cuộn danh sách không bấm nhầm và không có UI nằm dưới vùng khuyết/thanh trình duyệt. Kiểm tra cả màn hình ngang ngắn và dài theo thiết bị M0.

### M2 — Điều khiển cảm ứng

| Thao tác | Điều khiển đề xuất |
| --- | --- |
| Di chuyển trực tiếp | Joystick ảo bên trái; ngón tay có thể trượt ngoài vùng joystick mà không mất theo dõi |
| Dùng công cụ/vật phẩm | Nút hành động bên phải, dùng cùng quy tắc gameplay và frame tác động hiện tại |
| Tương tác/thu hoạch | Nút theo ngữ cảnh, hiển thị mục tiêu và hành động trước khi chạm |
| Chọn công cụ | Chạm hotbar; xem thông tin mà không cần hover/phím số |
| Chạm map | Di chuyển tới điểm khi chạm nền; chạm đối tượng hợp lệ thì tiếp cận/tương tác theo resolver hiện có |
| Zoom | Pinch hai ngón; không đồng thời phát lệnh di chuyển hoặc dùng đồ |
| Inventory, mục tiêu, đơn hàng và menu | Các nút trên màn hình; không cần Tab/E/Esc/F5/F9 |

- Tách adapter input cảm ứng khỏi luật gameplay; cả chuột/phím và cảm ứng gọi cùng lệnh đã kiểm tra. Không sao chép thuật toán trồng/mua/bán riêng cho mobile.
- Phân quyền từng touch ID: joystick, nút, UI cuộn hoặc pinch. Giữ joystick và bấm hành động bằng ngón thứ hai phải hoạt động đúng.
- Phân biệt tap, drag và pinch bằng ngưỡng/chế độ rõ ràng; trì hoãn commit tap cho tới khi biết đó không phải gesture khác.
- UI tiêu thụ touch trước thế giới. Một lần chạm không vừa kích hoạt nút vừa đi tới map, cũng không bị xử lý lần hai qua mouse emulation.
- Nhả hết trạng thái input khi mở modal, chuyển nền, mất focus, xoay màn hình hoặc touch bị hủy; không kẹt đi bộ/dùng đồ khi quay lại.
- Chỉ hiện điều khiển theo chế độ thích hợp, có tùy chọn bật/tắt khi cần cho thiết bị lai. Bàn phím/chuột vẫn dùng được như trước.
- Hướng dẫn đầu game và trang trợ giúp hiển thị thao tác theo loại input, không yêu cầu người chơi điện thoại bấm một phím không tồn tại.

Đạt khi chơi được trọn vòng di chuyển → chọn công cụ → cuốc/trồng/tưới → thu hoạch/nhặt → mua/bán → mở đất hoàn toàn bằng cảm ứng. Kiểm thử đa chạm, cuộn menu, pinch, nhả ngón ngoài màn hình và đổi input trên desktop.

### M3 — Hiệu năng, lưu và vòng đời trên điện thoại

- Dùng kết quả M0 và các phần đã thêm để tối ưu đúng điểm nghẽn: thời tiết, đèn, particle, thú, navigation, cây và popup. Giảm hiệu ứng bằng cấu hình chất lượng; không giảm tính đúng đắn của mô phỏng hoặc dữ liệu lưu.
- Rà asset tải vào, atlas, texture và resource không cần cho build. Đo ảnh hưởng của từng thay đổi lên tải ban đầu, bộ nhớ và hình ảnh.
- Autosave định kỳ vẫn là nền tảng. Lưu khi chuyển nền chỉ là cơ hội bổ sung; không dựa duy nhất vào callback đóng trang/thoát app vì có thể bị dừng trước khi ghi xong.
- Lưu vào vùng dữ liệu thích hợp của nền tảng, kiểm tra kết quả và chỉ báo đã lưu sau khi ghi hoàn tất. Web phải được thử qua reload, đóng/mở trình duyệt và các trường hợp không thể lưu hoặc hết dung lượng.
- Phân biệt reload/mở lại bình thường với người dùng xóa dữ liệu trình duyệt; không quảng bá save local là cloud hoặc bảo đảm tồn tại sau khi xóa dữ liệu.
- Khi quay lại từ khóa màn hình/chuyển ứng dụng: reset input, bỏ popup/modal không còn hợp lệ và catch-up một lần theo timestamp. Không chạy bù đồng thời từ nhiều đường làm nhân sản lượng hoặc tiến độ.
- Test mất mạng sau khi game tải xong; chỉ cam kết chơi offline/cài PWA nếu đã có cơ chế và kiểm thử tương ứng. Không mặc định Web đã có khả năng này.
- Xử lý nút/quy trình quay lại theo nền tảng được chọn: đóng lớp UI trước khi rời phiên; không phụ thuộc Esc hoặc thao tác tắt tab để dùng menu.

Đạt khi chơi liên tục tối thiểu 30 phút trên thiết bị M0 với farm chuẩn, đạt ngân sách hiệu năng đã chốt, không lỗi bộ nhớ, không kẹt input sau chuyển nền và tiến trình còn đúng sau mở lại. Chạy lại toàn bộ menu mới từ phần 1–5 bằng cảm ứng.

### Nguyên tắc cho mọi phần triển khai sau M2

UI hoặc tính năng mới chỉ hoàn thành khi dùng được cả chuột/phím lẫn cảm ứng. Dùng kích thước điện thoại thật và safe area trong QA, không lấy việc cửa sổ desktop 500×400 hoạt động làm bằng chứng đủ cho mobile. Không đợi M3 mới sửa lỗi chặn thao tác hoặc lưu dữ liệu.

## 5. Phần 1A — Nền tảng mục tiêu và tiến trình

### Trải nghiệm

Chuỗi nhập môn gợi ý: cuốc một ô → gieo một hạt → tưới một ô cây đang khô → thu hoạch → bán nông sản → mua một vật nuôi → bổ sung thức ăn/nước → mở thêm một cột đất. Loại hạt, số lượng và phần thưởng lấy từ baseline, không khóa vào ví dụ khi chưa kiểm tra nguồn vật tư.

Mỗi lúc có một mục tiêu chính. Nhiệm vụ tiếp theo chỉ mở sau khi nhiệm vụ trước đã nhận thưởng. Cho người chơi tự do làm việc khác; không chặn thao tác để ép làm đúng trình tự.

### Quy tắc đếm

- Mục tiêu hành động như trồng/thu hoạch chỉ đếm giao dịch thành công sau khi bước được kích hoạt. Không đếm nút bấm, animation hay biến động inventory chung.
- Mục tiêu trạng thái như sở hữu vật nuôi hoặc đã mở đất kiểm tra trạng thái hiện tại khi kích hoạt; tránh bắt người chơi mua thêm chỉ vì họ đã làm sớm.
- Bước chuẩn bị đất xét trạng thái ô đã cuốc, kể cả đất có sẵn trong save; nếu buộc phải cuốc thêm, farm đã mở và cuốc kín mọi ô sẽ không thể đi tiếp. Các bước gieo/tưới/thu hoạch vẫn đếm hành động mới.
- Bán hàng chỉ tính sau commit. Signal hiện tại `sold(quantity, total)` đủ cho tổng số/tổng doanh thu; nếu cần theo item thì mở rộng payload tại service với dữ liệu giao dịch đã chốt.
- Đọc save, cấp đồ mặc định, restore và phát lại signal UI không tạo thành hành động mới.
- Tiến trình giới hạn trong yêu cầu; nhận thưởng là thao tác riêng, đúng một lần. Tiền và cờ đã nhận thuộc cùng snapshot.
- Bản đầu thưởng xu để tránh phát sinh mất vật phẩm khi túi đầy. Ví đầy thì giữ trạng thái chờ nhận và giải thích lý do.
- Hồ sơ cũ bắt đầu ở chuỗi nhập môn với các bước kiểm tra trạng thái được xét lại; không suy đoán lịch sử thu hoạch hoặc tự cấp thưởng cho mọi bước.

### Thiết kế kỹ thuật dự kiến

- Resource định nghĩa: ID ổn định, mô tả, loại điều kiện, mục tiêu cần đạt, điều kiện mở và thưởng.
- State/service giữ tiến trình, điều kiện mở và nhận thưởng; không phụ thuộc Control hoặc tên node trong map.
- Adapter gắn vào các điểm commit của farming, trade, animal và land; không tạo event bus toàn game nếu chưa cần.
- FarmWorld nối hệ thống mới. Save adapter/schema ghi ID, tiến trình và trạng thái nhận thưởng bằng kiểu nguyên thủy; không lưu node/Resource sống.
- Tăng schema từ phiên bản đang có tại thời điểm triển khai, có migration từ save cũ. Không chốt cứng số phiên bản kế tiếp trong kế hoạch.

### Đạt khi và kiểm thử

- Hoàn thành từng bước hợp lệ; hành động thất bại không cộng tiến trình.
- Nhấn nhận liên tục hoặc signal gọi lồng nhau không cấp thưởng hai lần.
- Lưu/tải ở trạng thái đang làm, hoàn thành chưa nhận và đã nhận đều khôi phục đúng.
- Bản save trước khi nhận thưởng có thể được tải lại theo quy tắc rollback của toàn bộ save; xu và cờ nhận thưởng luôn khôi phục cùng nhau.
- Migration không làm mất cây, tiền, inventory hoặc vật nuôi.

## 6. Phần 1B — UI mục tiêu

### Công việc

- Một thẻ HUD gọn: tên mục tiêu đang theo dõi và tiến trình; có thể thu gọn.
- Trang mục tiêu: đang làm, đủ điều kiện nhận thưởng, đã hoàn thành; có mô tả thao tác và phần thưởng rõ ràng.
- Chọn một mục tiêu để theo dõi. Toast ngắn khi hoàn thành; không mở modal cưỡng bức.
- Dùng theme/font hiện có, EN/VI và UIScaleComponent; input lock dùng chung cơ chế menu hiện tại.
- Bản 1A có thể được thử bằng API/test; 1B biến toàn bộ chuỗi thành trải nghiệm chơi được.

### Đạt khi

Người chơi nhận thưởng và đổi mục tiêu qua UI; đóng/mở hoặc tải game không nhân đôi signal. Chữ dài, cửa sổ nhỏ 500×400 và kích thước thông thường không làm mất nút chính. Trên điện thoại, nút nhận thưởng và chọn mục tiêu dùng được bằng cảm ứng trong safe area. Thẻ HUD không che hotbar, joystick, nút hành động, thời tiết hoặc thông báo quan trọng.

## 7. Phần 1C — Đơn hàng

### Phạm vi bản đầu

- Một bảng đơn hàng riêng, tối đa ba đơn hiện có. Điểm đặt cụ thể chọn khi xem bố trí map, không chồng hitbox với hai NPC hiện tại.
- Bộ khoảng 6–8 mẫu đơn viết tay, chia nhóm cây trồng/hoa và về sau phụ phẩm vật nuôi/mật ong.
- Mẫu chỉ xuất hiện khi người chơi đã có khả năng tiếp cận nguồn hàng theo định nghĩa mở khóa đã kiểm tra. Không yêu cầu loài/cây bị thiếu nguồn mua hoặc đất chưa thể sử dụng.
- Mỗi đơn yêu cầu một hoặc hai loại sản phẩm, số lượng nguyên và thưởng xu. Giá thưởng tham chiếu giá bán thường cộng mức thưởng được hiệu chỉnh ở phần 4.
- Không có hạn chót, daily reset, reroll trả tiền hoặc tăng độ khó ngẫu nhiên trong bản đầu.
- Mỗi lần thay đơn tạo instance ID riêng. Đơn đang có được lưu; mở bảng hoặc load không tự đổi đơn.

### Giao nộp và thay đơn

- Kiểm tra đủ toàn bộ vật phẩm và sức chứa ví trước khi giao; giao một lần đủ đơn, chưa hỗ trợ nộp từng phần.
- Trừ vật phẩm, cộng xu và đánh dấu đơn hoàn thành như một giao dịch. Thiếu hàng/ví đầy thì không thay đổi gì.
- Hàng đã bán thường không tính là đã giao đơn. UI nhắc phạm vi của nút bán tất cả khi người chơi có hàng đang được yêu cầu; bản đầu không tự khóa vật phẩm.
- Hoàn thành hoặc bỏ một đơn cần thao tác xác nhận phù hợp. Bỏ đơn không phạt xu.
- Thay đơn bằng mẫu hợp lệ theo thứ tự cố định, không tạo phần thưởng chỉ từ việc thay đơn. Lưu vị trí trong vòng mẫu; xử lý trường hợp chưa có mẫu tiếp theo bằng ô trống có giải thích.

### Đạt khi

Có thể chơi liên tục qua nhiều đơn; đủ hàng trải trên nhiều stack vẫn giao đúng. Double click, load, hủy UI, item thay đổi trong lúc menu mở và ví đầy không gây nhân tiền/mất đồ. Đơn hiện có vẫn hợp lệ sau offline và hồ sơ cũ tải được.

## 8. Phần 2 — Hướng dẫn đầu game và trợ giúp

- Dùng chuỗi mục tiêu 1A làm xương sống; không tạo một hệ thống đếm nhiệm vụ thứ hai.
- Hướng dẫn ngắn theo ngữ cảnh cho di chuyển, chọn công cụ, thao tác, inventory và NPC bán hàng.
- Mỗi bước có một hành động chính; hoàn tất hướng dẫn bằng thành công gameplay thực, không chỉ bằng đóng hộp thoại.
- Nội dung hướng dẫn tự chọn cách diễn đạt theo input: phím/chuột trên desktop, joystick/chạm/nút hành động trên điện thoại.
- Có bỏ qua, bật/tắt gợi ý và trang trợ giúp mở lại bất kỳ lúc nào. Bỏ hướng dẫn không tự cấp thưởng nhiệm vụ.
- Lưu các gợi ý đã xem theo profile; quay lại game không lặp toàn bộ onboarding.
- Nêu rõ tăng trưởng theo thời gian thực, offline và nhu cầu vật nuôi để tránh bất ngờ sau khi nghỉ chơi.
- Rà soát đủ hạt/vật tư nhập môn và khoảng trống trong túi. Nếu thiếu do người chơi tiêu hết, có hướng phục hồi được cân bằng, không reset toàn bộ farm.

Đạt khi một người chưa biết game có thể hoàn thành trồng → thu hoạch → bán mà không cần đọc tài liệu ngoài game. Kiểm thử cả đường bỏ qua và tải lại giữa hướng dẫn.

## 9. Phần 3A — Vòng đời phiên chơi

### Màn hình bắt đầu

- Tiếp tục: chỉ cho dùng khi tìm thấy save tương thích; hiển thị lỗi rõ nếu save hỏng hoặc thuộc phiên bản mới hơn.
- Chơi mới: bản đầu quản lý một profile như hiện tại. Nếu có tiến trình, yêu cầu xác nhận ghi đè và tạo bản sao phục hồi trước khi thay. Chỉ xóa/reset sau xác nhận, không khi mở màn hình.
- Cài đặt và thoát. Chưa thêm nhiều slot/profile hoặc quản lý cloud.
- Không bind MainWorld/autosave khi đang ở menu; ngăn mở menu rồi vô tình ghi đè save bằng world mặc định.
- Khi khởi tạo game mới thất bại, giữ save cũ; tải save lỗi không tự biến thành một game mới.
- Thoát dùng quy trình save hiện có: khóa thao tác lặp, chờ kết quả và giữ cửa sổ khi lưu lỗi.

Đạt khi chạy từ cửa sổ mới, tiếp tục, hủy chơi mới, xác nhận chơi mới, save lỗi và thoát trong lúc save đều hoạt động đúng trên hồ sơ thử nghiệm.

## 10. Phần 3B — Menu Esc và Settings

- Menu: tiếp tục chơi, trợ giúp, cài đặt, về màn hình bắt đầu và thoát.
- Điện thoại luôn có nút mở menu và nút quay lại/đóng trên UI; không yêu cầu Esc. Chỉ hiện thao tác thoát/toàn màn hình nếu nền tảng hỗ trợ hành vi đó.
- Thống nhất thứ tự Esc: đóng hộp thoại/menu con trước, sau đó mới mở menu Esc. Không để nhiều lớp cùng nhận phím hoặc click xuyên UI.
- Về menu phải hoàn tất save, tháo world và signal, giải phóng input lock; tiếp tục lại không sinh thêm service/listener.
- Settings bản đầu: EN/VI, cửa sổ/toàn màn hình khi nền tảng hỗ trợ, hiển thị gợi ý. Chỉ thêm tùy chọn có hiệu lực thực.
- Lưu Settings riêng với profile nông trại, giữ lựa chọn qua chơi mới/thoát và mở lại.
- Giữ hành vi thời gian thực đã chốt ở phần 0; việc pause điều khiển không được mô tả là pause tăng trưởng.
- Cấu trúc Settings có chỗ mở rộng âm lượng sau này, nhưng không thêm slider không hoạt động trong phạm vi hiện tại.

Đạt khi mở/đóng menu không tiêu đồ, đổi công cụ hoặc kích hoạt tương tác ngoài ý muốn. Ngôn ngữ cập nhật UI đang mở, phóng to/thu nhỏ không mất nút, lưu cấu hình lỗi có fallback hợp lệ.

## 11. Phần 4 — Cân bằng kinh tế và thời gian

### Số liệu cần có

- Tiền đầu phiên/cuối phiên, doanh thu, chi phí hạt và thức ăn, lợi nhuận ròng.
- Thời gian chờ/chơi chủ động; sản lượng mỗi chu kỳ; tốc độ có thể hoàn thành đơn.
- Thời gian tới lần mua vật nuôi và mở đất đầu tiên; khoảng cách giữa các mốc tiếp theo.
- Tác động của tưới, booster, ong, mưa và tiến trình offline.
- Tình huống không còn xu/hạt, túi đầy, vật nuôi thiếu thức ăn, nghỉ nhiều ngày.

### Cách làm

1. Đo trên hồ sơ mới với giá hiện tại và chuỗi mục tiêu mới.
2. Xác định đoạn chờ dài, đường kiếm tiền vượt trội hoặc vòng lặp sinh lời bất thường.
3. Chỉnh một nhóm tham số mỗi lượt: sản lượng/giá, thưởng đơn hoặc giá mở đất; ghi trước/sau.
4. Chơi lại kịch bản chuẩn và kiểm tra profile cũ không bị thu hồi tài sản.

Không tự động áp giá mới lên đơn đã chấp nhận: lưu rõ phần thưởng đã chốt hoặc có quy tắc migration minh bạch. Các con số mục tiêu cuối cùng được chốt từ baseline và phong cách chơi mong muốn; không lấy việc mua hết 48 cột làm tiêu chí duy nhất.

Đạt khi có bảng số liệu và lý do cho các thay đổi; vòng nhập môn không bế tắc, các mốc tiến triển có nhịp hợp lý, và không có một thao tác lặp đơn giản tạo tiền vô hạn ngoài quy tắc thiết kế.

## 12. Phần 5 — Phản hồi và hoàn thiện map

- Lập ma trận mỗi hành động: thành công, ngoài tầm, sai công cụ, chưa chín, thiếu hàng, thiếu xu, túi/ví/chuồng đầy, đất khóa.
- Dùng thông báo ngắn có thể hành động, cập nhật tooltip/nút bị khóa; giới hạn tần suất để không spam mỗi physics tick.
- Rà outline, huy hiệu tương tác, feedback thu hoạch, trao thưởng và chuyển trạng thái đơn hàng.
- Rà vật thể trang trí dễ bị hiểu là có chức năng. Chỉ thêm tương tác khi có tác dụng cụ thể; còn lại chỉnh trình bày để rõ ý.
- Kiểm tra cổng, lối đi, hàng rào, Y-sort, cây che player, điểm spawn và khả năng tới NPC/bảng đơn. Animation cổng và collider/lối đi phải được thử như một tình huống gameplay, không chỉ xem sprite.
- Rà EN/VI, placeholder, tên item, giá và phím gợi ý; bỏ thông báo debug khỏi luồng chơi chính.

Đạt khi mọi lỗi thao tác phổ biến có lý do rõ, không nhầm vật thể tương tác và trang trí, không có lối bắt buộc bị kẹt, và UI không chồng lấn ở các kích thước đã chọn.

## 13. Phần 6 — Kiểm thử và đóng bản

### Các lượt chơi bắt buộc

| Lượt | Nội dung | Bằng chứng |
| --- | --- | --- |
| Hồ sơ mới | Chơi 30–60 phút qua nhập môn, mua bán, mục tiêu và đơn hàng | Checklist hoàn tất, thời gian các mốc, lỗi phát hiện |
| Tiếp tục | Save/thoát/mở lại trong lúc trồng, nhận thưởng, đang xem menu | Snapshot/tiến trình đúng, không nhận thưởng lặp |
| Offline | Các mốc ngắn/dài với cây, thú, thời tiết và đơn hàng | Catch-up đúng, không reset đơn hay nhân phụ phẩm |
| Hồ sơ cũ | Migration từ fixture được hỗ trợ | Tài sản cũ còn nguyên, tính năng mới có mặc định hợp lệ |
| Biên giao dịch | Túi/ví đầy, thiếu đồ, double click, input lặp | Không mất đồ hoặc cộng tiền hai lần |
| Cửa sổ/input | 500×400 và kích thước thông thường; bàn phím/chuột; tay cầm theo phạm vi đã chốt | Không mất nút, click xuyên hoặc kẹt focus |
| Điện thoại | Android/iPhone thuộc ma trận hỗ trợ; tap, drag, pinch, joystick + hành động cùng lúc; EN/VI và safe area | Hoàn thành vòng chơi bằng cảm ứng, không phụ thuộc phím hoặc hover |
| Chuyển nền mobile | Khóa màn hình, đổi ứng dụng/tab, quay lại và mở lại sau khi bị dừng | Không kẹt input, không nhân catch-up, save khôi phục đúng |
| Hiệu năng mobile | Chơi tối thiểu 30 phút trên thiết bị thấp nhất đã chọn với farm chuẩn và thời tiết | Đạt ngân sách FPS/frame time/bộ nhớ, không treo hoặc thoát bất thường |
| Hiệu năng | Farm đông cây/thú/pickup, mở UI và autosave | So sánh cùng kịch bản baseline, không phát sinh giật đáng kể |
| Export | Khởi động bản thực, chơi, lưu, đóng và mở lại | Log và kết quả thử trên từng nền tảng phát hành |

Web cần thử riêng cơ chế lưu qua lần tải lại/trình duyệt và khả năng chạy IO hiện tại; nếu không đáp ứng thì ghi rõ lỗi và xử lý trước khi coi Web là bản phát hành. Không bật thêm nền tảng chỉ để có file build.

### Điều kiện đóng bản

- Các test liên quan đạt; lint/kiểm tra scene không có lỗi mới. Runtime không phát sinh error/warning do tính năng mới.
- Không còn lỗi gây mất tiến trình, nhân tiền/đồ, không vào được game hoặc kẹt vòng nhập môn.
- Các lỗi còn lại được ghi rõ mức độ, cách tái hiện và quyết định xử lý; không giấu dưới nhãn hoàn thiện.
- Có hướng dẫn phím ngắn, quy tắc thời gian/offline, ghi chú phiên bản và cách lấy bản build.
- Chơi được từ đầu trên bản export với hồ sơ thử riêng; không dùng save cá nhân làm dữ liệu test.
- Chơi được bằng cảm ứng trên điện thoại thuộc phạm vi đã chốt, gồm menu/nhiệm vụ/đơn hàng và save qua chuyển nền/mở lại. Có checklist thiết bị/OS/trình duyệt thực đã thử; không tuyên bố hỗ trợ thiết bị chưa kiểm tra.

## 14. Quy trình bàn giao từng phần

1. Xác nhận phần đang làm và các quyết định thiết kế còn mở của phần đó.
2. Đọc mã hiện tại, đề xuất thay đổi cụ thể; giữ thay đổi đang có của người dùng.
3. Triển khai một lát cắt hoàn chỉnh, gồm dữ liệu, UI nếu thuộc phần, lưu/migration và bản dịch liên quan.
4. Chạy kiểm tra phù hợp, chơi thử bằng hồ sơ riêng, ghi kết quả.
5. Bàn giao: thay đổi gì, dùng thế nào, test nào đạt, hạn chế còn lại và phần tiếp theo được đề xuất.
6. Cập nhật bảng tiến độ bên dưới. Không coi việc chỉ có script hoặc UI mockup là hoàn tất một phần có yêu cầu chơi được.

## 15. Theo dõi tiến độ

| Phần | Trạng thái | Ghi chú |
| --- | --- | --- |
| 0 | Đã ghi baseline dữ liệu, chưa hoàn tất đo trải nghiệm | Xem `objectives_1a.md`: hồ sơ mới/catalog đã đối chiếu; thông số cà rốt hiện 10 giây/100 sản phẩm, còn cần đo và cân bằng |
| M0 | Nền tảng Web đã đạt; thiết bị thật chưa nghiệm thu | Xem `web_build.md`: export release, boot, F5/F9, autosave, reload và đóng/mở tab đã đạt; 23/23 test tập trung. Android/iPhone thật còn chờ xác nhận |
| M1 | Đã triển khai; thiết bị thật chưa nghiệm thu | Xem `mobile_ui.md`: bố cục, safe area, nút chạm, chuyển đồ và số lượng; 35/35 test đạt, Web đã kiểm tra ở chế độ touch |
| M2 | Đã triển khai; thiết bị thật chưa nghiệm thu | Xem `mobile_controls.md`: joystick, dùng đồ/tương tác, pinch, swipe và reset input; 102/102 GUT và 22/22 kiểm tra native touch đạt |
| 1A | Đã triển khai nền tảng/API | 9 mục tiêu, nhận thưởng nguyên tử, schema v12 và migration v11; xem `objectives_1a.md`. UI nhận thưởng thuộc 1B |
| 1B | Đã triển khai; điện thoại thật chưa nghiệm thu | HUD, trang mục tiêu, theo dõi/nhận thưởng, schema v13; 139/139 test và 21/21 native checks; xem `objectives_1b.md` |
| 1C | Đã triển khai; điện thoại thật chưa nghiệm thu | Bảng riêng, 8 mẫu/3 đơn, giao/bỏ có xác nhận, schema v14; 155/155 test và 29/29 native checks; xem `orders_1c.md` |
| 2 | Đã triển khai; chơi thử người mới/điện thoại thật còn chờ | Gợi ý theo mục tiêu, Help EN/VI, tùy chọn/lịch sử theo hồ sơ và cứu trợ một hạt; 165/165 test, 36/36 native checks; xem `onboarding_2.md` |
| 3A | Chưa bắt đầu | Menu bắt đầu/vòng đời phiên |
| 3B | Chưa bắt đầu | Esc/Settings |
| 4 | Đang triển khai 4A — thông số thử nghiệm | Xem `economy_4a.md`: Resource/giá/thưởng/máng và tương thích save; gói hồ sơ mới và offline cấp chuồng đã triển khai (xem `starter_content.md`, `pen_offline.md`); mẻ mật mới đã triển khai (xem `honey_batches.md`); còn đo cân bằng theo phiên chơi |
| 5 | Cỏ GPU đã tới G4, bật một vùng trong MainWorld | Xem `grass_gpu_g4.md`: 10 cụm BarnPen chạy GPU, ba overlap giữ nguồn; weather/light/fallback, 49 checks/bên và 57 GUT; tiếp theo G5 benchmark/chốt cấu hình thiết bị |
| M3 | Chưa bắt đầu | Hiệu năng, lưu và lifecycle điện thoại; rà lại UI mới |
| 6 | Chưa bắt đầu | Kiểm thử và export |

Bước kế tiếp theo lộ trình: 3A — màn hình bắt đầu, tiếp tục, chơi mới và thoát. Thưởng 1A là giá trị khởi đầu trong Resource; tiếp tục đo trải nghiệm ở phần 0 và cân bằng ở phần 4. M0–M2 còn nghiệm thu Android/iPhone thật; M3 hoàn thiện hiệu năng/lifecycle trước khi đóng bản.
