# Bảng Thông Số Kinh Tế & Cấu Hình Nông Trại Chuẩn Online (Master Economy Specs)

> [!NOTE]
> Tài liệu này chuẩn hóa toàn bộ các thông số kinh tế, nhịp độ chơi và cấu hình kỹ thuật cho **Fantasy Farm** theo định hướng **Game Online**, đã qua kiểm chứng toán học nghiêm ngặt:
> - **Tiến trình đầu game**: Chốt **Phương án 1** (Người chơi mở Cột đất 1 trị giá 60,000 xu ngay sau khi hoàn thành chuỗi Onboarding; thử thách tích lũy bắt đầu từ Cột 2 trở đi).
> - **Thời gian sinh trưởng**: Trải dài từ **1 phút (60s)** đến **1 ngày (86,400s)**, phân tích theo lịch đăng nhập và giới hạn thao tác thực tế.
> - **Sản lượng (Yield)**: Áp dụng hệ số **x100** (thu hoạch 100 đến 500 đơn vị/ô đất).
> - **Stack túi đồ (`max_stack`)**: Giữ nguyên chuẩn **32,000** của dự án để bảo toàn tương thích save game cũ.
> - **Công thức Đơn hàng chuẩn xác**: Tính chính xác từng xu theo công thức $\text{Giá NPC} \times \text{Hệ Số Thưởng}$ (1.25x – 1.40x), giới hạn tối đa 2 loại sản phẩm theo đúng [`OrderDefinition`](file:///c:/projects/fantasy-farm/scripts/order_definition.gd#L11).
> - **Khẩu phần ăn & Hoàn vốn gia súc**: Tính toán đồng bộ trên cùng 1 công thức toán học chặt chẽ, bao gồm cả giai đoạn con non, chu kỳ sản phẩm và tổng lãi ròng cả đời 14 ngày.
> - **Quy tắc Offline**: Xử lý tiêu thụ máng cấp chuồng, lượng no/nước còn lại trong người con vật và chống tính sản phẩm trùng lặp.

---

## 1. Thiết Kế Tiến Trình Đầu Game & Tài Sản Khởi Đầu (Starter Assets)

### A. Chốt Phương Án 1 Cho Mốc Mở Đất Đầu Tiên (60,000 Xu)
* **Quy tắc thiết kế**: Mua thêm cột thứ 5 là phần thưởng tốt nghiệp chuỗi Onboarding (Tutorial Graduation Moment).
  * Đất mở sẵn: **4 cột × 34 hàng = 136 ô**. Lượt mua đất đầu tiên mở cột thứ 5, giá 60,000 xu.
  * 24 hạt Cà rốt miễn phí: $24 \times 100 \times 35 = 84,000$ xu.
  * Tiền ví khởi đầu: $10,000$ xu.
  * Thưởng 5 bước Onboarding ban đầu: $5\text{k} + 5\text{k} + 5\text{k} + 10\text{k} + 10\text{k} = 35,000$ xu.
  * $\rightarrow$ **Tổng tiền sau vụ đầu và 5 thưởng Onboarding**: $129,000$ xu.
  * Người chơi đủ tiền mua ngay lượt mở đất 1 — cột thứ 5 (60,000 xu) và còn dư 69,000 xu để tái đầu tư.
  * **Thử thách tích lũy thực sự**: Bắt đầu từ **Cột 2 (150,000 xu)**, **Cột 3 (350,000 xu)** và các cột tiếp theo.

### B. Xử Lý Bẫy Tài Sản Khởi Đầu Miễn Phí Trên Map
* **Hồ sơ mới (New Game Profile)**:
  * Scene [`pond_pen.tscn`](file:///c:/projects/fantasy-farm/scenes/animals/pond_pen.tscn#L75-L191): Khởi đầu là chuồng ao trống (không có sẵn 5 vịt, 6 ngỗng để tránh tạo ra 763,200 xu miễn phí/ngày). Người chơi phải tích tiền mua từ Shop giống như chuồng gà và chuồng bò. *(Save cũ vẫn giữ nguyên đàn đã có)*.
  * Scene [`flower_garden.tscn`](file:///c:/projects/fantasy-farm/scenes/flowers/flower_garden.tscn#L31-L89): Toàn bộ xô hạt hoa miễn phí ban đầu sẽ bị khóa. Khu vườn hoa mở khóa như một phần thưởng sau khi người chơi mua thêm cột thứ 5.

---

## 2. Bảng 1: 22 Cây Trồng Ruộng (Field Crops)
*Thời gian từ 1 phút đến 24 giờ. Sản lượng từ 100 đến 500 củ/quả mỗi ô.*

| STT | Cây trồng | Mã ID | Thời gian lớn | Giá hạt mua (xu) | Sản lượng / ô | Giá bán / 1 đơn vị (xu) | Doanh thu / ô (xu) | Lãi ròng / ô (xu) | Lãi quy đổi / ô / giờ (xu) | Phân tầng Online Loop |
| :---: | :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **1** | **Cà rốt** | `carrot` | **60s (1p)** | **2,700** | **100** | 35 | 3,500 | **+800** | **48,000** | Cày cuốc online liên tục |
| **2** | **Củ cải đỏ** | `radish` | **120s (2p)** | **3,600** | **100** | 50 | 5,000 | **+1,400** | 42,000 | Vòng quay vốn nhanh |
| **3** | **Củ cần vàng** | `parsnip` | **180s (3p)** | **4,500** | **100** | 65 | 6,500 | **+2,000** | 40,000 | Session ngắn 5–10 phút |
| **4** | **Củ dền** | `beetroot` | **240s (4p)** | **5,500** | **100** | 80 | 8,000 | **+2,500** | 37,500 | Đơn hàng củ hầm |
| **5** | **Bắp cải** | `cabbage` | **300s (5p)** | **6,800** | **100** | 100 | 10,000 | **+3,200** | 38,400 | Cuối session 5 phút |
| **6** | **Khoai tây** | `potato` | **600s (10p)** | **8,000** | **200** | 65 | 13,000 | **+5,000** | 30,000 | Nghỉ tay uống nước |
| **7** | **Cà chua** | `tomato` | **900s (15p)** | **9,500** | **200** | 80 | 16,000 | **+6,500** | 26,000 | Giải lao ngắn |
| **8** | **Dưa chuột** | `cucumber` | **1,200s (20p)** | **12,000** | **200** | 100 | 20,000 | **+8,000** | 24,000 | Giữa giờ làm việc |
| **9** | **Hành tây** | `onion` | **1,500s (25p)** | **13,000** | **200** | 110 | 22,000 | **+9,000** | 21,600 | Nửa tiếng |
| **10**| **Lúa mì** | `wheat` | **1,800s (30p)** | **6,000** | **400** | 30 | 12,000 | **+6,000** | 12,000 | **Nguyên liệu tự xay cám gà** |
| **11**| **Tỏi** | `garlic` | **2,700s (45p)** | **9,000** | **500** | 35 | 17,500 | **+8,500** | 11,333 | Sản lượng tép tỏi lớn |
| **12**| **Tỏi tây** | `leek` | **3,600s (1h)** | **8,000** | **300** | 60 | 18,000 | **+10,000** | 10,000 | Hẹn giờ quay lại app sau 1 tiếng |
| **13**| **Bông cải xanh** | `broccoli` | **5,400s (1.5h)** | **12,000** | **100** | 280 | 28,000 | **+16,000** | 10,666 | Hẹn giờ nghỉ trưa |
| **14**| **Ngô / Bắp** | `corn` | **7,200s (2h)** | **5,000** | **300** | 50 | 15,000 | **+10,000** | 5,000 | **Nguyên liệu tự xay cám gia súc** |
| **15**| **Cà tím** | `eggplant` | **10,800s (3h)** | **12,000** | **200** | 150 | 30,000 | **+18,000** | 6,000 | Phiên buổi chiều |
| **16**| **Ớt hiểm** | `chili_pepper` | **14,400s (4h)** | **15,000** | **200** | 200 | 40,000 | **+25,000** | 6,250 | Nửa ngày làm việc |
| **17**| **Ớt chuông xanh** | `green_bell_pepper` | **21,600s (6h)** | **16,000** | **200** | 250 | 50,000 | **+34,000** | 5,666 | Trồng sáng $\rightarrow$ chiều thu hoạch |
| **18**| **Ớt chuông vàng** | `yellow_bell_pepper` | **28,800s (8h)** | **18,000** | **200** | 300 | 60,000 | **+42,000** | 5,250 | Trọn 1 ca học / làm việc |
| **19**| **Ớt chuông đỏ** | `bell_pepper` | **36,000s (10h)** | **20,000** | **200** | 350 | 70,000 | **+50,000** | 5,000 | Trọn 1 ngày vắng mặt |
| **20**| **Hướng dương** | `sunflower` | **43,200s (12h)** | **25,000** | **100** | 850 | 85,000 | **+60,000** | 5,000 | **Kích thích tổ ong lấy mật ngày** |
| **21**| **Dâu tây** | `strawberry` | **64,800s (18h)** | **30,000** | **500** | 200 | 100,000 | **+70,000** | 3,888 | Trồng ngủ qua đêm dài |
| **22**| **Bí ngô** | `pumpkin` | **86,400s (24h)** | **50,000** | **100** | 2,900 | 290,000 | **+240,000** | **10,000** | **JACKPOT 1 NGÀY: +240K/ô** |

### Kịch Bản Mục Tiêu Cần Kiểm Chứng (Hypothetical Pacing)
*So sánh dựa trên giới hạn toán học và thói quen đăng nhập thực tế (tính theo LÃI RÒNG sau tiền giống):*
* **1. Cày liên tục 2.5 giờ (Hardcore Session)**:
  * Cà rốt (1p): Trần lý thuyết 150 vụ $\times$ 800 xu = **120,000 xu/ô**. Với hiệu suất thao tác thực tế (~75% do tốn thời gian tưới, thu hoạch, bán đồ), dự kiến đạt **~90,000 xu/ô**.
  * Củ cải đỏ (2p): Trần lý thuyết 75 vụ $\times$ 1,400 xu = **105,000 xu/ô**. Thực tế dự kiến đạt **~80,000 xu/ô**.
* **2. Vào mỗi giờ (Casual)**: Đăng nhập 8 lần/ngày gieo Tỏi tây (1h) hoặc Ngô (2h) $\rightarrow$ Lãi: **40,000 – 80,000 xu/ô/ngày**.
* **3. Sáng gieo - Tối gặt (Commute 2 lần/ngày)**: Thu 2 vụ Ớt chuông đỏ (10h) $\rightarrow$ Lãi: $2 \times 50,000 = \mathbf{100,000\text{ xu/ô/ngày}}$ (hoặc Ớt vàng 8h: $2 \times 42,000 = \mathbf{84,000\text{ xu}}$).
* **4. Mỗi ngày vào 1 lần (Overnight/Idle)**: Thu 1 vụ Bí ngô (24h) $\rightarrow$ Lãi: **240,000 xu/ô/ngày** (hoặc Dâu tây 18h: **70,000 xu**).
*(Người chơi tích cực hoàn toàn có thể kết hợp trồng Bí ngô ở các ô xa và cày Cà rốt ở các ô gần để tối ưu dòng tiền).*

---

## 3. Bảng 2: 10 Loài Hoa Vườn (Garden Flowers)

| STT | Tên hoa | Mã ID | Thời gian lớn | Giá hạt mua (xu) | Sản lượng / chậu | Giá bán / 1 bông (xu) | Doanh thu / chậu (xu) | Lãi ròng / chậu (xu) | Hiệu ứng cộng hưởng |
| :---: | :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **1** | **Hoa Hồng Nhung** | `flower_01` | **300s (5p)** | 10,000 | **100** | 180 | 18,000 | **+8,000** | Duy trì tổ ong hoạt động |
| **2** | **Hoa Cúc Vàng** | `flower_02` | **900s (15p)** | 15,000 | **100** | 280 | 28,000 | **+13,000** | Tăng 10% tốc độ cây ruộng gần đó |
| **3** | **Hoa Oải Hương** | `flower_03` | **1,800s (30p)** | 20,000 | **100** | 380 | 38,000 | **+18,000** | Đơn hàng hương liệu |
| **4** | **Hoa Tulip Xanh** | `flower_04` | **3,600s (1h)** | 25,000 | **100** | 500 | 50,000 | **+25,000** | Hoa xuất khẩu |
| **5** | **Hoa Bách Hợp** | `flower_05` | **7,200s (2h)** | 30,000 | **100** | 650 | 65,000 | **+35,000** | Đơn hàng tiệc cưới |
| **6** | **Hoa Cẩm Chướng** | `flower_06` | **14,400s (4h)** | 40,000 | **100** | 900 | 90,000 | **+50,000** | **Tạo Mật Ong Hoa Quý (+100% giá)** |
| **7** | **Hoa Phong Lan** | `flower_07` | **28,800s (8h)** | 50,000 | **100** | 1,300 | 130,000 | **+80,000** | Hoa quý tộc |
| **8** | **Hoa Anh Thảo** | `flower_08` | **43,200s (12h)** | 60,000 | **100** | 1,800 | 180,000 | **+120,000** | Khách VIP thu mua |
| **9** | **Hoa Thược Dược** | `flower_09` | **64,800s (18h)** | 75,000 | **100** | 2,500 | 250,000 | **+175,000** | Đơn hàng cung đình |
| **10**| **Hoa Tiên Cảnh** | `flower_10` | **86,400s (24h)** | 100,000 | **100** | 4,500 | 450,000 | **+350,000** | **Báu vật ngàn hoa** |

---

## 4. Bảng 3: 7 Loài Vật Nuôi & Chu Kỳ Hoàn Vốn Chuẩn Xác

### A. Quy Chuẩn Khẩu Phần Ăn & Nước Uống Đồng Bộ
* **Tốc độ đói**: `satiety_depletion_seconds = 3600.0` (1 giờ tiêu hao 100 điểm no).
* **Tốc độ khát**: `hydration_depletion_seconds = 3600.0` (1 giờ tiêu hao 100 điểm nước).
* 1 đơn vị máng hồi phục 40 điểm no/nước $\rightarrow$ Mỗi con vật tiêu thụ: $24 \times 100 / 40 = \mathbf{60\text{ đơn vị thức ăn & } 60\text{ đơn vị nước/ngày}}$.
* Bao cám 200 đơn vị giá 2,000 xu $\rightarrow$ Chi phí thức ăn: $60 \times 10\text{ xu} = \mathbf{600\text{ xu/con/ngày}}$ ($25\text{ xu/giờ}$).

### B. Bảng Hoàn Vốn & Lãi Ròng Cả Đời (Chuẩn Hóa Cho Cả 7 Loài)
*Vòng đời vật nuôi: $T_{life} = 14\text{ ngày} = 336\text{ giờ}$.*
*Chi phí ăn cả đời: $C_{life\_feed} = 336\text{ giờ} \times 25\text{ xu/giờ} = \mathbf{8,400\text{ xu}}$.*
$$\text{Lãi 1 lứa} = \text{Doanh thu lứa} - (\text{Chu kỳ giờ} \times 25\text{ xu})$$
$$\text{Vốn cần bù} = \text{Giá mua giống} + (\text{Giờ nuôi non} \times 25\text{ xu})$$
$$\text{Thời gian hoàn vốn} = \text{Giờ nuôi non} + (\lceil \text{Vốn} / \text{Lãi lứa} \rceil \times \text{Chu kỳ giờ})$$
$$\text{Tổng Lãi Cả Đời (14 ngày)} = (\lfloor (336 - T_{juv}) / t_{cycle} \rfloor \times \text{Doanh thu lứa}) - \text{Giá mua giống} - 8,400$$

| Loài vật | Mã ID | Chuồng | Giá giống (xu) | Nuôi non (giờ) | Chi phí non (xu) | Sản phẩm | Chu kỳ lứa | Doanh thu lứa | Lãi ròng 1 lứa (xu) | Lứa cần hoàn vốn | **Tổng thời gian hoàn vốn từ lúc mua** | **Tổng Lãi Cả Đời (14 ngày)** |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Gà** | `chicken` | Coop | **16,000** | **1h** | 25 | 🥚 Trứng gà | **15p (0.25h)** | 800 | **793.75** | **21 lứa** | **6 giờ 15 phút** | **+1,047,600 xu** |
| **Vịt** | `duck` | Pond | **25,000** | **2h** | 50 | 🥚 Trứng vịt | **30p (0.5h)** | 1,500 | **1,487.50** | **17 lứa** | **10 giờ 30 phút** | **+968,600 xu** |
| **Ngỗng** | `goose` | Pond | **36,000** | **4h** | 100 | 🪶 Trứng ngỗng | **1h** | 2,800 | **2,775.00** | **14 lứa** | **18 giờ 00 phút** | **+885,200 xu** |
| **Cừu** | `sheep` | Barn | **50,000** | **6h** | 150 | 🧶 Lông cừu | **3h** | 6,500 | **6,425.00** | **8 lứa** | **30 giờ (1.25 ngày)**| **+656,600 xu** |
| **Bò** | `cow` | Barn | **75,000** | **8h** | 200 | 🥛 Sữa tươi | **4h** | 8,000 | **7,900.00** | **10 lứa** | **48 giờ (Đúng 2 ngày)**| **+572,600 xu** |
| **Lợn** | `pig` | Barn | **100,000** | **12h** | 300 | 🍄 Nấm Truffle | **8h** | 18,000 | **17,800.00** | **6 lứa** | **60 giờ (2.5 ngày)** | **+611,600 xu** |
| **Ngựa** | `horse` | Barn | **150,000** | **24h** | 600 | 💩 Phân compost | **12h** | 25,000 | **24,700.00** | **7 lứa** | **108 giờ (4.5 ngày)**| **+491,600 xu** |

### C. Quy Chuẩn Dự Trữ Máng Ăn & Nước Cho Cả Chuồng (24 Giờ Offline)
*Mỗi chuồng hiện có 2 máng ăn và 2 máng nước. Để đảm bảo nuôi cả đàn 24 giờ:*
* **Chuồng Coop (30 gà)**: Cần $30 \times 60 = \mathbf{1,800\text{ đơn vị thức ăn & } 1,800\text{ đơn vị nước/ngày}}$. Đặt mỗi máng `capacity = 1,200` $\rightarrow$ 2 máng = 2,400 đơn vị (dư dả 24h).
* **Chuồng Barn (36 gia súc)**: Cần $36 \times 60 = \mathbf{2,160\text{ đơn vị thức ăn & } 2,160\text{ đơn vị nước/ngày}}$. Đặt mỗi máng `capacity = 1,200 – 1,500` $\rightarrow$ 2 máng = 2,400 – 3,000 đơn vị (đủ 24h).
* **Chuồng Pond (20 vịt/ngỗng)**: Cần $20 \times 60 = \mathbf{1,200\text{ đơn vị thức ăn và 1,200 đơn vị nước/ngày}}$. Mỗi loại có 2 máng `capacity = 1,200` (tổng 2,400 đơn vị mỗi loại). Nước bơi trong ao không thay thế nước uống từ máng.

---

## 5. Bảng 4: 7 Cây Lâu Năm & Cây Lấy Gỗ (Perennial Trees)

### A. 4 Cây Ăn Quả (Fruit Trees)
| Cây trồng | Mã ID | Giá giống (xu) | Thời gian lớn | Chu kỳ ra quả | Sản lượng / đợt | Giá bán / 1 quả (xu) | Doanh thu mỗi đợt (xu) | **Thời gian hoàn vốn tiền giống** |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **Cây Táo** | `apple` | 20,000 | 12 giờ | **4 giờ** | **300 quả** | 25 | **7,500** | **24 giờ** (12h lớn + 3 đợt quả $\times$ 4h) |
| **Cây Đào** | `peach` | 20,000 | 12 giờ | **5 giờ** | **300 quả** | 30 | **9,000** | **27 giờ** (12h lớn + 3 đợt quả $\times$ 5h) |
| **Cây Lê** | `pear` | 25,000 | 16 giờ | **6 giờ** | **300 quả** | 38 | **11,400** | **34 giờ** (16h lớn + 3 đợt quả $\times$ 6h) |
| **Cây Anh Đào**| `cherry`| 30,000 | 20 giờ | **8 giờ** | **300 quả** | 55 | **16,500** | **36 giờ** (20h lớn + 2 đợt quả $\times$ 8h) |

### B. 3 Cây Lấy Gỗ (Timber Trees)
*Thời gian lớn ban đầu: **24 giờ**. Khi đốn hạ: Thu **400 Khối Gỗ (10,000 xu tiền mặt)** + **1 Cây Giống**. Gốc cây đợi 120s rồi mọc lại sau 50% thời gian lớn ban đầu ($120s + 12h = \mathbf{12\text{ giờ } 2\text{ phút}}$).*

| Cây gỗ | Mã ID | Giá mua giống shop | Thời gian lớn ban đầu | Thời gian tái sinh từ gốc | Sản lượng thu hoạch | Giá bán gỗ / khối (xu) | Doanh thu tiền mặt / lần chặt | Cơ chế phần thưởng |
| :--- | :--- | :---: | :---: | :---: | :--- | :---: | :---: | :--- |
| **Cây Sồi** | `oak` | 25,000 | **24 giờ** | **12 giờ 2 phút** | **400 Gỗ + 1 Giống** | 25 | **10,000 xu** | Gốc tự mọc lại; nhận 1 cây giống để nhân rộng rừng |
| **Bạch Dương**| `birch` | 25,000 | **24 giờ** | **12 giờ 2 phút** | **400 Gỗ + 1 Giống** | 25 | **10,000 xu** | Gốc tự mọc lại; nhận 1 cây giống để nhân rộng rừng |
| **Vân Sam** | `spruce` | 25,000 | **24 giờ** | **12 giờ 2 phút** | **400 Gỗ + 1 Giống** | 25 | **10,000 xu** | Gốc tự mọc lại; nhận 1 cây giống để nhân rộng rừng |

---

## 6. Bảng 5: Tổ Ong & Mật Ong (Beehives & Honey)

| Loại Mật Ong | Mã ID | Chu kỳ sinh mật | Điều kiện kích hoạt | Sản lượng / mẻ | Giá bán / 1 hũ (xu) | Doanh thu / mẻ (xu) | Ghi chú & Lợi nhuận |
| :--- | :--- | :---: | :--- | :---: | :---: | :---: | :--- |
| **Tổ ong** | `beehive` | — | Mua tại shop: **150,000 xu** | — | — | — | Tăng 10% tốc độ cây ruộng gần đó |
| **Mật Ong Rừng** | `wild_honey` | **24 giờ** | Không có hoa chuyên biệt | **100 hũ** | 150 | **15,000** | Lợi nhuận thụ động cơ bản |
| **Mật Hướng Dương** | `sunflower_honey`| **18 giờ** | Có luống Hoa Hướng Dương gần tổ | **100 hũ** | 250 | **25,000** | Thời gian giảm 25% so với 24 giờ (tốc độ ×4/3) |
| **Mật Ong Hoa Quý** | `floral_honey` | **12 giờ** | Có chậu hoa (`flower_06`–`10`) gần tổ | **100 hũ** | 400 | **40,000** | **Tối đa 80,000 xu/ngày nếu thu đủ 2 mẻ; offline chỉ trữ 1 mẻ** |

---

## 7. Bảng 6: Bảng Đơn Hàng Chuẩn Hóa ([`OrderBoard`](file:///c:/projects/fantasy-farm/components/orders/order_board.gd))
*Áp dụng công thức chính xác: Đơn 1 loại hàng = $\text{Giá NPC} \times 1.25$; Đơn 2 loại hàng = $\text{Giá NPC} \times 1.40$. Giới hạn tối đa 2 loại sản phẩm.*

| Tên đơn hàng | Mã ID | Yêu cầu số lượng (Tối đa 2 loại) | Giá trị bán lẻ NPC | Hệ số | **Thưởng Đơn Hàng Chuẩn Xác (xu)** | Lãi vượt mức khi giao đơn |
| :--- | :--- | :--- | :---: | :---: | :---: | :---: |
| **Xe Cà Chua Công Nghiệp** | `tomato_crate_bulk` | 1,000 Cà chua | 80,000 xu | 1.25x | **100,000** | **+20,000 xu** |
| **Khoai Tây Quân Đội** | `potato_military` | 2,000 Khoai tây | 130,000 xu | 1.25x | **162,500** | **+32,500 xu** |
| **Combo Salad Tươi (2 món)** | `grand_salad_basket` | 1,000 Cà chua + 800 Bắp cải | 160,000 xu | 1.40x | **224,000** | **+64,000 xu** |
| **Súp Nóng Mùa Đông (2 món)** | `winter_soup_barrel` | 1,000 Khoai tây + 1,000 Ngô | 115,000 xu | 1.40x | **161,000** | **+46,000 xu** |
| **Chuyến Xe Sữa & Trứng (2 món)** | `dairy_egg_express` | 1,000 Trứng gà + 400 Sữa tươi | 40,000 xu | 1.40x | **56,000** | **+16,000 xu** |
| **Hợp Đồng Xuất Khẩu Bí Ngô** | `royal_pumpkin_contract` | 1,000 Bí ngô | 2,900,000 xu | 1.25x | **3,625,000** | **+725,000 xu** |

---

## 8. Quy Tắc Sức Chứa & Xử Lý Tiêu Thụ Offline (Storage & Offline Rules)

1. **Giới hạn lứa sản phẩm Offline**:
   * Cây ăn quả và Tổ ong: **Chỉ trữ tối đa 1 lứa sản phẩm** (300 quả hoặc 100 hũ mật). Không tích lũy dồn nhiều lứa khi offline dài ngày.
2. **Cơ chế tiêu thụ Offline cấp Chuồng (`AnimalPen`)**:
   * Đàn vật nuôi dùng chung tổng trữ lượng máng trong chuồng.
   * **Quy tắc dừng sản xuất**: Máng cạn không làm con vật ngừng sản xuất ngay. Con vật tiếp tục tiêu hao lượng no/nước đang có sẵn trong bụng (tối đa thêm 1 giờ). Sản xuất chỉ dừng khi chỉ số no HOẶC nước trong người con vật thực sự tụt về 0.
   * **Chống tính trùng lặp sản phẩm**: Lưu timestamp `_updated_at` đồng bộ cùng trạng thái chuồng và máng vào DTO save. Khi nạp lại save, chỉ tính lượng thời gian trôi qua từ mốc `_updated_at`.
   * Không tính sản xuất cho vật nuôi đã vượt quá tuổi thọ (`lifespan_seconds = 14 ngày`).

---

## 9. Phân Loại Hạng Mục Cần Cập Nhật (Roadmap Triển Khai)

### Nhóm A: Chỉnh Sửa Thông Số Ngay (File Resource `.tres` và `.gd`)
1. **Giá bán nông sản**: Sửa file [`resources/shops/produce_prices.tres`](file:///c:/projects/fantasy-farm/resources/shops/produce_prices.tres).
2. **Giá mua hạt giống, con giống, thức ăn**: Sửa file [`resources/shops/farm_supply.tres`](file:///c:/projects/fantasy-farm/resources/shops/farm_supply.tres) và `resources/shops/animals/*.tres`.
3. **Thời gian lớn & Sản lượng cây trồng**: Sửa các file `crops/field/*/*.tres`.
4. **Thời gian lớn & Sản lượng hoa**: Sửa các file `flowers/definitions/*.tres`.
5. **Khẩu phần ăn, nước & Chu kỳ vật nuôi**: Sửa `satiety_depletion_seconds = 3600.0` và `hydration_depletion_seconds = 3600.0` trong `animals/definitions/*.tres` và chu kỳ sản xuất trong `animals/productions/*.tres`.
6. **Bảng đơn hàng chuẩn xác**: Sửa file [`resources/orders/farm_orders.tres`](file:///c:/projects/fantasy-farm/resources/orders/farm_orders.tres) theo bảng ở Mục 7.
7. **Dung lượng máng thức ăn/nước**: Nâng `capacity = 1200` trong `world/main_world.tscn`.

### Nhóm B: Tính Năng Mới & Logic Code (Cần Viết Code Logic Mới)
1. **Cơ chế mô phỏng máng ăn cấp chuồng khi offline**: Viết hàm tính tổng thức ăn/nước tiêu thụ trong `AnimalNeedsComponent.update_at()` có tính lượng no/nước trong người con vật sau khi máng cạn.
2. **Khóa xô hạt hoa và dọn chuồng ao cho Profile mới**: Viết logic kiểm tra trạng thái game mới để không cấp 11 con thủy cầm và 60 hạt hoa cao cấp ngay từ phút đầu.
3. **Hệ thống di chuyển save (Save Migration)**: Bảo đảm các ID đơn hàng cũ hoặc save game cũ không bị lỗi khi nâng cấp sang bộ thông số mới.
