# Kế hoạch nâng cấp nông cụ

Ngày lập: 25/10/2026. Trạng thái: **U1–U6 đã hoàn thành cho bản v1**. [Hướng dẫn và kiểm chứng](tool_upgrades.md).

Yêu cầu đã chốt: cuốc, tưới và gieo hạt mở rộng 1×1 → 2×2 → 3×3; tạm mua nâng cấp tại NPC thương nhân hiện có, sau này có thể chuyển sang NPC riêng.

## 1. Thiết kế cho bản đầu

| Hạng mục | Quy tắc |
|---|---|
| Cuốc | Ba cấp, tối đa 1 / 4 / 9 ô mỗi động tác |
| Bình tưới | Ba cấp, tối đa 1 / 4 / 9 ô mỗi động tác |
| Gieo hạt | Ba cấp, áp dụng chung cho hạt giống cây trồng đang chọn |
| Mua nâng cấp | Nâng riêng từng loại, lần lượt cấp 1 → 2 → 3 |
| Chọn phạm vi | Chọn sẵn 1×1, 2×2 hoặc 3×3 trong giới hạn đã mở; không dùng tích lực ở bản đầu |
| Sau khi mua | Công cụ vừa nâng tự chọn phạm vi mới để hiệu quả hiển thị ngay; sau đó người chơi có thể đổi nhỏ lại |
| Ghi nhớ | Lưu cấp và phạm vi đang chọn riêng cho từng loại trong profile |
| Animation | Một động tác, commit một lần ở impact frame hiện có; không phát 9 animation nối tiếp |
| Tài nguyên | Một hạt cho mỗi ô gieo thành công; ô không hợp lệ không tiêu hạt |
| Tưới | Giữ lượng ẩm và thời gian ẩm hiện tại cho từng ô; hệ thống hiện chưa có dung tích bình nước, không thêm tài nguyên mới trong phần này |

Gieo hạt là năng lực của người chơi, không phải cấp riêng cho từng loại hạt. Không thay item ID hoặc tạo nhiều bản sao của cuốc/bình tưới trong túi. Phạm vi phần này là đất trồng cây của FarmingController; không mở rộng thu hoạch, bón phân, đốn cây, chăm vườn hoa hoặc tương tác máng.

## 2. Luồng NPC và giao dịch

1. Người chơi đến NPC hiện tại, dùng luồng tương tác đang có để mở TradeMenu.
2. Chọn mục **Nâng cấp nông cụ** trong menu giao dịch.
3. Hiển thị ba thẻ: Cuốc, Bình tưới, Gieo hạt.
4. Mỗi thẻ có icon, cấp hiện tại, phạm vi hiện tại → tiếp theo, giá, điều kiện mở và nút nâng cấp. Cấp tối đa hiển thị rõ.
5. Khi mua thành công, trừ xu và tăng cấp đúng một lần, cập nhật thẻ và phạm vi, thông báo kết quả rồi dùng luồng lưu hiện có.
6. Đóng menu, preview và thao tác nông cụ dùng ngay cấp mới.

ShopMerchant chỉ mở giao diện. ToolUpgradeService thực hiện quote/mua; model và catalog không tham chiếu NPC hoặc ShopUI. Sau này NPC mới chỉ cần mở cùng panel với cùng service, không đổi save hoặc logic nông cụ.

Giao dịch kiểm tra lại cấp mong đợi, giá hiện hành, điều kiện và số xu tại thời điểm mua. Khóa thao tác mua lặp/tái nhập trong lúc phát signal; commit wallet và cấp trước khi báo thay đổi. Thiếu tiền, cấp cũ đã thay đổi hoặc đã tối đa đều không trừ tiền. Mua nâng cấp chỉ khả dụng sau khi profile khởi tạo/tải thành công.

### Giá và điều kiện đề xuất để chơi thử

Các số dưới đây là **cấu hình đề xuất, chưa phải quyết định cân bằng đã chốt**. Đưa vào catalog Resource để chỉnh mà không sửa code.

| Nâng cấp | 1×1 → 2×2 | 2×2 → 3×3 |
|---|---:|---:|
| Cuốc | 30.000 xu | 90.000 xu |
| Bình tưới | 30.000 xu | 90.000 xu |
| Gieo hạt | 40.000 xu | 120.000 xu |

- Đề xuất cấp 2 mở sau khi mua thêm 1 cột đất; cấp 3 sau khi mua thêm 3 cột.
- Số cột đã mua = `unlocked_columns - starting_columns`, dùng dữ liệu của chính profile. Không giả định mọi save đều bắt đầu với 4 cột.
- Giá và gate được rà lại ở U6 theo tốc độ kiếm tiền/thao tác thực tế, đặc biệt cây ngắn ngày.

## 3. Phạm vi và ô hợp lệ

Giữ cách nhắm hiện tại: vùng tác động nằm **phía trước nhân vật**, theo hướng nhìn. Không chuyển thành thao tác từ xa tại vị trí con trỏ chuột.

- 1×1: ô ngay trước mặt, giữ cảm giác hiện tại.
- 2×2: hai hàng phía trước; cột chứa ô trước mặt và một cột về phía bên phải nhân vật. Preview thể hiện rõ độ lệch của vùng chẵn.
- 3×3: ba hàng phía trước, mỗi hàng gồm cột giữa và hai cột hai bên.
- Footprint xoay đúng bốn hướng; không chứa ô đứng của nhân vật. Khóa footprint và hướng lúc bắt đầu động tác.
- Thứ tự xử lý: hàng gần trước, trong mỗi hàng từ trái sang phải theo hướng nhân vật. Cùng một thứ tự cho preview và commit.

Một policy chung tạo footprint và kết quả kiểm tra từng ô. Dùng lại quyền đất, vật cản, ô đang bị chiếm và điều kiện của FarmingController:

| Thao tác | Điều kiện thành công |
|---|---|
| Cuốc | Đất cho phép cuốc, chưa cuốc, không có cây/vật cản, đất đã mở |
| Tưới | Đất cho phép tưới và đang khô; ô đã ướt được bỏ qua |
| Gieo | Đất đã cuốc, đang trống, đã mở, có đúng hạt giống hợp lệ ở slot được chốt |

Nếu ít nhất một ô hợp lệ thì cho thực hiện, kể cả ô chính trước mặt bị chặn nhưng các ô bên cạnh còn dùng được. Cần rà cả điều kiện bắt đầu action và hiển thị focus, không chỉ thay vòng lặp commit.

Nếu chọn 3×3, có 9 ô hợp lệ nhưng chỉ còn 5 hạt trong slot đang chọn: preview hiển thị 5 ô sẽ gieo, 4 ô thiếu hạt; commit chỉ gieo 5 ô theo thứ tự đã nêu. Bản đầu không tự chuyển sang stack khác hoặc loại hạt khác.

Tại impact frame kiểm tra lại các ô và inventory vì trạng thái có thể đổi sau preview. Nếu cả vùng không còn hợp lệ thì không tiêu tài nguyên. Kết quả trả về gồm số ô thành công, bị bỏ qua và số hạt đã dùng.

## 4. Preview và điều khiển

- Mở rộng SoilFocusComponent thành preview tối đa 9 ô, không tạo node mới mỗi frame.
- Ô hợp lệ màu xanh; ô bị chặn màu đỏ/mờ; ô hợp lệ nhưng thiếu hạt dùng màu riêng. Kèm số lượng như `Gieo 5/9 ô`.
- HUD hiển thị phạm vi đang chọn. PC dùng nút bấm được trên HUD và phím tắt chu kỳ, mặc định đề xuất **R** sau khi kiểm tra xung đột InputMap.
- Điện thoại dùng nút phạm vi cạnh nút Use; chạm để chuyển qua các kích thước đã mở. Dùng chung model, không viết logic farming riêng cho touch.
- Đổi công cụ khôi phục phạm vi gần nhất của loại đó. Mua nâng cấp mới tự chọn mức vừa mở.
- Khóa đổi phạm vi trong lúc vung công cụ. Đổi slot, hạt, hướng nhìn hoặc chạm nhanh không được chuyển hướng động tác đang chờ impact.
- Khi menu NPC/túi đồ mở, ẩn preview và chặn thao tác đất theo modal lifecycle hiện có.

## 5. Phân chia module

| Thành phần dự kiến | Trách nhiệm |
|---|---|
| ToolUpgradeCatalog / offer Resource | Loại nâng cấp, cấp, phạm vi, giá và gate |
| ToolUpgradeState | Cấp và phạm vi đã chọn theo từng loại; invariants và signal |
| ToolUpgradeService | Quote và giao dịch wallet + state; không phụ thuộc NPC |
| FarmingAreaPolicy | Sinh footprint, thứ tự ô, query hợp lệ và số hạt cần |
| FarmingController | Batch till/water/plant, giữ luật đất và vòng đời crop |
| FarmingActionComponent | Khóa dữ liệu đầu động tác, commit batch tại impact frame một lần |
| SoilFocusComponent / range selector | Preview cùng policy, điều khiển PC/touch |
| ToolUpgradePanel | Ba thẻ nâng cấp trong TradeMenu, có thể dùng lại cho NPC mới |
| SaveSchema / WorldStateAdapter | Validate, migration, capture và restore tiến trình |

Không đưa logic nâng cấp vào ShopMerchant hoặc mở rộng một autoload thành nơi chứa tất cả chức năng. FarmWorld chỉ lắp ghép state/service vào các thành phần cần dùng.

## 6. Save và bảo toàn trạng thái

Thêm `tool_upgrades` vào DTO, gồm cấp và phạm vi đang chọn của cuốc/tưới/gieo. Lưu số nguyên trong phạm vi hợp lệ; selected size không vượt cấp đã mở.

- Tại thời điểm lập plan schema hiện là v20. U1 dùng phiên bản kế tiếp còn trống, dự kiến v21, với migration tuần tự cho save cũ.
- Save cũ nhận cả ba loại ở cấp 1, phạm vi 1×1; không trừ tiền hoặc cấp thưởng thêm.
- Validate toàn bộ trạng thái trước restore, không âm thầm nhận cấp sai hoặc cấp vượt trần.
- Mua nâng cấp, đổi phạm vi, lưu/tải và chuyển NPC không làm đổi item ID hoặc cấp lại nông cụ.
- Tôn trọng trạng thái đang load/restore và cơ chế xử lý lỗi lưu hiện có. Chỉ đưa lên UI giao dịch thật sau khi đường save và các action nhiều ô đã hoàn thiện.

## 7. Thứ tự triển khai

| Bước | Công việc | Điều kiện hoàn thành |
|---|---|---|
| **U1 — Dữ liệu, giao dịch, save** | Catalog/state/service; quote, mua đúng một cấp; migration/capture/restore | Unit test thiếu tiền, cấp tối đa, gate, quote cũ, callback mua lặp; save cũ/cấp mới đều tải lại đúng; kiểm thử trong harness trước khi bán thật |
| **U2 — Nông cụ nhiều ô** | Policy footprint; batch till/water/plant; giữ commit tại impact; kiểm tra lại tài nguyên | 1/4/9 ô đúng bốn hướng; khóa đất/vật cản/cây; 5 hạt chỉ gieo 5 ô; sự kiện lặp không tiêu hạt hai lần |
| **U3 — Preview và chọn phạm vi** | Preview nhiều ô, HUD, phím PC và nút touch | Preview khớp commit, không che nút mobile; menu/hủy animation/đổi slot không làm lệch action |
| **U4 — Tích hợp NPC hiện có** | Mục Nâng cấp trong TradeMenu, ba thẻ, thông báo/khóa nút, transaction UI | Mua xong dùng ngay đúng cấp; thiếu tiền/tối đa/gate rõ ràng; mở/đóng menu không ảnh hưởng mua bán hiện tại |
| **U5 — Kiểm thử luồng hoàn chỉnh** | Từ save cũ đến NPC, mua, dùng, lưu, thoát và tải lại; PC + touch | Cả ba loại, cả ba phạm vi, tiến trình và tiền giữ đúng; không sửa profile cá nhân trong QA |
| **U6 — Chơi thử và cân bằng** | Đo tốc độ thao tác, dòng tiền, gate, chi phí; rà layout/hiệu ứng | Chốt giá/gate trong catalog và ghi lại kết quả; benchmark phạm vi 9 ô không gây khựng rõ rệt |

U1 → U2 → U3 → U4 → U5 → U6. U4 chỉ bật mua nâng cấp trong game sau khi U1–U3 đạt; tránh tình trạng trả tiền cho một phạm vi chưa hoạt động. Mỗi bước có log kiểm thử và ghi chú bàn giao trước khi chuyển phần tiếp theo.

U1 đã đạt 43/43 tests, 568 assertions; lint và engine validation đạt, Web export thành công. Bản sao profile hiện có đã migrate v20 → v21 và restore, giữ nguyên xu và đồ trong túi. Giao dịch tại NPC vẫn tắt cho tới U4.

### Chi tiết bắt buộc của U2

- Dùng đơn vị ô trồng thực tế của farmland, không dùng lưới TinyDecor 4px để tạo vùng.
- Batch terrain cập nhật theo layer một lần khi phù hợp, thay vì rebuild terrain 9 lần.
- Gieo hạt chốt loại và slot đầu động tác, kiểm tra lại số lượng ở impact, khóa tái nhập khi inventory/soil signal phát ra.
- Hoàn tất model trước khi phát sự kiện quan sát; một signal không được gọi lại để nhân đôi crop hoặc tiêu hạt lần nữa.
- Objective/onboarding nhận đúng số ô thành công, không đếm các ô bị bỏ qua. Dùng một quy tắc phát sự kiện rõ ràng để tránh vừa đếm batch vừa đếm từng ô.
- Crop tạo ra vẫn có đủ mốc thời gian, độ ẩm, tăng trưởng, pollination, hiệu ứng nảy mầm và save như thao tác một ô.

## 8. Danh sách nghiệm thu toàn tính năng

1. Ở cấp cơ bản, cả ba thao tác hoạt động như bản hiện tại.
2. Mua 2×2 chỉ nâng đúng loại đã chọn, trừ xu một lần; có thể quay về 1×1.
3. Mua 3×3 mở đủ ba phạm vi, không tự nâng hai loại còn lại.
4. Chạm bờ đất, hàng rào, đất khóa, cây đang trồng và vùng pha trộn khô/ướt: chỉ các ô hợp lệ thay đổi.
5. Thiếu hạt, hết hạt giữa animation, đổi slot hoặc đổi loại hạt: không tiêu sai stack, không gieo trùng.
6. Một animation chỉ commit một batch dù frame_changed hoặc inventory.changed phát lại.
7. Mở menu NPC/túi, pause, hủy action, đổi hướng: không còn batch cũ chạy muộn vào vùng khác.
8. Save v20 migrate đúng; save cấp 2/3 và phạm vi nhỏ đã chọn tải lại đúng; tiền/cây/trạng thái nông trại giữ nguyên.
9. PC và touch cùng tạo footprint và cùng kết quả, không nhân đôi hành động do mouse emulation.
10. Panel gọi service qua interface chung; có thể gắn sang một NPC thử khác mà không sửa model hoặc save.

## 9. Những điểm còn là cấu hình đề xuất

Giá, gate mua thêm 1/3 cột và phím R là đề xuất trong plan này. Khi triển khai có thể dùng chúng làm cấu hình thử; kết quả U6 mới là cơ sở chốt cân bằng. Các quyết định nền tảng đã chốt là ba cấp diện tích, nâng riêng từng loại, dùng NPC hiện tại và tách được NPC sau này.
