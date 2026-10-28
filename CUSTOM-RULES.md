# Quy tắc phối hợp GPT-6.1 Sol và GPT-6.1 Terra

> Bản lưu tạm để tham khảo và chỉnh sửa. File này không tự thay đổi model hoặc bật quy trình phối hợp. Chỉ áp dụng khi người dùng yêu cầu dùng quy trình này cho một công việc cụ thể.

## 1. Mục đích và lựa chọn quy trình

- Model lập kế hoạch và review: **GPT-6.1 Sol**.
- Model thực thi: **GPT-6.1 Terra**, mặc định mức suy luận **Medium**.

- Giảm sửa sai, đọc lại không cần thiết và làm lại task đã hoàn tất.
- Ưu tiên hoàn thành đúng hành vi mong muốn; không đánh đổi độ chính xác để giảm số lượt gọi.
- Việc nhỏ như đổi chữ, thông số hoặc sửa UI có phạm vi rõ: có thể giao Terra trực tiếp, không bắt buộc lập kế hoạch riêng.
- Tính năng vừa, phạm vi rõ: có thể dùng Terra xuyên suốt.
- Refactor hoặc tính năng nhiều phần độc lập: Sol lập kế hoạch, Terra thực thi từng task, Sol review kết quả.
- Save/load, migration, mô phỏng offline, giao dịch tiền hoặc vật phẩm: ưu tiên Sol phụ trách logic chính; Terra chỉ xử lý phần đã tách rõ.
- Không mặc định dùng Max/Ultra. Chọn mức suy luận theo độ khó và bằng chứng thực tế.

## 2. Sol — giai đoạn lập kế hoạch

### Khảo sát

1. Chưa viết code implementation trong giai đoạn lập kế hoạch.
2. Đọc hướng dẫn dự án và mã hiện tại trong phạm vi cần thay đổi.
3. Truy vết luồng bị tác động: nơi gọi, nơi nhận kết quả, dữ liệu dùng chung, signal và lưu trữ nếu liên quan.
4. Tuân thủ cơ chế khám phá code của dự án, bao gồm graph và kiểm tra coverage khi được yêu cầu.
5. Phân biệt điều đã xác minh với giả định; ghi rõ điểm chưa kiểm tra hoặc quyết định còn thiếu.
6. Tránh đọc toàn bộ repository nếu không cần cho nhiệm vụ.

### Nội dung PLAN.md

Kế hoạch phải ngắn vừa đủ để triển khai và bao gồm:

- Mục tiêu và phạm vi công việc.
- Hành vi cần có và hành vi hiện tại cần bảo toàn.
- Các phụ thuộc chéo và rủi ro đáng chú ý.
- Interface/contract: input, output, kiểu dữ liệu, lỗi và side effect khi có liên quan.
- Danh sách task có ID ổn định, thứ tự và phụ thuộc.
- Điều kiện nghiệm thu và cách kiểm tra phù hợp cho từng task.
- Các điểm cần review cuối cùng.

### Đường dẫn và phạm vi sửa

- Dùng đường dẫn tương đối từ thư mục gốc dự án một cách nhất quán.
- Ghi chính xác file cho từng task; phân biệt rõ `Sửa`, `Tạo mới` và `Xóa`.
- Nếu đã xác định được, ghi thêm hàm, class, node hoặc resource cần tác động.
- Xác nhận file và symbol hiện hữu trước khi đưa vào kế hoạch.
- Ghi rõ mục đích của file mới; tránh tạo file trùng vai trò với phần có sẵn.
- Không thêm abstraction hoặc mở rộng interface khi chưa có nhu cầu cụ thể.

### Chia task và kiểm tra

- Mỗi task đủ nhỏ để triển khai và kiểm tra độc lập khi có thể.
- Chốt contract dùng chung trước các task phụ thuộc vào nó.
- Chọn unit test, integration test, kiểm tra runtime hoặc kiểm tra UI theo rủi ro thực tế.
- Không bắt buộc thêm unit test cho từng bước hoặc cho thay đổi hiển thị đơn giản.
- Test tập trung vào hành vi và lỗi có thể xảy ra; tránh test chỉ lặp lại implementation.
- Không sửa fixture hoặc kỳ vọng chỉ để làm test xanh; thay đổi kỳ vọng phải có lý do từ hành vi đã được chốt.

## 3. Terra — giai đoạn thực thi

### Trước khi sửa

1. Đọc hướng dẫn dự án, mục tiêu chung, task được giao và các contract/phụ thuộc liên quan trong PLAN.md.
2. Kiểm tra trạng thái task và mã hiện tại; không chỉ dựa vào mô tả kế hoạch.
3. Xác nhận file và symbol được chỉ định tồn tại.
4. Nếu không tìm thấy, tìm vị trí hiện hành và báo chênh lệch. Không tự tạo file thay thế.
5. Chỉ tạo file mới khi task ghi rõ; nếu phát sinh nhu cầu tạo mới ngoài kế hoạch, báo lý do trước khi mở rộng phạm vi.

### Trong khi thực hiện

- Thực hiện task được giao trong phạm vi đã chốt.
- Giữ nguyên interface/contract trừ khi có quyết định cập nhật được ghi nhận.
- Có thể quyết định chi tiết implementation nội bộ nếu không đổi contract, hành vi hoặc phạm vi.
- Không tự thêm abstraction, tính năng hoặc refactor không liên quan.
- Không hoàn tác thay đổi của người khác; điều chỉnh phần việc để phù hợp với mã hiện tại.
- Nếu có xung đột trực tiếp không thể giải quyết trong contract hiện tại, ghi rõ vị trí và nguyên nhân.

### Khi kế hoạch không khớp mã thực tế

- Dừng task bị ảnh hưởng nếu cần đổi contract, thiếu quyết định quan trọng hoặc kế hoạch mâu thuẫn với mã.
- Ghi bằng chứng: đường dẫn, symbol, lỗi hoặc kết quả kiểm tra thực tế.
- Đề xuất hướng xử lý và chuyển lại cho Sol hoặc người điều phối để cập nhật kế hoạch.
- Chỉ tiếp tục task khác nếu được giao và không phụ thuộc phần đang vướng.
- Không đoán để cố hoàn thành và không vá vòng nhiều lần cùng một nguyên nhân.
- Nếu một lượt sửa vẫn thất bại vì cùng vấn đề, chuyển cho Sol chẩn đoán trước khi thử tiếp.

### Kiểm tra và bàn giao

- Chạy các kiểm tra đã ghi trong task; bổ sung kiểm tra khi thay đổi thực tế tạo ra rủi ro chưa được bao phủ.
- Báo đúng lệnh/cách kiểm tra, kết quả, giới hạn và phần chưa xác minh.
- Không tuyên bố đã chạy test hoặc đã xem UI nếu chưa thực hiện.
- Không đánh dấu DONE khi kiểm tra bắt buộc chưa đạt.
- Phân biệt lỗi phát sinh với lỗi đã có trước bằng bằng chứng khi có thể; không tự mở rộng sang sửa lỗi nền ngoài phạm vi.

## 4. Trạng thái và cập nhật tiến độ

Sử dụng các trạng thái:

| Trạng thái | Ý nghĩa |
| --- | --- |
| TODO | Chưa bắt đầu. |
| IN_PROGRESS | Đang thực hiện. |
| BLOCKED | Không thể tiếp tục task nếu chưa giải quyết vướng mắc đã ghi. |
| DONE | Đã thực hiện và đáp ứng các kiểm tra/nghiệm thu bắt buộc. |

- Đổi sang IN_PROGRESS khi bắt đầu task.
- Sau khi kiểm tra xong, cập nhật trạng thái và kết quả ngắn gọn ngay trong task.
- Với BLOCKED, ghi nguyên nhân, bằng chứng và quyết định cần có để tiếp tục.
- Với DONE, ghi file đã sửa, kiểm tra đã chạy và phần chưa xác minh nếu có.
- Khi tiếp tục công việc, đọc trạng thái cùng mã hiện tại để tránh làm lại task cũ.
- Chỉ mở lại task DONE nếu có thay đổi mới hoặc bằng chứng cho thấy kết quả cũ không còn hiệu lực; ghi lý do mở lại.
- Chỉ cập nhật phần kế hoạch bị thay đổi. Không biến PLAN.md thành nhật ký cho từng thao tác.

## 5. Sol — review cuối

- Đọc diff thực tế và đối chiếu với mục tiêu, contract cùng điều kiện nghiệm thu.
- Kiểm tra các luồng dễ bị bỏ sót, đặc biệt là phụ thuộc chéo và xử lý lỗi.
- Đánh giá ý nghĩa của test, không chỉ dựa vào trạng thái xanh.
- Nếu cần sửa, tạo task bổ sung nhỏ, chỉ rõ file, vấn đề và cách nghiệm thu.
- Không refactor lại phần đã đạt chỉ vì khác sở thích implementation.
- Báo kết quả cuối, phần chưa xác minh và rủi ro còn lại.

## 6. Mẫu task trong PLAN.md

```md
### T03 — Thu gọn hotbar

- Trạng thái: TODO
- Phụ thuộc: T01
- Sửa: components/hotbar_ui.gd
- Sửa: scenes/ui/hotbar.tscn
- Tạo mới: Không
- Phạm vi: bỏ nhãn công cụ và dòng hướng dẫn, thu gọn container.
- Contract: giữ nguyên signal chọn slot và phím tắt 1–6.
- Nghiệm thu: hotbar gọn, các slot hoạt động, không che nội dung tại 667×375.
- Kiểm tra: thao tác chọn slot bằng phím/chuột và kiểm tra bố cục runtime.
- Kết quả: Chưa thực hiện.
- Chưa xác minh: Chưa xác định.
```

Sau khi hoàn thành, ví dụ:

```md
- Trạng thái: DONE
- Kết quả: đã sửa hai file trong phạm vi; chọn slot bằng phím/chuột hoạt động;
  bố cục runtime tại 667×375 đạt.
- Chưa xác minh: thiết bị cảm ứng thật.
```

## 7. Nguyên tắc tiết kiệm usage

- Không áp dụng quy trình hai model cho mọi thay đổi.
- Sol chốt hướng một lần; Terra nhận task rõ ràng và chỉ đọc ngữ cảnh cần thiết.
- Giữ kế hoạch, kết quả và yêu cầu bàn giao ngắn nhưng có đủ bằng chứng.
- Chọn model mạnh sớm cho phần có rủi ro mất dữ liệu hoặc phụ thuộc phức tạp.
- Không lặp lại kiểm tra đã đạt nếu không có thay đổi hoặc nghi ngờ mới liên quan.
- Đo mức sử dụng trên các công việc tương đương trước khi kết luận tiết kiệm được bao nhiêu.
- Việc chuyển model hoặc giao task phải được thực hiện qua cơ chế có sẵn; file quy tắc không tự điều phối model.
