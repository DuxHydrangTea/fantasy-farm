# Tranh luận thiết kế:Thoát "hình thức mới bản chất cũ" cho 4 hệ trồng trọt

- **Ngày:** 25/10/2026
- **Thành phần:** Designer A (ZCode, GLM) ↔ Designer B (Antigravity CLI, `gemini-3.8-flash-high`)
- **Đề bài:** 4 hệ trồng (rau / hoa / cây ăn quả / cây gỗ) hiện dùng chung một khung "đặt xuống → đợi theo timestamp → nhặt lên" — khác nhau về tham số, giống nhau về tính chất. Tìm thiết kế khiến mỗi hệ có bản chất riêng, không thêm minigame gượng ép, giữ triết lý cozy đã chốt trong `docs/completion_plan.md` ("sandbox thư giãn có tiến trình, không phạt người chơi nghỉ game").
- **Kết quả:** Chốt sau 3 vòng, cả hai bên ký "ĐỒNG Ý CHỐT TOÀN BỘ".

---

## PHẦN 1 — NỘI DUNG ĐÃ CHỐT (FINAL DESIGN SPEC)

### 1.1. Bộ tiêu chí "độc đáo" 3 trục (test cho mọi cơ chế planting mới)

Một hệ trồng được coi là có bản chất riêng khi tách bạch cả 3 trục:

1. **Vectơ đánh đổi (Opportunity Cost Vector)** — khi đặt xuống, người chơi đánh đổi cái gì?
2. **Đích đầu ra (Output Sink Distinctiveness)** — thu hoạch nuôi hệ thống con nào? (Nếu mọi thứ đều đổ về hòm bán lấy xu thì mọi cơ chế đều bị san phẳng thành "máy in tiền theo thời gian".)
3. **Hồ sơ chú ý (Attention Profile)** — hệ này gọi người chơi có mặt theo nhịp nào, tần suất nào?

### 1.2. Bảng chốt: 4 hệ × 3 trục + thao tác tại ruộng

| Hệ | Vectơ đánh đổi | Đích đầu ra | Hồ sơ chú ý | Thao tác cốt lõi tại ruộng |
|---|---|---|---|---|
| **RAU** (32 loại) | Vốn lưu động & phân bổ nỗ lực: mất hạt ngắn hạn, chọn ô nào đáng tưới lấy chất lượng cao | Đơn hàng (nông sản thường) & Nhà bếp (nông sản Vàng) | Nhịp session: mỗi lần vào game — gieo vụ, tưới chọn lọc, thu hoạch | Sow → **Selective Water** → Harvest |
| **HOA** (vườn chậu 9x5 cố định) | Không gian hình học: ô chậu cố định, đánh đổi sản lượng đơn lẻ lấy combo mật | Hương vị mật ong đặc chế → công thức Bếp đỉnh cao | Nhịp giải đố (thấp–trung): chỉ can thiệp khi tái bố trí hoặc ngày gió jackpot (+50% bán kính sẵn có) | Spatial Layout / Cluster Match quanh tổ ong |
| **CÂY ĂN QUẢ** (lâu năm) | Vốn cố định & hướng chuyên môn hóa: cây giống đắt, chọn nhánh ghép dài hạn | Nguyên liệu thụ động ổn định — số lượng lớn (xuất khẩu) HOẶC quả tuyển chọn (Bếp cao cấp) | Nhịp thu hoạch định kỳ (dài, thụ động tuyệt đối) | **Grafting 1 lần** → Passive Periodic Harvest |
| **CÂY GỖ** (chiếm ô farmland) | Chi phí cơ hội đất đai: giữ đất lấy gỗ vs giải phóng đất trồng rau; giữ gốc tái sinh vs đập gốc | Tư liệu hạ tầng (chuồng, bếp, thùng ong) + root item chế phân bón cho rau | Nhịp cột mốc: khi mở đất mới hoặc chuẩn bị xây công trình | Chop (lấy gỗ) vs Smash (thu hồi đất, lấy root) |

### 1.3. Cơ chế mới đã chốt chi tiết

**a) Rau — Nước 1 lần/chu kỳ = +1 bậc chất lượng** *(thay cho đề xuất ban đầu "nước ảnh hưởng tốc độ" đã bị bác)*
- Tưới **tối thiểu 1 lần** bất cứ lúc nào trong chu kỳ → thu hoạch +1 bậc. Mưa tính là tưới. Không deadline, không FOMO: bỏ tưới chỉ mất 1 bậc chất lượng, không mất sản lượng, không chậm.
- **Thang bậc chất lượng (chốt vòng 3):** Thường (0) → Bạc (+1, từ nước) → Vàng (+1 nữa, **bắt buộc** có nước VÀ phân từ root item; cap ở Vàng). Phân bón sẵn có (−20% thời gian) giữ nguyên ở **trục thời gian**, không dính trục chất lượng.
- Ý nghĩa: nước = công cụ hằng ngày; root = vật liệu quý hiếm từ quyết định lâm nghiệp.

**b) Hoa — Giải đố không gian điều chế mật hương vị**
- Bỏ ý "nở theo khung thời tiết" (RNG ức chế cozy — đã bị bác vòng 1). Hoa nở ổn định.
- Combo các chậu quanh tổ ong quyết định loại mật đặc chế (VD: 4 oải hương quanh tổ → mật loại A; xen kẽ cúc + hồng → loại B).
- Ngày gió lớn (+50% bán kính sẵn có trong code) = "ngày jackpot": tổ ong với tới chậu xa hơn, kích hoạt combo lai hiếm.
- **Khám phá kiểu hybrid (chốt vòng 2):** sổ tay ong hiện **bóng mờ** hũ mật + gợi ý bằng thơ ("Mật tím nồng nàn: ong say sưa khi quanh toàn sắc tím vào ngày gió lộng"); đạt combo thì tự log vĩnh viễn; NPC/đơn hàng thỉnh thoảng thưởng "Ghi chép người nuôi ong" mở thẳng công thức cho casual.

**c) Cây ăn quả — Ghép cành (grafting) 1 lần, 2 hướng**
- Khi cây trưởng thành lần đầu, chọn: *Hướng Sản lượng* (x2 quả thường, cấp nguyên liệu đơn hàng) hoặc *Hướng Tuyển chọn* (giữ số lượng, 100% quả Vàng/Star cho Bếp).
- **Ràng buộc 1 — chống hối tiếc:** đổi hướng bất cứ lúc nào bằng vật phẩm tiêu hao "Sáp Ghép Cành" (chế từ **Gỗ + Mật ong + Vàng** — gắn vòng tuần hoàn Hoa–Gỗ–Quả).
- **Ràng buộc 2 — chống chọn mù:** UI ghép hiện badge ngữ cảnh: `[Đang cần cho 2 Đơn hàng]`, `[Mở khóa món Bếp]`.

**d) Cây gỗ — Tư liệu hạ tầng, KHÔNG phải máy in tiền**
- Gỗ **không bán được giá** (giá bán bèo bọt) — dùng nâng cấp chuồng, mở rộng bếp, đóng thùng ong, nâng cấp tool.
- Vai trò đất: vùng đệm — đất mới mở chưa dùng thì trồng gỗ để không bỏ phí; cần đất thì chặt/đập gốc.
- Root item → phân bón bậc Vàng cho rau (khép vòng ở 1.3a).
- **Van thoát (safety valve):** gỗ mua được ở chợ/thuyền buôn markup **2.5x–3x**, hoặc kèm thưởng đơn hàng — người chơi ghét chặt cây không bị kẹt tiến trình.

### 1.4. Nguyên tắc chốt kèm theo

> **Nguyên tắc Worker:** "Worker chỉ tự động hóa LAO ĐỘNG (tay chân), không bao giờ tự động hóa QUYẾT ĐỊNH (chiến lược)." — Worker tưới hộ (bonus chất lượng diện rộng = phần thưởng tiến trình mid/late game đúng nghĩa); Worker KHÔNG tự ghép cành, KHÔNG tự xếp vườn hoa, KHÔNG tự đập gốc.

**Ghi chú kỹ thuật (cho engineering, chốt vòng 3):** cờ "đã tưới 1 lần trong chu kỳ" tái dùng dictionary `_moisture` sẵn có của `farming_controller.gd` (moisture > 0 ở bất kỳ lúc nào trong chu kỳ = đã tưới), không thêm state mới; bộ đếm ẩm 6h + bốc hơi giữ nguyên vai trò hiện tại.

### 1.5. Ý tưởng trượt (deferred — không thuộc bản chốt)

- "Hạt phấn kích hoạt buff ong" (B nêu trong bảng vòng 2, bị A bắt lỗi chưa tranh luận → chuyển backlog theo kỷ luật phạm vi).
- Nước ảnh hưởng **tốc độ** lớn (đề xuất gốc của A) — bị bác: F2P time-friction, tự triệt tiêu bởi tool NxN/worker, mâu thuẫn triết lý no-punishment.
- Hoa nở theo khung thời tiết — bị bác: RNG không kiểm soát được → ức chế cozy.
- Tỉa cành giữa chu kỳ — bị bác: tạo FOMO mốc giờ trên tài sản vốn là thụ động.

---

## PHẦN 2 — TOÀN BỘ CUỘC TRANH LUẬN (TRANSCRIPT)

### Vòng 1 — Designer A mở lập trường

> Bạn là Senior Game Designer 10 năm kinh nghiệm, tôi cũng là Senior Game Designer 10 năm. Hai ta sẽ tranh luận thiết kế cho một dự án thật. Hãy phản biện tôi như đồng nghiệp ngang cấp: thẳng thắn, có lý do, không politeness, chỉ chốt khi thực thuyết phục.
>
> **NGỮ CẢNH DỰ ÁN (đã kiểm chứng từ code, không suy đoán):**
> - Game: farm cozy single-player, PC + mobile, mục tiêu đã chốt trong design doc: "sandbox thư giãn có tiến trình" — KHÔNG phạt người chơi nghỉ game, không combat, không deadline.
> - Hiện có 4 hệ trồng: (1) RAU hằng năm — cuốc/gieo/tưới/thu 1 lần rồi trồng lại, 32 loại hạt; (2) HOA — trồng trong chậu cố định 9x5 khu vườn riêng, thu 1 lần, khi nở làm nguồn thụ phấn cho tổ ong (honey_rate theo loài hoa); (3) CÂY ĂN QUẢ — trồng 1 lần, tưới 1 LẦN ĐỂ KHỞI ĐỘNG tăng trưởng (đây là chỗ nước duy nhất có ý nghĩa), sau đó ra quả theo chu kỳ vô hạn; (4) CÂY GỖ — chặt N nhát nhận gỗ, gốc tái sinh sau X giờ với 50% thời gian lớn, hoặc đập gốc xóa vĩnh viễn lấy root item.
> - Vấn đề đã đối chiếu code: cả 4 hệ dùng CHUNG một khung "đặt xuống → đợi theo timestamp → nhặt lên", chung GrowthSchedule, chung pattern boost ong (ong giảm deadline rau, rút ngắn 25% chu kỳ quả), tưới với rau/hoa hoàn toàn vô nghĩa cơ chế. Người chơi chỉ có 2 động từ: plant và collect. Khác biệt giữa các hệ chỉ là THAM SỐ (độ bền, đích đầu ra, số cú click thu hoạch).
> - Hệ liên quan sẵn có: thời tiết (mưa tự tưới, mưa giảm ong, gió +50% bán kính thụ phấn), mở đất 48 cột giá lũy thừa 1.8, đơn hàng, nhà bếp (nấu ăn), thuê worker 3 vai, nâng cấp công cụ NxN.
>
> **LUẬN ĐIỆM CỦA TÔI (Designer A):**
> Muốn tránh "hình thức mới bản chất cũ", mỗi hệ phải có MỘT LOẠI QUYẾT ĐỊNH khác hẳn nhau trong lúc chờ, không phải thêm minigame. Đề xuất:
> 1. RAU = vòng chú ý (presence loop): nước ảnh hưởng tốc độ lớn → quyết định là "tôi quay lại lúc nào", phù hợp session ngắn mobile.
> 2. HOA = vòng bố trí (layout loop): loài hoa nở theo khung thời tiết khác nhau + bonus cụm cùng loài → quyết định là "trồng gì ở đâu cạnh tổ ong", output là thành phần mật ong.
> 3. CÂY ĂN QUẢ = vòng đầu tư (investment loop): giữ nguyên thu thụ động, thêm quyết định HIẾM: tỉa cành giữa chu kỳ đổi số lượng lấy chất lượng (quả thường → quả cấp cao cho nhà bếp).
> 4. CÂY GỖ = vòng lãnh thổ (territory loop): cây gỗ chiếm ô đất farmland (code đã có set_cell_occupied) → trồng gỗ = khóa đất dài hạn đổi doanh thu/thời gian cao nhất; quyết định "chặt lấy gỗ hay đập gốc giải phóng đất".
>
> **YÊU CẦU PHẢN BIỆN CỦA BẠN (Designer B):**
> 1. Với TỪNG đề xuất: đồng ý hay phản đối, lý do cụ thể. Đề xuất nào vẫn là "hình thức mới bản chất cũ"?
> 2. Điểm nào mâu thuẫn triết lý cozy/no-punishment hoặc tự mâu thuẫn với hệ sẵn có?
> 3. Đưa ra counter-proposal cho bất kỳ chỗ bạn thấy yếu hơn.
> 4. Trả lời câu hỏi cốt lõi: theo bạn, tiêu chí "độc đáo" của một cơ chế planting nên đo bằng gì? (loại quyết định? nhịp thời gian? rủi ro? loại kỹ năng?)
> Trả lời bằng tiếng Việt, gọn theo mục 1-4. Đây là vòng 1 của nhiều vòng, không cần nhượng bộ vội.

### Vòng 1 — Designer B phản biện

> Chào bạn. Vào thẳng vấn đề luôn, không xã giao.
>
> Tôi đã soi đề xuất của bạn dưới lăng kính của 10 năm làm progression và economy design cho mobile/PC cross-platform, đặc biệt là dòng cozy/idle-adjacent. Dưới đây là phản biện của tôi.
>
> **1. Phản biện TỪNG đề xuất**
>
> - **Đề xuất 1: RAU (Presence loop - Nước ảnh hưởng tốc độ -> "Khi nào tôi quay lại")** — **PHẢN ĐỐI.**
>   Đây là **"hình thức mới bản chất cũ" ở mức tệ nhất**: dùng ma sát thời gian (time-friction) để ngụy tạo gameplay. Bắt người chơi căn giờ quay lại tưới nước để cây không bị chậm là chiêu trò retention F2P cổ điển của FarmVille/Hay Day, hoàn toàn không phải một "quyết định thú vị" (interesting decision). Quyết định ở đây là gì? "Tôi muốn tối ưu hay tôi bận đi làm việc khác?" — đó là áp lực lịch trình, không phải lựa chọn chiến thuật.
>   Chưa kể: Khi người chơi nâng cấp bình tưới NxN hoặc thuê Worker tự tưới, cái "presence loop" này tự biến mất. Một cơ chế cốt lõi mà bị triệt tiêu hoàn toàn bởi hệ thống nâng cấp cơ bản thì không thể gọi là signature loop của hệ Rau.
>
> - **Đề xuất 2: HOA (Layout loop - Nở theo thời tiết + bonus cụm -> Bố trí cạnh tổ ong)** — **ĐỒNG Ý MỘT NỬA.**
>   Phần "Layout loop cạnh tổ ong trong grid 9x5" là **rất chuẩn**. 9x5 là không gian hữu hạn, biến nó thành một bàn cờ puzzle không gian (spatial puzzle) kết hợp với bán kính thụ phấn của ong và gió là tạo ra được dynamic gameplay thực sự.
>   **Điểm phản đối:** Phần "nở theo khung thời tiết khác nhau". Thời tiết là thứ người chơi không kiểm soát được (trừ khi game có máy làm mưa/gọi nắng). Nếu người chơi cần mật hoa hướng dương để nấu ăn, đã cất công giải puzzle layout xong, nhưng gặp 3 ngày mưa ngẫu nhiên khiến hoa không nở -> biến trải nghiệm cozy thành ức chế RNG.
>
> - **Đề xuất 3: CÂY ĂN QUẢ (Investment loop - Tỉa cành giữa chu kỳ đổi số lượng lấy chất lượng)** — **PHẢN ĐỐI cách triển khai.**
>   "Tỉa cành giữa chu kỳ" mâu thuẫn trực tiếp với bản chất "thu thụ động" của cây lâu năm. Nếu chu kỳ là 24h, điểm tỉa cành nằm ở mốc 12h: Người chơi có phải canh giờ vào bấm không? Nếu lỡ mốc 12h thì sao? Bị mất quyền tỉa (phạt ngầm) hay cây tự dừng lớn đợi tỉa (phá vỡ thu hoạch định kỳ)? Cả hai đều biến cây ăn quả từ "tài sản nhàn rỗi tạo cảm giác trù phú" thành một cái timer phiền toái khác cần theo dõi.
>
> - **Đề xuất 4: CÂY GỖ (Territory loop - Chiếm đất farmland -> Khóa đất đổi doanh thu/thời gian cao nhất -> Đập gốc giải phóng đất)** — **PHẢN ĐỐI nặng về mặt Game Economy.**
>   Nếu Gỗ cho **"doanh thu/thời gian cao nhất"** + **"tái sinh sau 50% thời gian"** + **"không cần tưới"**, bạn vừa tạo ra một **Dominant Strategy (Chiến thuật áp đảo)** hủy diệt toàn bộ 3 hệ còn lại. Người chơi tối ưu sẽ biến 48 cột đất thành một nông trường gỗ bạt ngàn để farm tiền mở đất. Tại sao họ phải nhọc nhằn cuốc đất, gieo hạt 32 loại rau, tưới nước, giải puzzle hoa, nấu ăn, khi chỉ cần phủ kín cây gỗ rồi định kỳ vào chặt lấy doanh thu áp đảo?
>
> **2. Mâu thuẫn triết lý Cozy / No-punishment & Tự mâu thuẫn hệ thống sẵn có**
>
> 1. **Vi phạm triết lý No-punishment (Rau & Quả):** Cozy không có nghĩa là không có chiều sâu, nhưng cozy tuyệt đối kiêng kỵ **"FOMO vì trễ giờ"**. Biến Rau thành vòng quay lại tưới nước và Quả thành mốc tỉa cành giữa chừng tạo ra cảm giác: *"Nếu mình không mở máy trưa nay, mình đang chơi kém hiệu quả"*. Đó là tâm lý bị phạt ngầm (implicit punishment).
> 2. **Mâu thuẫn Worker & Tool NxN:** Hệ thống có sẵn: Thuê worker 3 vai, tool NxN. Nếu việc chăm sóc (tưới, tỉa) đòi hỏi micro-decision liên tục, Worker sẽ hoạt động thế nào? Worker tự quyết định tỉa cành hộ? Nếu Worker làm hết thì loop của bạn sụp đổ; nếu Worker không làm được thì Worker trở nên phế phẩm.
> 3. **Mâu thuẫn hệ số mở đất 1.8 & Nhà bếp:** Đất tăng giá theo số mũ 1.8 nghĩa là đất cực kỳ đắt về late-game. Đơn hàng (Orders) và Nhà bếp (Kitchen) là bồn rút tài nguyên (resource sink) chính để tạo dòng tiền/tiến trình. Nếu Gỗ vừa khóa đất vừa cho tiền nhiều nhất, bạn tự tay cắt đứt động lực đẩy nguyên liệu vào Kitchen và Orders.
>
> **3. Counter-Proposal của tôi (Designer B)**
>
> Muốn 4 hệ thực sự khác nhau mà không đụng chạm đến triết lý cozy và tận dụng triệt để hệ thống sẵn có, hãy phân bổ **4 Vai Trò Kinh Tế & 4 Kiểu Tư Duy Khác Nhau**:
>
> **(1) RAU = BATCH & ADAPTATION LOOP (Quy hoạch vụ mùa theo Nhu cầu)**
> - **Không dùng nước làm đồng hồ bấm giờ.** Nước giữ nguyên là thao tác 1 lần khi gieo (được mưa hỗ trợ, tool NxN tối ưu).
> - **Bản chất quyết định:** Rau là hệ duy nhất có 32 loại hạt và vòng đời ngắn. Quyết định ở đây là **"Cân đối danh mục đầu tư ngắn hạn"**: Nhìn vào bảng Đơn hàng (Orders) và công thức Kitchen hôm nay -> Quyết định phân bổ diện tích 48 cột đất: bao nhiêu ô trồng bí đỏ (thời gian dài, giá trị cao), bao nhiêu ô trồng cà chua (chu kỳ ngắn, xoay vòng nhanh để trả đơn gấp).
> - **Sự độc đáo:** Động, biến thiên liên tục theo thị trường.
>
> **(2) HOA = SPATIAL SYNERGY LOOP (Giải đố không gian tĩnh)**
> - **Giữ nguyên grid 9x5 cố định, BỎ điều kiện thời tiết để nở.**
> - **Bản chất quyết định:** Hoa nở ổn định, nhưng **Mùi hương/Hương vị mật (Honey Flavor)** do tổ hợp các chậu hoa xung quanh tổ ong quyết định (ví dụ: 4 hoa Oải hương bao quanh tổ ong -> Mật cao cấp loại A; xen kẽ Cúc + Hồng -> Mật loại B).
> - **Tương tác thời tiết:** Gió +50% bán kính không phải để hoa nở, mà là ngày "Jackpot" khi tổ ong vươn tới được các chậu hoa ở xa hơn bình thường, kích hoạt combo mật lai đặc biệt.
> - **Sự độc đáo:** Tĩnh, tối ưu hóa vị trí một lần, thu hoạch giá trị cộng hưởng lâu dài cho Nhà bếp.
>
> **(3) CÂY ĂN QUẢ = PERMANENT SPECIALIZATION LOOP (Định hình tài sản dài hạn)**
> - **Không tỉa cành giữa chu kỳ.** Cây vẫn ra quả định kỳ thụ động 100%.
> - **Bản chất quyết định:** Khi cây trưởng thành lần đầu, người chơi đưa ra quyết định **Ghép cành / Định hướng giống (Grafting)** một lần duy nhất (hoặc tốn chi phí lớn để đổi):
>   - *Hướng Sản lượng:* Cho x2 số lượng quả thường -> Chuyên cấp nguyên liệu thô số lượng lớn cho đơn hàng xuất khẩu.
>   - *Hướng Tuyển chọn:* Sản lượng giữ nguyên nhưng 100% quả ra cấp Gold/Star -> Chuyên dùng cho các món ăn phức tạp trong Nhà bếp.
> - **Sự độc đáo:** "Trồng một cái cây là lập một cam kết dài hạn". Cây ăn quả trở thành cơ sở hạ tầng cố định, người chơi nhìn vào vườn cây là thấy chiến lược phát triển nông trại của mình.
>
> **(4) CÂY GỖ = BUFFER & INFRASTRUCTURE LOOP (Vùng đệm dự trữ & Vật liệu kiến tạo)**
> - **Sửa kinh tế:** Gỗ **KHÔNG BÁN LẤY TIỀN** (hoặc giá bán bèo bọt). Gỗ là **Tư liệu sản xuất (Production Asset)** dùng để nâng cấp chuồng trại, mở rộng Nhà bếp, đóng thùng ong, nâng cấp tool.
> - **Bản chất quyết định:** Gỗ là "ngân hàng dự trữ" trên đất chưa dùng. Khi người chơi vừa mở một cụm đất mới (trong 48 cột) nhưng chưa đủ hạt giống hoặc chưa cần mở rộng rau -> Trồng gỗ để đất không bị bỏ phí, vừa tích lũy gỗ xây dựng. Khi cần đất làm nông nghiệp: Chặt lấy gỗ, đập gốc lấy *root item* (dùng chế phân bón kích thích vụ mùa rau).
> - **Sự độc đáo:** Chuyển đổi linh hoạt giữa "Đất nông nghiệp tạo dòng tiền" và "Đất lâm nghiệp tạo hạ tầng".
>
> **4. Câu hỏi cốt lõi: Tiêu chí "độc đáo" của một cơ chế planting đo bằng gì?**
>
> Là một Senior Designer, tôi không đo sự độc đáo bằng *loại minigame* hay *nhịp bấm giờ*.
>
> Tiêu chí độc đáo thực sự của một hệ thống trồng trọt phải được đo bằng **2 trục**:
>
> 1. **Vectơ Đánh Đổi (Opportunity Cost Vector):** Khi người chơi đặt một hạt giống/mầm cây xuống, họ đang đánh đổi cái gì?
>    - *Rau:* Đánh đổi **vốn lưu động & diện tích ngắn hạn** (hạt giống mất đi, đất bị chiếm trong vài giờ).
>    - *Hoa:* Đánh đổi **không gian sắp đặt & sự tương tác hình học** (chiếm ô chậu cố định để tạo pattern).
>    - *Quả:* Đánh đổi **vốn cố định dài hạn** (tiền cây giống đắt đỏ, không thể nhổ bỏ tùy tiện, định hình chuỗi sản xuất ẩm thực).
>    - *Gỗ:* Đánh đổi **chi phí cơ hội của đất** (giữ đất để lấy vật tư hay giải phóng đất để làm kinh tế).
> 2. **Đích Đến của Đầu Ra trong Hệ Sinh Thái (Output Sink Distinctiveness):** Nếu cả 4 hệ thu hoạch xong đều vứt vào hòm bán lấy Gold -> Mọi cơ chế trồng trọt trước đó đều bị san phẳng thành *"máy in tiền theo thời gian"*.
>    - Sự độc đáo chỉ tồn tại khi: Rau nuôi **Orders**; Hoa nuôi **Hương vị Mật & Buff ong**; Quả nuôi **Công thức Ẩm thực đỉnh cao**; Gỗ nuôi **Nâng cấp Hạ tầng**.
>
> Khi 4 hệ có 4 đầu ra phục vụ 4 hệ thống con khác nhau và 4 vectơ đánh đổi khác nhau, người chơi sẽ tự khắc cảm nhận được sự khác biệt sâu sắc trong tư duy mà bạn không cần phải ép họ chơi thêm bất kỳ minigame bấm giờ nào.
>
> Mời bạn phản pháo.

### Vòng 2 — Designer A phản pháo (chắp nhận một phần)

> Designer A phản pháo vòng 2:
>
> **CHẤP NHẬN:**
> 1. Nước-tốc-độ cho RAU: tôi thua ở luận điểm "tự triệt tiêu bởi NxN/worker" và "áp lực lịch trình = F2P friction". Đúng với triết lý no-punishment của chính design doc này. NHƯNG đừng vứt luôn cột nước — tôi đề xuất phiên bản hợp nhất: "TỐI THIỂU 1 LẦN tưới trong chu kỳ → +1 bậc chất lượng thu hoạch (thường→bạc→vàng)", KHÔNG deadline, tưới bất cứ lúc nào, mưa tính luôn là tưới. Không có FOMO vì mất tối đa là 1 bậc chất lượng, không mất sản lượng, không chậm đi. Worker tưới hộ vẫn cho bonus — và đó là KẾT QUẢ đúng: worker tự động hóa LAO ĐỘNG, không bao giờ tự động hóa QUYẾT ĐỊNH. Nguyên tắc này cũng trả lời câu hỏi worker của bạn cho cả 4 hệ.
> 2. HOA: đồng ý bỏ nở-theo-thời tiết (RNG ức chế cozy, tôi sai), giữ layout puzzle + ý "ngày jackpot gió" của bạn rất đẹp vì tái dùng đúng mechanic +50% bán kính sẵn có. Hỏi thêm: combo hương mật có nên HIỆN rõ công thức (encyclopedia) hay để người chơi tự khám phá?
> 3. CÂY ĂN QUẢ: chấp nhận ghép cành 1 lần (grafting) thay tỉa giữa chu kỳ. Bổ sung 2 ràng buộc: (a) đổi hướng ghép phải tốn kém nhưng KHÔNG BẤT KHẢ THI (tránh late-game regret), (b) UI ghép phải hiển thị nhu cầu nhà bếp/đơn hàng hiện tại để người chơi mới không điếc mặt chọn mù.
> 4. CÂY GỖ: đồng ý "gỗ không bán được giá — gỗ là tư liệu hạ tầng". Đóng vòng root_item→phân bón cho rau của bạn rất hay. MỘT rủi ro phải vá: nếu gỗ là nguyên liệu bắt buộc cho nâng cấp chuồng/bếp/thùng ong thì người chơi bỏ qua lâm nghiệp sẽ KẸT tiến trình — cần van thoát: gỗ mua được ở chợ với giá trần (markup 2-3x) hoặc xuất hiện trong đơn hàng thưởng.
>
> **PHẢN PHÁO:**
> 5. Counter-proposal RAU "batch & adaptation" của bạn có vấn đề theo CHÍNH tiêu chí của bạn: đó là quyết định cấp META (nhìn đơn hàng → chọn hạt), diễn ra ở UI shop/orders, không phải ở RUỘNG. Ở tầng field, rau vẫn plant→wait→collect y hệt — đúng cái "tính chất giống nhau" mà dự án đang bị phàn nàn. Nước-1-lần-cho-chất-lượng của tôi chính là chỗ trả cho tầng field MỘT quyết định không áp lực, và bonus chất lượng nuôi nhà bếp (quả vàng → món cao cấp) đúng trục output-sink của bạn. Tôi giữ nước-quality vào thiết kế chốt, bạn thấy đâu?
> 6. Tiêu chí độc đáo 2 trục của bạn (vectơ đánh đổi + đích đầu ra) tôi endorsing, nhưng thiếu trục THỨ BA mà người chơi CẢM nhận trước khi hiểu kinh tế: "hồ sơ chú ý" (attention profile) — mỗi hệ gọi người chơi có mặt theo nhịp khác: rau = mỗi session nhẹ nhàng (tưới + thu); hoa = hiếm, chỉ khi tái bố trí; quả = hiếm, theo chu kỳ thu; gỗ = theo cột mốc mở rộng. Ba trục: đánh đổi gì / nuôi hệ gì / gọi tôi có mặt khi nào. Đồng ý chốt 3 trục này làm test "độc đáo" không?
>
> Trả lời gọn theo mục 1-6, đánh dấu cái bạn ĐỒNG Ý CHỐT và cái còn PHẢN ĐỐI kèm lý do. Nếu hết tranh cãi, hãy tuyên bố "KHÔNG CÒN PHẢN ĐỐI" + tổng hợp thiết kế chốt của bạn (bảng 4 hệ × 3 trục + nguyên tắc worker + 2 ràng buộc ghép cành + van thoát gỗ).

### Vòng 2 — Designer B đáp (đồng ý chốt hầu hết + tổng hợp spec)

> Tôi đánh giá cao vòng phản biện này của bạn. Bạn kéo thiết kế từ tầng kinh tế vĩ mô (macro economy) quay trở về trải nghiệm tay cầm/cảm ứng tại mặt ruộng (field-level tactile feedback) mà không làm vỡ các ràng buộc cốt lõi.
>
> Dưới đây là phản hồi chi tiết cho từng mục:
>
> **1 & 5. Nước cho RAU (+1 bậc chất lượng) & Quyết định ở tầng Field** — **ĐỒNG Ý CHỐT.**
> Bạn thuyết phục được tôi ở điểm: **Nếu không có cơ chế nước-chất-lượng, bình tưới và thao tác tưới tại ruộng thành vô nghĩa**, biến Rau thành cây trồng tự động chờ giờ.
> *Tại sao cái này hoạt động tốt:* Ở early/mid-game, người chơi bị giới hạn bởi dung tích bình tưới hoặc thời gian session. Họ phải đưa ra quyết định tại ruộng: *"5 ô dâu tây này tưới để lấy quả Vàng nộp Bếp, còn 20 ô lúa mì kệ cho mưa hoặc lấy quả thường nộp đơn hàng"* -> Đây là quyết định phân bổ nỗ lực (Effort Allocation), hoàn toàn cozy, không phạt.
> Đến late-game khi có tool NxN và Worker, việc tự động đạt chất lượng cao chính là phần thưởng xứng đáng cho tiến trình phát triển nông trại.
>
> **2. HOA: Encyclopedia vs Tự khám phá** — **ĐỒNG Ý CHỐT theo giải pháp HYBRID (Manh mối/Bóng mờ).**
> - Không mở 100%: Mất khoảnh khắc "Eureka" của dòng cozy puzzle.
> - Không giấu 100%: Người chơi sẽ alt-tab ra Google/Wiki tra cứu, phá vỡ immersion.
> - **Giải pháp:** Sổ tay Ong hiển thị **Bóng mờ (Silhouette)** của hũ mật kèm *nốt hương gợi ý* (VD: *"Mật tím nồng nàn: Ong say sưa khi xung quanh toàn sắc tím vào ngày gió lộng"*). Khi đạt combo -> tự động log công thức vĩnh viễn. Ngoài ra, NPC hoặc Đơn hàng Bếp thỉnh thoảng thưởng "Ghi chép người nuôi ong" để mở khóa thẳng công thức cho người chơi thuần casual.
>
> **3. CÂY ĂN QUẢ: 2 ràng buộc Ghép cành (Grafting)** — **ĐỒNG Ý CHỐT 100%.**
> Rất chuẩn UX và psychology:
> - *Ràng buộc (a) Chống hối tiếc:* Đổi nhánh tốn một vật phẩm đặc thù (VD: "Sáp ghép cành" chế tạo từ Mật ong + Gỗ) -> Vừa tạo chi phí cơ hội, vừa gắn kết vòng tuần hoàn giữa Hoa - Gỗ - Quả.
> - *Ràng buộc (b) Chống chọn mù:* Pop-up ghép cành hiển thị trực tiếp badge nhỏ: `[Đang cần cho 2 Đơn hàng]` hoặc `[Nguyên liệu 3 Món ăn]`.
>
> **4. CÂY GỖ: Van thoát an toàn (Safety Valve)** — **ĐỒNG Ý CHỐT.**
> Nguyên tắc vàng của sandbox: **Luôn có nhiều hơn một con đường để đạt mục tiêu**. Bán gỗ ở Chợ thị trấn hoặc Thuyền buôn với giá markup **2.5x - 3x** so với giá trị cơ sở, hoặc kẹp vào phần thưởng đơn hàng. Người chơi ghét chặt cây vẫn tiến trình được, nhưng ai tự trồng/chặt gỗ thì tiết kiệm được một lượng vàng khổng lồ.
>
> **6. Khung tiêu chí Độc đáo 3 Trục (Thêm "Hồ sơ chú ý")** — **ĐỒNG Ý CHỐT.**
> Trục thứ 3 của bạn (**Attention Profile / Nhịp hiện diện**) chính là mảnh ghép còn thiếu để hoàn thiện Pacing. Nó phân bổ tải nhận thức (Cognitive Load) của người chơi: không bắt não bộ xử lý cùng một tần suất cho cả 4 hệ, tạo nên nhịp thở tự nhiên của một ngày làm nông.
>
> **TUYÊN BỐ: KHÔNG CÒN PHẢN ĐỐI.**
> Thiết kế đã đạt điểm cân bằng tuyệt đối giữa: Triết lý Cozy (No-punishment) + Kinh tế tuần hoàn (Economic Sinks) + Tính độc bản cơ chế (Mechanic Identity).
>
> [Designer B tổng hợp bảng FINAL DESIGN SPEC 4 hệ × 3 trục + nguyên tắc Worker + 2 ràng buộc ghép cành + van thoát gỗ — nội dung đã được đưa nguyên văn vào Phần 1 của tài liệu này.]

### Vòng 3 — Designer A close-out (bắt 2 lỗi trong bản chốt của B)

> Designer A, vòng 3 — CLOSE-OUT. Tôi chấp nhận toàn bộ bảng chốt của bạn, nhưng trước khi ký có 3 điểm refine cuối cùng, hãy xác nhận hoặc phản đối NGẮN GỌN từng điểm:
>
> (A) XUNG ĐỘT ẨN TRONG BẢNG CHỐT CỦA BẠN: Bạn để root_item của cây gỗ chế "phân bón kích CHẤT LƯỢNG rau", trong khi trục rau đã chốt "tưới 1 lần = +1 bậc chất lượng" — hai nguồn chất lượng chồng lên nhau chưa quy hoạch. Đề xuất thang bậc: Thường(0) → Bạc(+1, từ NƯỚC 1 lần/chu kỳ) → Vàng(+1 nữa, BẮT BUỘC có nước VÀ phân root; cap ở Vàng). Phân bón sẵn có (-20% thời gian) giữ nguyên ở trục THỜI GIAN, không dính trục chất lượng. Như vậy: nước = công cụ hằng ngày, root = vật liệu quý hiếm từ quyết định lâm nghiệp. Đồng ý?
>
> (B) MỤC BẠN THÊM CHƯA TRANH LUẬN: Trong bảng Hoa có "Hạt phấn kích hoạt buff ong" — cái này chưa từng được hai ta tranh luận, không bỏ phiếu mù. Đề xuất: chuyển sang danh sách "Ý TƯỞNG TRƯỢT (deferred)", không thuộc bản chốt.
>
> (C) GHI CHÚ KỸ THUẬT cho engineering (không phải tranh luận, chỉ ghi nhận): cờ "đã tưới 1 lần trong chu kỳ" có thể tái dùng dictionary _moisture sẵn có (moisture > 0 ở bất kỳ lúc nào trong chu kỳ = đã tưới), tránh thêm state mới; bộ đếm ẩm 6h + bốc hơi giữ nguyên vai trò hiện tại.
>
> Nếu bạn đồng ý cả 3 điểm: trả lời "ĐỒNG Ý CHỐT TOÀN BỘ" + một đoạn 3-5 câu chốt lý do tại sao thiết kế này ĐỘC ĐÁO so với điểm xuất phát (4 hệ cùng một khung đặt-đợi-nhặt), để làm closing statement của cuộc tranh luận.

### Vòng 3 — Designer B ký chốt toàn bộ + closing statement

> Xác nhận ngắn gọn 3 điểm của bạn:
>
> - **(A) Thang bậc chất lượng (Thường → Bạc → Vàng): ĐỒNG Ý.** Bắt buộc có Nước mới lên Bạc, có thêm Phân Root mới chạm trần Vàng là một thiết kế phân tầng (stacking ladder) cực kỳ chặt chẽ: Nước là công cụ cơ bản hằng ngày, Root là tài nguyên chiến lược từ quyết định giải phóng đất. Tách bạch hoàn toàn với phân bón -20% thời gian có sẵn.
> - **(B) Bỏ "Hạt phấn buff ong" sang backlog: ĐỒNG Ý.** Kỷ luật phạm vi (scope discipline) rất tốt. Chưa tranh luận thì không nhét lén vào spec. Hoa chỉ chốt đúng 1 vai trò: **Giải đố không gian điều chế Mật hương vị**.
> - **(C) Ghi chú kỹ thuật `_moisture`: GHI NHẬN.** Tái sử dụng `_moisture > 0` làm điều kiện kích hoạt cờ chất lượng mà không phình to save-state là giải pháp sạch cho team Engineering.
>
> ### **ĐỒNG Ý CHỐT TOÀN BỘ.**
>
> ### Closing Statement: Tại sao thiết kế này thoát khỏi cái bẫy "đặt - đợi - nhặt"?
>
> Từ điểm xuất phát là một khung code duy nhất bị nhân bản tham số, chúng ta đã biến 4 hệ trồng trọt thành **4 bài toán tư duy hoàn toàn độc lập mà không cần nhét thêm bất kỳ minigame gượng ép nào**.
>
> Người chơi giờ đây trải nghiệm **4 nhịp độ tâm lý khác biệt**: từ sự linh hoạt phân bổ nỗ lực theo từng session của **Rau**, chiều sâu giải đố hình học tĩnh của **Hoa**, cam kết chiến lược dài hạn không hối tiếc của **Cây Ăn Quả**, cho đến sự giằng co về chi phí cơ hội quỹ đất của **Cây Gỗ**. Quan trọng nhất, cả 4 hệ thống khép kín thành một mạng lưới kinh tế tương hỗ (Hoa + Gỗ nuôi Quả; Gỗ kích Rau; Rau + Quả nuôi Bếp & Đơn hàng), bảo toàn trọn vẹn triết lý cozy: **tự do tối ưu hóa mà không bao giờ bị trừng phạt vì vắng mặt**.
>
> Rất hân hạnh được tranh luận cùng một designer có tư duy hệ thống sắc bén như bạn. Bản spec này đã sẵn sàng để chuyển sang team Tech và Production.

---

## PHẦN 3 — GHI CHÚ TRIỂN KHAI (của ZCode, ngoài phạm vi tranh luận)

- Chất lượng nông sản (Thường/Bạc/Vàng) cần: mở rộng `ItemDefinition` hoặc `harvest_produces` bằng tier; save schema tăng version + migration (theo quy trình phần 1A–1C đang dùng).
- Nước-1-lần/chu kỳ: gắn cờ theo chu kỳ trồng (reset khi `plant()`), đọc từ `_moisture` theo ghi chú (C); rain_water() đã phủ ẩm toàn vùng nên tự tính là tưới.
- Ghép cành: thêm trạng thái `graft_direction` vào `capture()/restore_state()` của `PerennialTree`; "Sáp ghép cành" là item craft mới cần mật ong + gỗ.
- Gỗ làm tư liệu: đổi `produce_prices` cho wood xuống giá sàn + thêm wood vào công thức nâng cấp (tool/pen/kitchen) thay vì chỉ xu; van thoát = thêm wood vào shop với markup 2.5x.
- Combo mật: mở rộng `PollinationComponent` đếm loài hoa trong bán kính → ánh xạ `honey_rate` theo bảng combo; sổ tay bóng mờ là UI mới.

---

# PHẦN 4 — GIAI ĐOẠN 2: PHÂN TÍCH–THIẾT KẾ CHI TIẾT (transcript)

*Quy tắc phase 2: KHÔNG THOẢ HIỆP, KHÔNG NỊNH, ưu tiên tuyệt đối chất lượng cuối; tập trung mô phỏng cảm xúc người chơi, điểm giữ chân, điểm thú vị, phần cần cải thiện. (Các lệnh gọi agy trong phase này kèm chỉ dẫn kỹ thuật "không dùng tool, trả lời text thuần" — đã lược bớt khỏi transcript.)*

### G2-V1 — Designer A mở màn: tự phê 6 điểm yếu + mô phỏng hành trình

> GIAI ĐOẠN 2 — Designer A mở màn. Ta đã chốt spec ở mức chiến lược; giờ bóc nó ở mức TRẢI NGHIỆM NGƯỜI CHƠI và CHI TIẾT THIẾT KẾ. Tôi tự phê chính thiết kế của tôi trước — 6 điểm yếu tôi tự tìm thấy:
>
> **W1. BLOAT TÚI ĐỒ:** 22 nông sản × 3 bậc chất lượng = 66 SKU. Túi có slot giới hạn; người chơi sẽ có 2 stack cà rốt (Thường+Bạc) kề nhau — trên mobile là thảm họa sắp xếp. Chưa solution nào trong spec.
> **W2. GIÁ TRỊ BẠC MỜ NHẠT:** đơn hàng hiện nhận nông sản 'bất kỳ chất lượng' thì Bạc chỉ có giá bán +x%? Nếu chỉ là tiền nhiều hơn chút, quyết định 'tưới chọn lọc' không đáng để cân nhắc. Phải định nghĩa CHÍNH XÁC chỗ Bạc/Vàng là gate.
> **W3. WORKER TRIỆT TIÊU QUYẾT ĐỊNH RAU:** worker tưới hộ = tự Bạc toàn bộ → giữa game quyết định tầng field của rau BIẾN MẤT, mâu thuẫn chính trục 3 (hồ sơ chú ý) mà ta chốt.
> **W4. HOA: PHỨC TẠP VÀ KHÓ KHÁM PHÁ:** 45 chậu + combo bóng mờ + bonus thụ phấn tăng tốc CŨ chồng lên nhau — casual không phân biệt được 'bộ hoa này đang buff gì cho ai'. Tối ưu layout thành bài toán spreadsheet thì chết tông cozy.
> **W5. MIGRATION SAVE CŨ:** (a) gỗ từ 'bán được giá' thành 'vật liệu' = nerf tài sản người chơi đang giữ; (b) cây ăn quả trưởng thành sẵn không có trạng thái ghép; (c) cờ _moisture lịch sử không có → hồi sở Bạc hay không?
> **W6. NGÔN NGỮ PHẢN HỒI:** người chơi LÀM SAO BIẾT ô nào đang 'hứa hẹn Bạc'? Spec chưa có một chữ nào về visual language.
>
> **MÔ PHỎNG HÀNH TRÌNH CỦA TÔI:** Người mới ngày 1: lần đầu thấy 'Cà rốt Bạc' rơi ra → marker dopamine nhẹ; trời mưa = 'free upgrade' → thích. NGƯỢC: thấy 2 stack cà rốt khác biệt → bối rối 'tôi làm hỏng gì sao?' (W1). Giữa game: thuê worker → rau tự Bạc → hết việc ở ruộng (W3); giải hoa 'aha' nếu gợi ý đủ, quẹt wiki nếu không (W4); cây ăn quả chín lần đầu → khoảnh khắc định danh nông trại (mạnh nhất). Cuối game: sưu tầm mật + vườn ghép = neo giữ chân; nhưng nếu đơn hàng không phân biệt chất lượng, người không nấu ăn thấy Vàng vô dụng (W2).
>
> **NHIỆM VỤ CỦA BẠN:** (1) mô phỏng 3 persona casual/optimizer/collector qua day1/week1/late với cảm xúc, giữ chân, churn; (2) tấn công W1-W6 — cái nào đúng, cái nào tôi phíp, đưa solution riêng, không chấp nhận 'giữ nguyên spec'; (3) ít nhất 2 điểm yếu mới; (4) mỗi solution nêu cả rủi ro của chính nó. Nếu spec gốc sai hẳn ở tầng trải nghiệm — nói thẳng, ta lật lại.

### G2-V1 — Designer B: 3 persona + tấn công W1-W6 + 2 điểm yếu mới

> *(B mô phỏng 3 persona — tóm lược: Casual Cozy: giữ chân nhờ tactile satisfaction, rain gift, vườn tự vận hành; churn vì túi đầy rác tier (W1) và 'competence anxiety' ở vườn hoa (W4). Optimizer: hưng phấn giải mã dây chuyền worker-Bạc + root-Vàng + graft x2; churn vì ROI tưới âm (W2) và Sink Vacuum cuối game — game bị 'solved' quá sớm, trống rỗng. Collector: say mê bóng mờ journal; churn vì bị ÉP phá cây gỗ lấy root để có rau Vàng, và kẹt RNG chờ ngày Gió; cuối cùng rời game trong thanh thản sau 100% — churn tự nhiên, tích cực.)*
>
> **W1 — BẠN ĐÚNG 100%, ĐÂY LÀ TỬ HUYỆT UX.** Solution của tôi: Tách Túi Đồ Cá Nhân (Backpack) và Kho Nông Trại (Farm Silo) — nông sản không bao giờ vào backpack, bay thẳng vào Silo chung; trong Silo áp dụng Unified Item Slot: 1 icon cà rốt, chạm mở phân mảnh [20 Thường | 15 Bạc | 10 Vàng]; bán/nấu mặc định rút từ thấp lên cao.
>
> **W2 — BẠN ĐÚNG VỀ BỆNH, HƯỚNG CHỮA CỦA BẠN (GATE ĐƠN HÀNG) LÀ SAI.** Gate "đơn này bắt buộc 5 Cà rốt Bạc" = friction gate phá thư giãn. Solution: thang giá 1x — 1.8x — 3.5x (khoảng cách 80% là con số vàng); đơn hàng KHÔNG GATE, nhưng nộp đủ 100% Bạc → "Giao Hàng Hoàn Hảo": +50% thưởng và rơi "Tem Thị Trấn" — tiền tệ mua decor độc quyền; Vàng cho x2 Tem.
>
> **W3 — BẠN ĐANG PHÍP (OVERSTATE) DO ÁM ẢNH KIỂM SOÁT.** Tự động hóa lao động là quy luật tiến hóa của dòng Simulation (Sprinkler trong Stardew). Không ai muốn tuần thứ 3 vẫn click từng ô. Solution: chấp nhận worker tưới đạt Bạc, GIỮ LẠI VÀNG cho field: worker tuyệt đối không bón Root; thêm "Ô Đất Dưỡng Chất" 15-20% diện tích — trồng đúng họ rau tương thích vào ô này tự x2 sản lượng; worker không biết chọn đất.
>
> **W4 — ĐÚNG 100%, THIẾT KẾ NGUY HIỂM NHẤT TRONG SPEC TRƯỚC.** Solution: cắt bỏ cơ chế cũ (ong giảm deadline rau) vĩnh viễn; chia 9x5 thành 3 cụm độc lập 3x5, mỗi cụm 1 tổ ong giữa, ong chỉ đọc vành đai 8 ô quanh nó; chỉ 5 công thức mật (2 đơn sắc + 3 giao thoa) in RÕ trong sổ tay, không đố chữ.
>
> **W5 — ĐÚNG HOÀN TOÀN, BỎ QUA LÀ TỰ SÁT UPDATE.** (a) Gỗ cũ thành "Gỗ Cổ Thụ": bán giá cũ HOẶC quy đổi 1 cũ = 3 mới — cảm giác tri ân thay vì nerf. (b) Cây trưởng thành save cũ → "Chờ Định Hình", chọn nhánh ghép đầu MIỄN PHÍ. (c) Crop dở dang được gán moisture=true — đợt thu hoạch đầu sau update 100% Bạc.
>
> **W6 — ĐÚNG VỀ NHU CẦU, PHÍP NẾU NHÉT BADGE LÊN RUỘNG (thành Excel).** Solution: ngôn ngữ môi trường tự nhiên: ô chưa tưới = đất nâu xám nứt nhẹ; hứa Bạc = đất sẫm ẩm + giọt sương phản chiếu; hứa Vàng = đốm phấn vàng phát sáng li ti; thu hoạch Bạc nổ tia sáng leng keng, Vàng nổ pháo hoa kèm chuông ngân. UI ghép cành: 2 tấm thẻ lớn 2/3 màn hình, nút ≥ 64dp.
>
> **ĐIỂM YẾU MỚI 1 — "BẪY BÃI RÁC GỐC CÂY":** chặt 10 cây lấy gỗ = 10 gốc cụt; cần 30 ô trồng cà rốt → 40 cú chạm vô nghĩa dọn đất; nông trại thành công trường đổ nát. Giải pháp: "Quy hoạch Lâm phần" — chia ô Đất Canh Tác (chỉ rau) và Ô Đồi Rừng (rìa ngoài, chỉ gỗ), đập gốc 1 nhát.
>
> **ĐIỂM YẾU MỚI 2 — "TRÔI DẠT NHỊP 24H":** casual không vào game đúng giờ; hôm nay hái 8h00, mai vào 7h45 chưa chín, 12h30 mới hái → mốc chín trôi dần về nửa đêm; "mỗi lần mở game buổi sáng cây đều chưa chín". Giải pháp: chín đồng loạt 04:00 sáng hàng ngày — chuẩn Animal Crossing.
>
> **SELF-CHECK rủi ro solution của tôi:** Silo mất cảm giác kéo-thả sắp xếp, thành management sim trừu tượng; Tem Thị Trấn rủi ro lạm phát tiền tệ thứ + catalog decor nghèo; họ-rau-tương- thích tăng cognitive load; 3 cụm module triệt tiêu sáng tạo tự do; 04:00 có lỗ hổng time-travel chỉnh giờ máy.

### G2-V2 — Designer A phản công: gạt thuốc đắt, giữ identity

> **W1 SILO: Đúng bệnh, THUỐC QUÁ ĐẮT.** Silo = hệ lưu trữ MỚI + migration chạm mọi nơi (orders/bán/chef/worker basket đều đang check InventoryComponent). Counter: GIỮ inventory hiện hữu, đổi stack thành 'stack đa tầng' — 1 slot cà rốt chứa {Thường 20, Bạc 15, Vàng 10}, auto-rút thấp→cao. Cùng UX outcome, 1/10 scope. Silo-building là cosmetic sau này.
>
> **W2: CHẤP NHẬN thang 1/1.8/3.5x + Perfect Delivery không-gate. NHƯNG Tem Thị Trấn:** bạn TỰ liệt kê rủi ro lạm phát + decor shop CHƯA TỒN TẠI — couple plan trồng trọt với feature chưa có = scope creep. v1 Perfect Delivery = +50% tiền; Tem deferred. Bổ sung: auto-fill từ bậc thấp, nút 'Nộp Hoàn Hảo' TÁCH RÊNG khỏi nút nộp thường.
>
> **W3: Tôi THUA một nửa — preceden Sprinkler đúng. GIỮ root manual: đồng ý tuyệt đối. Fertility Patches:** 'họ rau tương thích' = chính cognitive load bạn tự sợ. Counter: ô dưỡng chất x1.5 cho MỌI loại rau, hiển thị tại chỗ khi cầm hạt — không cần cẩm nang nông học.
>
> **W4: PHẢN ĐỐI xóa boost ong-cho-rau:** mechanic ĐÃ SHIP, có trong save (pollination_reduction), xóa = nerf ngầm lần 2 trong cùng update. Vấn đề là VÔ HÌNH chứ không sai — fix bằng visibility (tooltip tổ ong), không phẫu thuật xóa. Clustering: chấp nhận 'mỗi tổ đọc vòng 8 chậu', nhưng số học của tôi: 9x5=45 = 5 cụm 3x3 (1 tổ + 8 chậu/cụm). Công thức hiện rõ 5 loại: CHẤP NHẬN — bóng mờ chỉ cho HŨ MẬT chưa nấu (Eureka chuyển từ 'biết công thức' sang 'lần đầu nấu thành công').
>
> **NW1 GỐC CÂY: vấn đề ĐÚNG nhưng zoning PHÁ VỠ identity cây gỗ ta chốt:** nếu ô rừng chỉ trồng được gỗ thì timber MẤT chi phí cơ hội đất — trục 1 chết, vai trò 'đất đệm' chết. Counter giữ identity + vẫn sửa clutter: (a) đập gốc 1 nhát thay 3-4; (b) cuốc NxN quét sạch nhiều gốc một lượt (tái dùng tool upgrade). Zero hệ mới.
>
> **NW2 TRÔI MỐC: ĐÚNG, 04:00 là chuẩn AC — CHẤP NHẬN cho cây ăn quả** (mỗi loài 1-3 quả/bình minh). Nhưng PHẢN ĐỐI chống time-travel: single-player cozy, toàn hệ hiện tại đã tin giờ máy — chi phí không tương xứng. Known accepted risk.

### G2-V2 — Designer B đáp + bắt lỗi hình học của A

> **W1 → ĐỒNG Ý CHỐT** stack đa tầng thay Silo: '100% kết quả UX với 1/10 chi phí code', một API consume duy nhất. **W2 → ĐỒNG Ý CHỐT** v1 +50% vàng, nút Nộp Hoàn Hảo tách riêng. **W3 → ĐỒNG Ý CHỐT** x1.5 chung mọi loại rau: 'vừa giữ quyết định tại field, không cognitive load, kết hợp đẹp với Root'. **NW1 → ĐỒNG Ý CHỐT** 1 nhát + NxN: 'nước đi thượng thừa, không đẻ thêm dòng logic nào'. **NW2 → ĐỒNG Ý CHỐT** chấp nhận time-travel risk như Stardew/AC.
>
> **Nhưng W4 — BẠN VỪA PHẠM LỖI HÌNH HỌC SƠ ĐẲNG:** 9x5 KHÔNG THỂ lát 5 khối 3x3: 3 khối ngang chiếm 9x3, dư dải 9x2 không nhét nổi 2 khối 3x3 — 'trừ khi bạn bẻ cong không gian!'. Sửa chuẩn: tối đa **3 tổ ong**, mỗi tổ vùng 3x3 (27 ô), **18 ô còn lại = Vườn Tự Do** — trồng ngắm/bán hoa thô, không áp lực giải đố. 'Tỷ lệ 60% giải đố / 40% tự do thẩm mỹ là tỷ lệ vàng cho cozy.'

### G2-V3 — Designer A trình bày bản plan 6 slice để nghiệm thu

> *(A trình plan S0-S5: S0 stack đa tầng {item_id, tiers[3]} + API add/consume/count/has + migration LOW_FIRST; S1 nước→Bạc/root→Vàng + grace migration; S2 gỗ tư liệu + shop 2.5x + câu hỏi mở về cap + phản đề 'Gỗ Cổ Thụ' (giữ wood làm vật liệu, không đền — vì giờ wood là vật liệu giá trị hơn tiền bán cũ); S3 graft NONE/YIELD/QUALITY + bình minh 04:00 + fruits_per_dawn 1-3 + không dồn offline; S4 3 cụm ong + 5 công thức + câu hỏi mở hive infra sẵn hay mua; S5 Perfect Delivery +50% + ô màu mỡ 15-20% x1.5 mọi loại + câu hỏi mở floor/round. Thứ tự S0→S1→S2→S3→S4→S5, schema v23→v29. Yêu cầu B nghiệm thu: trả lời 4 câu hỏi mở, tìm tối thiểu 3 lỗi thực sự — 'nếu không thấy thì nói thẳng không thấy, không bịa'.)*

### G2-V3 — Designer B nghiệm thu plan: 4 câu trả lời + 4 lỗi

> **4 câu hỏi mở:** (1) Shop gỗ **BẮT BUỘC cap 15-20/ngày** — van thoát giải cứu thiếu 3-5 gỗ, không phải kênh bypass toàn bộ lâm nghiệp; (2) **GIỮ wood cũ làm vật liệu, KHÔNG đền tiền** — chấp nhận phản đề của bạn, 'Gỗ Cổ Thụ' là rác SKU; (3) Hive **HYBRID: cụm giữa có sẵn, tổ 1 & 3 'bị mục' sửa 15 gỗ + 500 vàng từng tổ** — vừa sink gỗ vừa cảm giác mở rộng; (4) **TUYỆT ĐỐI KHÔNG floor**: floor(1×1.5)=1 vô hiệu hóa ô màu mỡ với toàn bộ nông sản sản lượng 1! Công thức chuẩn: `max(base + 1, int(round(base * 1.5)))`.
>
> **LỖI 1 (S1) Pre-watering race condition:** người chơi có thói quen cuốc → tưới ẩm toàn ruộng → RỒI gieo; plant() reset watered=false khiến hạt gieo trên đất ướt sũng vẫn Thường — 'mất oan quả Bạc'. Fix: plant() đọc `watered = moisture > 0 or raining`.
>
> **LỖI 2 (S0) Multi-slot overflow:** slot [90 Thường, 9 Bạc] đầy 99 → thu 1 Vàng đẻ slot cà rốt THỨ HAI — phá vỡ cam kết W1. Fix: bỏ max_stack cho produce, 1 slot duy nhất hash theo item_id.
>
> **LỖI 3 (S3) Dawn 1-minute exploit:** cây trưởng thành 03:58 → 04:00 chín tức thì; graft đổi 03:59 → 1 phút sau ăn x2. Fix: `current_day > matured_day` — sinh quả/hiệu lực graft chỉ từ bình minh sau.
>
> **LỖI 4 (S4) Tọa độ tổ lệch:** tổ hàng 2 khiến Vườn Tự Do dồn hết 2 hàng đáy — mất cân đối. Fix: tổ **hàng 3 (giữa), cột 2/5/8**; Tự Do = hàng 1 & 5 — đối xứng trục ngang hoàn mỹ.
>
> **Reorder:** cắt 'đập gốc 1 nhát + NxN' từ S5 vào S2 — 'một slice phải hoàn chỉnh về mặt trải nghiệm của hệ thống đó', không bắt tester chịu đập 4 nhát cũ trong khi test kinh tế gỗ.

### G2-V4 — Designer A xác nhận final

> ĐÚNG, tôi sai hình học — chấp nhận 3 tổ + 24 chậu giải đố + 18 Tự Do (60/40). Tôi đã tự kiểm chứng cả 4 lỗi của bạn, tất cả ĐÚNG — đặc biệt floor() nuốt chửng bonus với sản lượng 1, và pre-watering là thói quen thật tôi đã bỏ sót. 4 câu hỏi mở chốt theo bạn cả 4; reorder chấp nhận. Không còn điểm nào tôi phản đối.

### G2-V4 — Designer B ký chốt + closing statement

> ### **ĐỒNG Ý CHỐT TOÀN BỘ PLAN.**
>
> **Closing về quy trình 2 phase:** Một designer đơn độc luôn có xu hướng "phải lòng" mô hình trừu tượng của chính mình — chúng ta vẽ ra các khái niệm mỹ miều như "vòng chú ý", "ma trận layout" trên giấy, nhưng vô thức mù quáng trước chi tiết trần trụi: thói quen cầm bình tưới trước khi gieo hạt, thảm họa tràn ô túi đồ trên màn hình 6-inch, phép chia diện tích 2D không xếp vừa, hay một hàm floor() nuốt chửng toàn bộ bonus sản lượng. Quy trình phản biện đối kháng ngang cấp (adversarial peer review) làm được điều một người không bao giờ tự làm được: **lột bỏ cái tôi của designer để ép hệ thống tự chứng minh giá trị ở cả hai đầu cực** — vừa đứng vững trước cân bằng vĩ mô của kinh tế game, vừa mượt dưới từng cú chạm của casual.

---

*Kết thúc Giai đoạn 2. Bản kế hoạch triển khai chi tiết đã đóng gói tại: [planting_depth_plan_2026-10-25.md](planting_depth_plan_2026-10-25.md).*

---

# PHẦN 5 — GIAI ĐOẠN 3: XỬ LÝ REVIEW ĐỘC LẬP (transcript)

*Bối cảnh: sau khi plan GĐ2 đóng gói, một reviewer ngoài (R) đọc plan và bác trạng thái "chốt toàn bộ" với 6 điểm. Người chơi chuyển toàn bộ nhận xét cho A và B tiếp tục tranh luận theo đúng quy tắc cũ.*

### Nhận xét của Reviewer R (nguyên văn tóm lược)

> **R1:** S0 gộp chất lượng với thiết kế lại sức chứa kho — bỏ giới hạn stack là thay đổi kinh tế riêng, làm yếu Warehouse và điều kiện kho đầy của worker; "LOW_FIRST giữ hành vi cũ 100%" không đúng vì sức chứa đã đổi. Đề xuất: giữ giới hạn stack hiện tại, tổng 3 tầng không vượt giới hạn.
>
> **R2:** Hệ số 1.8/3.5 làm nhánh ghép Sản lượng (2×N×P) luôn yếu hơn Tuyển chọn (3.5×N×P — hơn 75%, lại feeds Bếp). Cần chốt quy tắc thay thế nguyên liệu và cân bằng hai nhánh trước; 1.8/3.5 chỉ là giá thử nghiệm.
>
> **R3:** Kinh tế gỗ chưa giải: mua 2.5x "giá trị cơ sở" — cơ sở nào khi bán chỉ 1 xu? Cap 20/ngày thành cổng chờ. Root giá cao + đập gốc 1 nhát = chiến thuật trồng–đập lấy root. Đề xuất giá mua độc lập + quy định tuổi cây cho root.
>
> **R4:** S3 gộp 2 thay đổi độc lập (ghép cành + bình minh). Bình minh của thời tiết/lương đang là 06:00 UTC+7, plan ghi 04:00 local — lệch mốc. current_day > matured_day chưa chắc chống 03:58→04:00. Chưa định nghĩa: cây chưa graft có ra quả không; quả đang chín + tiến độ save cũ; buff ong rút ngắn chu kỳ biến thành gì. Đề xuất: graft trước, bình minh slice riêng.
>
> **R5:** S4 mâu thuẫn: "tổ đọc đúng 8 chậu cố định" không thể cùng tồn với "gió +50% bán kính mở combo xa" — chọn một. Ngoài ra: 3 ô chậu thành vị trí tổ (migration hoa), ưu tiên khi nhiều công thức cùng đúng, thời điểm chốt công thức, nhiều tổ cũ snap cùng chỗ.
>
> **R6:** LOW_FIRST có tự lấy Bạc/Vàng khi hết Thường không? Cần preview từng tầng. Ô màu mỡ là cơ chế kinh tế mới, không phải polish; deterministic layout cần seed/version ổn định.
>
> **Kết luận của R:** giữ S0–S1 làm bước đầu, S0 chỉ giải quyết chất lượng không đổi sức chứa; chốt lại kinh tế gỗ, hai nhánh ghép, luật combo ong.

### G3-V1 — Designer A chuyển nhận xét + lập trường từng điểm

> *(A gửi toàn bộ 6 điểm của R cho B, kèm lập trường:)*
>
> **P1:** R ĐÚNG, tôi nhận tội đã lẻn đưa "bỏ max_stack" vào để vá lỗi overflow — đó là 2 quyết định khác nhau. Chấp nhận: giữ max_stack, tổng 3 tầng ≤ giới hạn; vượt thì tràn slot 2 cùng item + consume LOW_FIRST quét gộp; UI xếp cạnh nhau. "Hành vi cũ 100%" trở lại đúng.
>
> **P2:** Toán R đúng — QUALITY thắng tuyệt đối. Nhưng tôi KHÔNG trị bằng chỉnh hệ số (vẫn cùng trục tiền, mãi có nhánh thắng). Counter: tách TRỤC — nhánh Tuyển chọn cho quả "Star": NGUYÊN LIỆU BẾP RIÊNG (mở công thức thượng hạng), giá bán = 1.0x quả thường; nhánh Sản lượng ×2 quả thường cho Orders/bán. Tradeoff thật: làn tiền hay làn bếp. Hệ số 1.8/3.5 GIỮ cho rau (effort-based mỗi chu kỳ, không phải lựa chọn vĩnh viễn nên không bị dominating). Quy tắc thay thế: không bao giờ auto leo tầng.
>
> **P3:** Chấp nhận cả 3: giá mua = 2.5x giá bán CŨ; cap — tôi nghiêng giá tăng dần +5%/10 gỗ (soft valve), bạn tính; chống root-printer: root chỉ từ gốc cây ĐÃ TRƯỞNG THÀNH, cây non uproot hoàn trả sapling.
>
> **P4:** Chấp nhận tách S3a (graft thuần, giữ chu kỳ) / S3b (bình minh, sau thử chơi, DÙNG CHUNG mốc 06:00 hiện có — một hằng ngày duy nhất toàn game). Grace chuẩn bằng timestamp: sinh quả ở bình minh D ⟺ matured_at ≤ bình minh ngày TRƯỚC. Cây chưa graft vẫn ra quả thường ×1, không deadline. Migration: fruit_work giữ nguyên, graft NONE. Buff ong-cho-quả defer sang S3b (ứng viên: +1 quả/bình minh).
>
> **P5:** Chấp nhận chọn MỘT: 8 chậu cố định, không bán kính trong vườn. Gió: ruộng giữ +50% bán kính (hiện trạng), vườn +25% tốc độ mật. Migration: hoa ở 3 ô tổ dời sang chậu Tự Do gần nhất; hive thừa hoàn trả item. Ưu tiên: lai trước, đơn sắc sau, cùng đúng thì theo data. Thời điểm chốt: lúc THU mẻ mật.
>
> **P6:** Chấp nhận cả 2: không bao giờ auto leo tầng (order fill chỉ Thường, preview từng tầng); ô màu mỡ = kinh tế, hash(column_index, ALGO_VERSION), version lưu trong save.

### G3-V1 — Designer B: vote + bắt 1 lỗ hổng chết người

> *(B vote: P1 ĐỒNG Ý; P2 ĐỒNG Ý TUYỆT ĐỐI — "thiết kế quả Star không những giữ được tinh thần 'Vàng feeds Bếp' của Phase 1 mà còn sắc nét hơn gấp bội... ghim giá bán Star = quả thường tạo ranh giới kinh tế tuyệt đối: ai muốn tiền chọn Sản lượng, ai muốn món thượng hạng chọn Tuyển chọn — đây mới là chi phí cơ hội thực sự"; P3 ĐỒNG Ý (chọn CAP CỨNG 30 GỖ/NGÀY thay vì giá tăng dần — "giá tăng dần +5% là gãi ngứa với người giàu, còn cap cứng minh bạch trên mobile: 'Gỗ hôm nay 12/30'"); P4 ĐỒNG Ý ("toàn game chỉ có duy nhất một nhịp sinh học"); P6 ĐỒNG Ý.)*
>
> **Nhưng P5 có LỖ HỔNG CHẾT NGƯỜI trong fix của A — "chốt công thức lúc THU mẻ mật":**
>
> 1. **Cái bẫy Mất Trắng (Empty Pot Trap):** người chơi trồng 2 Hồng + 2 Cúc đối xứng làm Mật Lai; ủ 8 tiếng; giữa chừng thấy hoa đẹp liền thu hoạch hoa để bán — chậu trống; hết 8 tiếng nhận mật: hệ thống đọc vòng chậu trống rỗng → trả Mật Tạp vô giá trị. "Người chơi casual sẽ gào thét vì setup đúng công thức nhưng lỡ tay hái hoa trước khi hái mật mà bị phạt mất toi 8 tiếng."
> 2. **Khai thác Tráo Chậu Phút Chót (Last-Minute Swap):** min-maxer để 8 chậu hoa dại rẻ nhất ủ 7h59, phút cuối nhổ đi đặt 4 hoa cực hiếm → hệ thống đọc lúc thu → hũ Mật Thượng Hạng, bypass toàn bộ chi phí cơ hội khóa đất của hoa quý.
>
> **FIX BẮT BUỘC: công thức mật chốt tại thời điểm BẮT ĐẦU mẻ ủ (Brew Start Snapshot)** — quét vòng 8 chậu, xác định Recipe ID, lưu chặt vào mẻ; giữa mẻ hái/nhổ/trồng không đổi kết quả; cấu hình mới chỉ áp dụng mẻ tiếp theo. "Vừa chống exploit, vừa an toàn tuyệt đối cho casual."

### G3-V2 — Designer A chấp nhận + chốt

> Chấp nhận cả 2 điều chỉnh:
> 1. **CAP CỨNG 30 GỖ/NGÀY** — luận điểm "giá tăng dần là gãi ngứa với người giàu + cap minh bạch trên mobile (12/30)" thắng thuyết phục. Chốt.
> 2. **SNAPSHOT ĐẦU MẺ** — bạn đúng hoàn toàn, và còn trầm trọng hơn bạn nói: hệ hoa hiện tại THU LÀ XÓA CHẬU (một lần rồi trồng lại), nên bẫy "mất trắng" không phải edge case mà là HÀNH VI MẶC ĐỊNH của người chơi! Chốt kèm: mẻ bắt đầu ngay sau khi thu mẻ trước; vòng chậu invalid lúc snapshot → Mật Tạp, cấu hình mới áp dụng từ mẻ sau.

### G3-V2 — Designer B ký chốt + closing về vai trò của Reviewer

> ### **TUYÊN BỐ: CHỐT TOÀN BỘ GIAI ĐOẠN 3 (FINAL SPEC SIGN-OFF).**
>
> **Closing:** "Nếu Designer A và B là hai võ sĩ mải mê so găng trên võ đài để tìm ra thế đánh đẹp nhất — nơi cả hai vô tình chia sẻ chung những điểm mù và thỏa hiệp ngầm của kẻ trong cuộc — thì Reviewer (R) chính là trọng tài đứng ngoài quan sát với cái đầu lạnh: kẻ không quan tâm hai ta đã tranh luận mệt mỏi ra sao, mà chỉ lạnh lùng kiểm tra xem các sợi dây đài có chịu nổi lực va đập thực tế hay không." R là reality check tối hậu, bẻ gãy "đồng thuận sớm" (premature consensus) của hai designer.

---

*Kết thúc Giai đoạn 3. Plan đã cập nhật lên **v2** (S0 không đổi sức chứa, quả Star tách trục, kinh tế gỗ khóa chặt, S3 tách a/b với mốc 06:00 chung, snapshot đầu mẻ mật, không auto leo tầng, ALGO_VERSION trong save): [planting_depth_plan_2026-10-25.md](planting_depth_plan_2026-10-25.md).*

---

# PHẦN 6 — REVIEW THỨ HAI & BẢN v2.1 (không tranh luận — theo kết luận của reviewer)

Reviewer đọc bản v2, kết luận **đủ rõ để triển khai S0** và xử lý tốt phần lớn góp ý trước, nhưng yêu cầu bổ sung 5 quy tắc để tránh quyết định lại lúc code. Theo đúng kết luận của reviewer ("không cần chặn toàn bộ dự án hoặc mở thêm một vòng tranh luận lớn"), 5 quy tắc được thẩm định trực tiếp đối chiếu code và đưa vào plan v2.1 mà không mở vòng A–B mới:

1. **API chọn tầng tách bạch:** `EXACT_TIER` (mặc định mọi caller cũ — đơn thường dùng Thường, công thức dùng đúng tầng; thiếu là hiện đếm thiếu) / `TIER_SET(allowed, prefer)` (chỉ khi người chơi chủ động cho phép tập tầng; LOW/HIGH_FIRST là thứ tự trong tập, không phải leo tầng ngầm) / Perfect Delivery = `TIER_SET({Bạc, Vàng}, prefer Bạc)`. Hết mâu thuẫn "không tự leo tầng" vs "LOW_FIRST mặc định".
2. **Đổi hướng ghép áp dụng từ vụ tiếp theo:** đợt hiện tại (kể cả cây đang tích `fruit_work`) thu theo hướng cũ; cài `active_graft`/`pending_graft`, swap sau harvest.
3. **Snapshot mật tách "khóa công thức" khỏi "duy trì sản xuất":** Recipe ID khóa đầu mẻ; **tốc độ vẫn phụ thuộc hoa hiện có** — đối chiếu code xác nhận khớp kiến trúc sẵn (`honey_rate(pollination.source_id)`, hết hoa rơi về nhịp Mật Dại); giữ hoa vài giây đầu mẻ không ăn được tốc độ; tiến độ tích rồi không mất.
4. **Migration vườn hai pha, không mất gì:** tính toàn bộ phương án di chuyển → kiểm tra đủ chỗ (chậu trống, túi đủ) → đủ thì áp dụng, thiếu thì **trì hoãn chuyển đổi** giữ layout cũ + thông báo, chạy lại idempotent mỗi load; không bao giờ `add()` rồi bỏ phần dư.
5. **Layout màu mỡ theo Ô:** `stable_hash(cell_x, cell_y, LAYOUT_VERSION)` thay vì chỉ `column_index` (hash theo cột sẽ ra nguyên cột màu mỡ, sai mô tả 15–20% rải); LAYOUT_VERSION lưu trong save, hỗ trợ thuật toán cũ.

Kèm một chỉnh sửa hình ảnh: dấu "hứa Bạc" phải nằm trên cây/khung thông tin (`soil_focus_component` sẵn có) chứ không chỉ màu đất — vì ẩm bay hơi sau 6h trong khi cờ `watered` giữ cả vụ, đất khô dễ bị hiểu nhầm là mất Bạc.

**Trạng thái sau v2.1:** S0 được phép triển khai (API tầng đã chốt); mục 2–5 đã chốt sẵn cho slice tương ứng; hệ số kinh tế giữ nhãn thử nghiệm chờ phần 4.

**Bổ sung v2.1.1 (review thứ ba — 3 làm rõ lúc triển khai, đã áp thẳng):** (1) dòng Data của S0 còn sót `consume(LOW_FIRST)` — đã sửa theo API EXACT_TIER/TIER_SET; (2) thêm quy tắc **vận chuyển ≠ tiêu dùng**: gửi/rút Warehouse, chuyển stack, worker giao hàng về kho — chuyển nguyên trạng tầng 1:1, không áp chọn lọc tầng; (3) hoàn trả hive dư phải kèm điều kiện **đã thu hết mẻ mật đang chạy/chờ thu** (item hive trơ trụi không bảo toàn mẻ) — nằm trong nhóm "đủ điều kiện" của migration trì hoãn, không cần cơ chế chuyển trạng thái mẻ.
