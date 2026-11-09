# Fantasy Farm — P0 sounds

Bộ âm thanh P0 đã tích hợp vào gameplay. Trang nghe thử vẫn giữ để đối chiếu từng clip.

- Mở `review/index.html` bằng trình duyệt để nghe từng âm, lọc nhóm, đánh dấu Giữ / Đổi và xuất ghi chú JSON.
- Nghe nhanh `review/p0_sampler.wav`; thứ tự và mốc thời gian trong `review/sampler_cues.json`.
- Các file dùng thử nằm trong thư mục theo nhóm, WAV PCM 16-bit mono 44.1 kHz.
- Manifest ghi rõ tác giả, nguồn, giấy phép, hash, thời lượng, mức âm và cách xử lý từng file.
- Biến thể bước chân dùng bản gốc khác nhau. Biến thể làm vườn có thể dùng cùng nguồn được đổi cao độ/cắt ngắn; chúng không phải các bản thu độc lập.
- Bước chân đất dùng mud02 của TinyWorlds (4 biến thể cao độ); tiếng đá dùng bộ Kenney Concrete riêng. `review/soil_vs_stone.wav` phát 4 bước đất rồi 4 bước đá để so sánh.

## Nguồn và giấy phép

Tất cả file được chọn có giấy phép CC0-1.0, cho phép dùng thương mại và chỉnh sửa. Giữ bản giấy phép trong `licenses/`.

- Kenney: UI Audio, Interface Sounds, RPG Audio, Impact Sounds, Casino Audio, Music Jingles. https://kenney.nl/support
- SFXMint: 5 âm từ thư viện công khai Farming Tools. https://sfxmint.com/sounds/farming-tools và https://sfxmint.com/license
- SFXMint mô tả thư viện là âm tạo bằng AI hoặc tổng hợp thủ tục; nguồn này được ghi riêng trong manifest.

- TinyWorlds: Different Steps, dùng mud02.ogg. https://opengameart.org/content/different-steps-on-wood-stone-leaves-gravel-and-mud

## Danh sách sự kiện

| Sự kiện | Âm | Số biến thể | Mốc nghe nhanh |
|---|---|---:|---:|
| `footstep_dirt` | Bước chân trên đất | 4 | 0.00s |
| `footstep_grass` | Bước chân trên cỏ | 4 | 0.93s |
| `footstep_stone` | Bước chân trên đường đá | 4 | 1.93s |
| `till_soil` | Cuốc đất | 3 | 2.69s |
| `sow_seed` | Gieo hạt | 3 | 4.24s |
| `water_crop` | Tưới nước | 3 | 5.54s |
| `harvest_crop` | Thu hoạch rau | 3 | 7.34s |
| `harvest_flower` | Hái hoa | 2 | 8.69s |
| `harvest_fruit` | Hái trái cây | 2 | 9.79s |
| `item_pickup` | Nhặt vật phẩm | 2 | 10.94s |
| `coin_receive` | Nhận xu | 2 | 11.69s |
| `coin_spend` | Thanh toán | 1 | 13.11s |
| `ui_click` | Bấm nút | 2 | 13.92s |
| `ui_tab` | Đổi tab | 2 | 14.66s |
| `ui_open` | Mở menu | 1 | 15.41s |
| `ui_close` | Đóng menu | 1 | 16.24s |
| `storage_deposit` | Cất vật phẩm vào kho | 2 | 17.05s |
| `storage_withdraw` | Lấy vật phẩm khỏi kho | 2 | 17.94s |
| `error_resources` | Không đủ tiền hoặc nguyên liệu | 1 | 19.14s |
| `error_capacity` | Túi hoặc kho đầy | 1 | 19.95s |
| `order_delivered` | Giao đơn hàng thành công | 1 | 20.70s |
| `objective_complete` | Hoàn thành mục tiêu | 1 | 21.89s |
| `reward_claim` | Nhận thưởng nhiệm vụ | 1 | 23.04s |

## Runtime

- Autoload `Sound` (`components/farm_sound.gd`) dùng pool tối đa 12 AudioStreamPlayer; catalog preload đủ 48 clip cho 23 sự kiện.
- Bước chân dựa vào quãng đường thực: 18 px/bước, tối đa một âm mỗi 220 ms; đứng yên, đi vào tường, mở menu và dịch chuyển xa không phát bước chân.
- Đất đã cuốc hoặc tưới ưu tiên hơn tile đường nằm dưới. Bề mặt còn lại đọc vật liệu tile: Pavement_Tiles là đá; FarmLand và Path_Decoration (kể cả lối giữa luống) là đất; còn lại là cỏ. Quyền blocks_farming không quyết định tiếng bước chân.
- Thu hoạch gộp trong 130 ms, nhặt đồ trong 120 ms, lỗi trong 700 ms. Số lượng sản phẩm không nhân số âm.
- Mua/bán, giao đơn, nhận thưởng và chuyển kho phát tại điểm nhận kết quả thành công; không suy ra từ thay đổi ví/túi.
- Mỗi lần kích hoạt nút có tiếng click mềm, kể cả khi handler ẩn/tạo lại nút; âm kết quả giao dịch hoặc mở/đóng menu phát riêng. Click/đổi tab được tăng 3 dB so với clip để dễ nhận ra, vẫn giữ foley đã lọc dải cao.
- UI dùng foley vải/gõ gỗ ngắn, lọc bớt dải cao và peak khoảng -23 đến -24 dBFS; không dùng tiếng điện tử cũ. Cao độ phát là 1× vì clip đã thay trực tiếp.
- Trong Cài đặt: tổng 100%, hiệu ứng 80%, giao diện 80%, môi trường 70% mặc định. Mức âm lưu trong ui_preferences.cfg; vẫn đọc được cài đặt cũ.
- Tiếng gió cũ đi qua bus Ambience. Chưa bổ sung nhạc nền hoặc âm P1/P2.
- Có thể giữ/đổi clip bằng trang review; nguồn và giấy phép không thay đổi.
