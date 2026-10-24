# Bảng thông số nông trại — baseline trước cân bằng

Chụp ngày **24/10/2026**, từ Resource được Godot 4.7.2 nạp cùng giá trị mặc định trong script và scene MainWorld hiện tại. Đây là cấu hình hồ sơ mới, không đọc save cá nhân. **Chưa thay giá, sản lượng, thời gian hoặc luật gameplay.**

Bản dữ liệu đầy đủ: [farm_parameters_2026-10-24.json](farm_parameters_2026-10-24.json). Tên Việt trong bảng dùng để đọc; ID trong JSON là khóa đối chiếu.

## 1. Quy ước tính

- Đơn vị tiền: xu; thời gian là giây thực, không phải thời gian ngày/đêm rút gọn.
- Doanh thu một vụ = sản lượng × giá bán NPC. Lãi sau tiền giống = doanh thu − giá một hạt/cây giống; chưa tính đi lại, thao tác, diện tích, phân bón hoặc công cụ.
- Doanh thu/giờ vật nuôi là phép quy đổi lý thuyết khi đã trưởng thành, sống, luôn đủ ăn/nước và không có buff; không phải số đo chơi thử hay cam kết thu nhập offline.
- Thưởng đơn hàng là khoản nhận thay cho việc bán cùng số hàng; không cộng cả giá bán NPC lẫn tiền thưởng đơn vào doanh thu một lần giao.

## 2. Hồ sơ mới và giới hạn chung

| Thông số | Giá trị hiện tại |
| --- | --- |
| Tiền khởi đầu | 1.000 xu |
| Túi đồ | 64 ô; hotbar 6 ô đầu |
| Công cụ khởi đầu | 1 cuốc + 1 bình tưới; dùng lại, không tiêu hao theo lượt |
| Hạt khởi đầu | 12 hạt cà rốt |
| Thức ăn trong túi khởi đầu | 5 gói gia cầm |
| Vật tư trên map | 5 gói gia súc, 5 gói gia cầm, 6 hạt mỗi loại hoa 01–10 |
| Đất trong vùng mở rộng | 48 cột × 34 hàng = 1.632 ô hình học |
| Đất mở sẵn | 1 cột = 34 ô hình học; số ô trồng thực còn phụ thuộc tile cho phép và vật cản |
| Trần tiền trong ví | 1.000.000.000 xu |
| Stack nông sản ruộng và sản phẩm vật nuôi | 32.000/ô theo Resource hiện tại |
| Stack hạt giống, hoa | 99/ô; công cụ 1/ô |

Nguồn: [components/tool_selection_component.gd](C:/projects/fantasy-farm/components/tool_selection_component.gd), [components/inventory_component.gd](C:/projects/fantasy-farm/components/inventory_component.gd), [components/wallet_component.gd](C:/projects/fantasy-farm/components/wallet_component.gd), [world/main_world.tscn](C:/projects/fantasy-farm/world/main_world.tscn).

## 3. Cây ruộng — 22 loại

Mỗi vụ tiêu thụ một hạt và cần trồng lại sau thu hoạch. Không có buff trong bảng.

| Cây / ID | Mua hạt | Lớn (giây) | Sản lượng/vụ | Bán/đơn vị | Doanh thu/vụ | Lãi sau giống/vụ |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Củ dền (`beetroot`) | 10 | 10 | 100 | 8 | 800 | 790 |
| Ớt chuông (`bell_pepper`) | 10 | 10 | 200 | 10 | 2.000 | 1.990 |
| Bông cải xanh (`broccoli`) | 10 | 10 | 100 | 12 | 1.200 | 1.190 |
| Bắp cải (`cabbage`) | 10 | 10 | 200 | 10 | 2.000 | 1.990 |
| Cà rốt (`carrot`) | 10 | 10 | 100 | 5 | 500 | 490 |
| Ớt cay (`chili_pepper`) | 10 | 10 | 200 | 8 | 1.600 | 1.590 |
| Bắp (`corn`) | 10 | 10 | 100 | 7 | 700 | 690 |
| Dưa leo (`cucumber`) | 10 | 10 | 100 | 7 | 700 | 690 |
| Cà tím (`eggplant`) | 10 | 10 | 200 | 10 | 2.000 | 1.990 |
| Tỏi (`garlic`) | 10 | 10 | 600 | 9 | 5.400 | 5.390 |
| Ớt chuông xanh (`green_bell_pepper`) | 10 | 10 | 100 | 9 | 900 | 890 |
| Tỏi tây (`leek`) | 10 | 10 | 300 | 8 | 2.400 | 2.390 |
| Hành tây (`onion`) | 10 | 10 | 400 | 6 | 2.400 | 2.390 |
| Củ cải vàng (`parsnip`) | 10 | 10 | 300 | 8 | 2.400 | 2.390 |
| Khoai tây (`potato`) | 10 | 10 | 200 | 6 | 1.200 | 1.190 |
| Bí ngô (`pumpkin`) | 10 | 10 | 200 | 18 | 3.600 | 3.590 |
| Củ cải (`radish`) | 10 | 10 | 100 | 5 | 500 | 490 |
| Dâu tây (`strawberry`) | 10 | 10 | 100 | 12 | 1.200 | 1.190 |
| Hướng dương (`sunflower`) | 10 | 10 | 200 | 10 | 2.000 | 1.990 |
| Cà chua (`tomato`) | 10 | 10 | 100 | 7 | 700 | 690 |
| Lúa mì (`wheat`) | 10 | 10 | 400 | 4 | 1.600 | 1.590 |
| Ớt chuông vàng (`yellow_bell_pepper`) | 10 | 10 | 200 | 10 | 2.000 | 1.990 |

**Luật nước hiện chạy:** cây ruộng có thể gieo trên đất đã cuốc khô hoặc ướt; đồng hồ lớn bắt đầu ngay khi gieo. `Crop.refresh` và lịch tăng trưởng không chặn tiến độ khi đất khô. Đất tưới giữ ẩm 21.600 giây (6 giờ cơ sở), nhưng độ ẩm hiện không phải điều kiện để cây tiếp tục lớn/thu hoạch. Đây là điểm khác với lời hướng dẫn “crops need moist soil”, cần quyết định ở lượt cân bằng/sửa luật; chưa sửa trong bảng này.

Nguồn: [resources/shops/farm_supply.tres](C:/projects/fantasy-farm/resources/shops/farm_supply.tres), [resources/shops/produce_prices.tres](C:/projects/fantasy-farm/resources/shops/produce_prices.tres), [components/farming_controller.gd](C:/projects/fantasy-farm/components/farming_controller.gd), [components/crop.gd](C:/projects/fantasy-farm/components/crop.gd); Resource cây nằm trong `crops/field/`.

## 4. Hoa — 10 loại

| Hoa / ID | Mua hạt | Lớn sau tưới (giây) | Bông/vụ | Bán/bông | Lãi sau giống/vụ |
| --- | ---: | ---: | ---: | ---: | ---: |
| flower_01 | 15 | 120 | 1 | 20 | 5 |
| flower_02 | 15 | 120 | 1 | 20 | 5 |
| flower_03 | 15 | 120 | 1 | 20 | 5 |
| flower_04 | 15 | 120 | 1 | 20 | 5 |
| flower_05 | 15 | 120 | 1 | 20 | 5 |
| flower_06 | 15 | 120 | 1 | 20 | 5 |
| flower_07 | 15 | 120 | 1 | 20 | 5 |
| flower_08 | 15 | 120 | 1 | 20 | 5 |
| flower_09 | 15 | 120 | 1 | 20 | 5 |
| flower_10 | 15 | 120 | 1 | 20 | 5 |

Hoa phải tưới để bắt đầu đồng hồ lớn. Thu hoạch xong cần gieo lại vào chậu. Các chậu/trang trí của khu hoa là tài nguyên không gian riêng, không quy đổi ngang với một ô ruộng trong so sánh thu nhập.

Nguồn: [components/flowers/flower_pot.gd](C:/projects/fantasy-farm/components/flowers/flower_pot.gd), `flowers/definitions/` và hai catalog giá phía trên.

## 5. Vật nuôi — 7 loài

| Loài | Mua/con | Bán lại non / trưởng thành | Sản phẩm | Chu kỳ (giây) | Lượng/chu kỳ | Bán/đơn vị | Doanh thu/giờ lý thuyết |
| --- | ---: | ---: | --- | ---: | ---: | ---: | ---: |
| Gà | 160 | 80 / 120 | Chicken Egg | 30 | 1 | 8 | 960 |
| Bò | 720 | 360 / 540 | Cow Milk | 60 | 1 | 24 | 1.440 |
| Vịt | 240 | 120 / 180 | Duck Egg | 40 | 1 | 10 | 900 |
| Ngỗng | 320 | 160 / 240 | Goose Egg | 50 | 1 | 14 | 1.008 |
| Ngựa | 960 | 480 / 720 | Compost | 60 | 1 | 6 | 360 |
| Heo | 480 | 240 / 360 | Truffle | 60 | 1 | 40 | 2.400 |
| Cừu | 560 | 280 / 420 | Wool | 60 | 1 | 30 | 1.800 |

| Nhu cầu / vòng đời | Gia cầm: gà, vịt, ngỗng | Gia súc: bò, cừu, heo, ngựa |
| --- | ---: | ---: |
| Từ tuổi 0 đến trưởng thành | 86.400 giây = 24 giờ | 86.400 giây = 24 giờ |
| Tuổi thọ tổng từ tuổi 0 | 1.209.600 giây = 14 ngày | 1.209.600 giây = 14 ngày |
| 100% no → 0 nếu không ăn | 600 giây = 10 phút | 600 giây = 10 phút |
| 100% nước → 0, trời bình thường | 300 giây = 5 phút | 600 giây = 10 phút |
| Ngưỡng tìm máng ăn/uống | ≤50% | ≤50% |
| Đơn vị thức ăn/nước mỗi lần | 1 / 1 | 1 / 1 |
| Tăng nhu cầu mỗi đơn vị máng | +40 điểm phần trăm, tối đa 100 | +40 điểm phần trăm, tối đa 100 |

Các Resource sản xuất hiện dùng WORLD_DROP: phụ phẩm rơi trong thế giới; hệ thống vẫn hỗ trợ DIRECT_COLLECTION nhưng không gán cho 7 Resource hiện tại. Không sản xuất khi còn non, chết, no=0 hoặc nước=0. Tuổi, no/khát và phần thời gian đủ điều kiện sản xuất tiến theo thời gian thực khi offline; AI đi tới máng là hành vi lúc chạy game, không tự coi toàn bộ lượng dự trữ trong máng là khẩu phần đã ăn trong thời gian đóng game.

Nguồn: `animals/definitions/`, `animals/productions/`, `resources/shops/animals/`, [scripts/animal_shop_offer.gd](C:/projects/fantasy-farm/scripts/animal_shop_offer.gd), [components/animals/animal_needs_component.gd](C:/projects/fantasy-farm/components/animals/animal_needs_component.gd), [components/animals/animal_actor.gd](C:/projects/fantasy-farm/components/animals/animal_actor.gd).

## 6. Chuồng và máng đang đặt trong map

| Khu | Vật nuôi có sẵn | Sức chứa | Thức ăn còn/tổng | % máng ăn | Nước còn/tổng | % máng nước |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| CoopPen | 0 | 30 | 240/1.200 (2 máng) | 20% | 240/240 (2 máng) | 100% |
| BarnPen | 0 | 36 | 600/600 (1 máng) | 100% | 600/600 (1 máng) | 100% |
| PondPen | 5 vịt, 6 ngỗng | 20 | 600/600 (1 máng) | 100% | 600/600 (1 máng) | 100% |

11 con trong ao có tuổi khởi tạo 120 giây, vẫn chưa trưởng thành theo ngưỡng 24 giờ. Các số stock là giá trị authored khi tạo hồ sơ mới, không phải trạng thái save người chơi. Mọi máng đang đặt phục hồi 40 điểm/đơn vị và phục vụ trong 1,5 giây.

| Vật tư / thao tác | Giá | Hiệu lực |
| --- | ---: | --- |
| Poultry Feed (`poultry_feed`) | 25 | 300 đơn vị máng/gói |
| Livestock Feed (`livestock_feed`) | 25 | 300 đơn vị máng/gói |
| Crop Fertilizer (`crop_fertilizer`) | 5 | Mỗi cây một lần, dùng trước 50%; giảm hạn chín 20% tổng thời gian gốc |
| Animal Tonic (`animal_tonic`) | 3 | Chu kỳ hoàn thành kế tiếp có 50% xác suất thêm 1 sản phẩm; không cộng dồn tonic đang chờ |
| Beehive (`beehive`) | 1.500 | Đặt một tổ ong |
| Axe (`axe`) | 250 | Công cụ chặt/đào cây; dùng lại |

Máng nước không thu xu và không tiêu hao bình tưới. Nhấn E/tương tác tự động đổ đầy lượng còn thiếu; đường dùng công cụ thủ công thêm 30 đơn vị/lượt (`water_per_use=30`). Đổ thức ăn tự động dùng gói nguyên và giữ phần dư trong `feed_reserve`.

Với phục hồi tối đa 40 điểm/đơn vị, no mất 100 điểm/600 giây: chi phí thức ăn duy trì lý tưởng ≈15 đơn vị/giờ = 1,25 xu/giờ/con khi gói 300 đơn vị giá 25. Đây chỉ là ước tính mức tiêu hao dài hạn; chưa tính đi tới máng, phần phục hồi bị kẹp 100% hoặc gián đoạn. Không dùng số này làm lãi thực đo.

Nguồn: [components/animals/animal_trough.gd](C:/projects/fantasy-farm/components/animals/animal_trough.gd), [components/animals/trough_interaction_component.gd](C:/projects/fantasy-farm/components/animals/trough_interaction_component.gd), [components/animals/animal_production_component.gd](C:/projects/fantasy-farm/components/animals/animal_production_component.gd).

## 7. Cây lâu năm

| Cây | Giá cây giống | Lớn ban đầu (giây) | Chu kỳ quả (giây) | Sản lượng | Giá bán/đơn vị | Doanh thu/lượt |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Táo (`apple`) | 60 | 180 | 90 | 3 Apple | 40 | 120 |
| Bạch dương (`birch`) | 60 | 240 | — | 5 Wood | 20 | 100 |
| Anh đào (`cherry`) | 60 | 180 | 90 | 3 Cherry | 40 | 120 |
| Sồi (`oak`) | 60 | 240 | — | 5 Wood | 20 | 100 |
| Đào (`peach`) | 60 | 180 | 90 | 3 Peach | 40 | 120 |
| Lê (`pear`) | 60 | 180 | 90 | 3 Pear | 40 | 120 |
| Vân sam (`spruce`) | 60 | 240 | — | 5 Wood | 20 | 100 |

- Cây ăn quả phải tưới để bắt đầu lớn; lần quả đầu sau 180+90=270 giây cơ sở. Mỗi lần thu đặt lại tiến độ quả; chỉ giữ tối đa một lứa sẵn sàng, không tích vô hạn khi nghỉ game.
- Gỗ (`wood`) bán 20 xu/đơn vị; rễ gỗ (`root_wood`) bán 20 xu/đơn vị.
- Cây lấy gỗ tự lớn sau trồng, chặt 4 nhát khi trưởng thành cho 5 gỗ và trả 1 cây giống. Gốc đợi 120 giây rồi mọc lại với thời gian lớn bằng 50% ban đầu (120 giây): tổng 240 giây từ lúc chặt tới lứa gỗ tiếp theo, chưa tính thao tác. Đào gốc 3 nhát cho 2 root_wood và loại bỏ cây.
- Ô cây ăn quả và lấy gỗ có vùng riêng; không lấy số ô ruộng mở rộng làm sức chứa của hai vùng này.

Nguồn: `trees/definitions/`, [components/trees/fruit_tree.gd](C:/projects/fantasy-farm/components/trees/fruit_tree.gd), [components/trees/timber_tree.gd](C:/projects/fantasy-farm/components/trees/timber_tree.gd).

## 8. Ong và mật

| Thông số | Giá trị |
| --- | --- |
| Giá tổ ong | 1.500 xu |
| Chu kỳ công cơ sở | 86.400 giây = 24 giờ / 1 hũ |
| Có nguồn phấn liên tục | Tốc độ ×1,3 → khoảng 66.461,54 giây = 18 giờ 27 phút 42 giây/lứa |
| Sức chứa sản phẩm sẵn sàng | 1 hũ; đầy thì ngừng tích công tới khi thu |
| Bán Wild Honey / Sunflower Honey / Floral Honey | 150 / 225 / 300 xu mỗi hũ |
| Bán kính cơ sở / khi gió | 80 / 120 pixel world |
| Nguồn phấn chuyên biệt | Loài chiếm ưu thế phải đóng góp ≥50% tổng công chu kỳ |
| Buff cây ruộng có thụ phấn | Tốc độ lớn +10% (1,1×), không phải giảm thẳng thời gian 10% |
| Buff cây ăn quả gần tổ hoạt động | Chu kỳ quả ngắn hơn 25% (1/0,75× tốc độ) |

Nguồn: [resources/bees/beehive.tres](C:/projects/fantasy-farm/resources/bees/beehive.tres), [components/bees/beehive_production_component.gd](C:/projects/fantasy-farm/components/bees/beehive_production_component.gd), [components/bees/apiary_system.gd](C:/projects/fantasy-farm/components/bees/apiary_system.gd), [components/trees/tree_plantation.gd](C:/projects/fantasy-farm/components/trees/tree_plantation.gd).

## 9. Thưởng mục tiêu nhập môn

| Mục tiêu / ID | Điều kiện cấu hình | Số cần | Thưởng xu |
| --- | --- | ---: | ---: |
| Prepare the soil (`first_soil`) | `prepared_soil` — xét trạng thái đang có | 1 | 25 |
| Plant a seed (`first_seed`) | `plant` — đếm hành động thành công khi bước đang mở | 1 | 50 |
| Water your crop (`first_water`) | `water_crop` — đếm hành động thành công khi bước đang mở | 1 | 50 |
| Harvest a crop (`first_harvest`) | `harvest` — đếm hành động thành công khi bước đang mở | 1 | 100 |
| Sell your produce (`first_sale`) | `sell_produce` — đếm hành động thành công khi bước đang mở | 1 | 100 |
| Care for an animal (`first_animal`) | `own_animal` — xét trạng thái đang có | 1 | 100 |
| Refill a feed trough (`first_feed`) | `refill_food` — đếm hành động thành công khi bước đang mở | 1 | 50 |
| Refill a water trough (`first_trough_water`) | `refill_water` — đếm hành động thành công khi bước đang mở | 1 | 50 |
| Expand your farm (`first_expansion`) | `land_columns` — xét trạng thái đang có | 2 | 250 |

Tổng thưởng cả chuỗi: **775 xu**, nhận một lần. Bước mở đất đòi tổng 2 cột, tức mua thêm 1 cột nếu bắt đầu từ mặc định. Nguồn: [resources/objectives/onboarding.tres](C:/projects/fantasy-farm/resources/objectives/onboarding.tres).

## 10. Đơn hàng lặp lại

| Mẫu đơn | Hàng giao | Nếu bán NPC | Thưởng giao đơn | Chênh so với bán NPC |
| --- | --- | ---: | ---: | ---: |
| `carrot_crate` | 12 × Carrot | 60 | 72 | +12 (20,00%) |
| `tomato_crate` | 10 × Tomato | 70 | 84 | +14 (20,00%) |
| `potato_crate` | 12 × Potato | 72 | 87 | +15 (20,83%) |
| `corn_crate` | 10 × Corn | 70 | 84 | +14 (20,00%) |
| `salad_basket` | 8 × Carrot, 6 × Tomato | 82 | 99 | +17 (20,73%) |
| `soup_basket` | 8 × Potato, 6 × Corn | 90 | 108 | +18 (20,00%) |
| `flower_bouquet` | 6 × Flower 01 | 120 | 144 | +24 (20,00%) |
| `mixed_bouquet` | 4 × Flower 01, 4 × Flower 02 | 160 | 192 | +32 (20,00%) |

Bảng giữ tối đa 3 đơn; 8 mẫu luân phiên xác định, không hết hạn và không cooldown theo thời gian. Hoàn thành/bỏ đơn mới thay đơn; điều kiện xuất hiện dựa trên nguồn có thể sản xuất trong world. Chênh lệch trên là thưởng thêm so với bán cùng số hàng, không phải lãi sau chi phí trồng. Nguồn: [resources/orders/farm_orders.tres](C:/projects/fantasy-farm/resources/orders/farm_orders.tres), [components/orders/order_service.gd](C:/projects/fantasy-farm/components/orders/order_service.gd).

## 11. Giá mở đất

Mở từ phải sang trái. Giá lượt mua khi đang sở hữu k cột: **round(15.000 × k^1,8)**, k=1…47. Mỗi lượt thêm 34 ô hình học. Một cột đầu miễn phí; tổng 47 lượt mua.

| Lượt mua | Tổng cột sau mua | Giá lượt này | Tổng tiền mua đất từ đầu |
| ---: | ---: | ---: | ---: |
| 1 | 2 | 15.000 | 15.000 |
| 2 | 3 | 52.233 | 67.233 |
| 3 | 4 | 108.370 | 175.603 |
| 4 | 5 | 181.886 | 357.489 |
| 5 | 6 | 271.792 | 629.281 |
| 6 | 7 | 377.367 | 1.006.648 |
| 7 | 8 | 498.044 | 1.504.692 |
| 8 | 9 | 633.364 | 2.138.056 |
| 9 | 10 | 782.939 | 2.920.995 |
| 10 | 11 | 946.436 | 3.867.431 |
| 15 | 16 | 1.963.611 | 11.520.676 |
| 20 | 21 | 3.295.682 | 25.213.030 |
| 30 | 31 | 6.837.692 | 76.713.907 |
| 40 | 41 | 11.476.230 | 169.727.183 |
| 47 | 48 | 15.341.485 | 265.237.379 |

JSON đính kèm chứa đủ 47 mức. Không cộng tiền thưởng mục tiêu/đơn hàng khi tính tổng giá đất. Nguồn: [components/land/land_expansion_state.gd](C:/projects/fantasy-farm/components/land/land_expansion_state.gd).

## 12. Thời tiết và thời gian

| Yếu tố | Quy tắc hiện tại |
| --- | --- |
| Ngày | 86.400 giây; mốc đổi thời tiết 06:00 UTC+7 |
| Phân bố từ roll lịch | Sunny 60%, Rain 20%, Cloudy 10%, Windy 10%; lịch xác định theo ngày/seed, không bảo đảm tỷ lệ trong mẫu chơi ngắn |
| Cloudy | Tiêu nước vật nuôi ×0,75, bốc hơi đất ×0,75 |
| Rain | Tưới vùng đất mở hợp lệ, bốc hơi đất 0; vịt/ngỗng trong ao tạo sản phẩm tốc độ ×1,1 |
| Rain và ong | Không nhận phấn/thụ phấn; vẫn tích công mật hoang tốc độ cơ sở |
| Windy | Bán kính ong ×1,5 |
| Menu / đóng game | Menu không dừng thời gian thực; offline catch-up theo luật từng hệ thống, không tự giả lập mọi hành vi AI |

Nguồn: [components/weather/weather_schedule.gd](C:/projects/fantasy-farm/components/weather/weather_schedule.gd), các hệ thống đã dẫn phía trên.

## 13. Những điểm cần quyết định ở lượt cân bằng

1. **Cây ruộng tạo tiền rất nhanh trên giấy:** mọi cây 10 giây, giá giống 10, lãi/vụ từ 490 đến 5.390. Tỏi cho 600×9−10=5.390; cà rốt cho 100×5−10=490. Với 1.000 xu đầu, thu hoạch 3 cây tỏi đủ phần tiền thiếu để mua cột 15.000 xu nếu bỏ qua mọi thời gian thao tác. Đây không phải số giây chơi thực.
2. **Hoa và ong khác nhịp rất xa cây ruộng:** hoa thường lãi 5 xu sau 120 giây; mật chờ hàng chục giờ. Cần đo giá trị không gian, đơn hàng và buff trước khi chọn vai trò kinh tế cho từng hệ.
3. **Tuổi trưởng thành 24 giờ, thức ăn/nước chỉ đủ 5–10 phút từ đầy:** cần rà trải nghiệm quay lại game, nhu cầu chăm sóc và sản xuất offline. Vật nuôi trên map đang có tuổi 120 giây, không phải đàn trưởng thành sinh sản phẩm ngay.
4. **Luật nước ruộng và nội dung trợ giúp đang lệch nhau:** chọn đất khô có dừng lớn hay không rồi đồng bộ gameplay/UI/test; bảng này chỉ ghi nhận.
5. **Kinh tế đơn hàng:** thưởng thêm so với bán NPC khoảng 20–21%, có thể lặp không cooldown. Cần đo thời gian nhận/giao/thay đơn, không quy đổi thành tiền vô hạn mỗi giây chỉ từ catalog.
6. **Đất tăng theo k^1,8:** đo mốc mua đầu và các mốc xa; sức chứa 1.632 ô chưa trừ vật cản và không có nghĩa cần mua hết để coi game hoàn thành.

## 14. Độ tin cậy và việc còn lại

- Đã đọc catalog bằng engine để lấy cả giá trị mặc định; đối chiếu 45 offer vật phẩm + 7 offer vật nuôi, 48 giá bán, 22 cây ruộng, 10 hoa, 7 loài, 7 cây lâu năm, 9 mục tiêu và 8 mẫu đơn.
- Snapshot world được instantiate ngoài SceneTree: không bind autosave, không cập nhật tuổi/AI và không dùng hồ sơ cá nhân. Kiểm tra lượng máng/số con dựa trên dữ liệu scene hiện tại.
- Các con số lãi và doanh thu là phép tính từ cấu hình, chưa là phép đo FPS, thời gian đi lại, số thao tác, hay phiên chơi 30–60 phút. Không suy ra thời gian hoàn thành toàn game từ các tỷ lệ lý thuyết.
- Bước tiếp theo của Step 4: chọn hồ sơ thử mới, đo thu hoạch/bán/mua vật nuôi/mở đất và quyết định vai trò từng hệ trước khi chỉnh thông số.
