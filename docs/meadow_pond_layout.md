# Hồ cảnh khuôn viên phía Đông

Dáng hồ bất đối xứng: phần nước rộng ở Tây Bắc, eo giữa và một vịnh lõm phía
Đông, rồi nở ra thành phần nước nhỏ hơn ở Đông Nam. Cây bạch dương nhỏ và đá
đánh dấu vịnh. Cây lớn được dời ra bờ Tây, liễu ở bờ Nam; các bụi hoa cỏ cũ nằm
trong hình hồ mới được gom lại trên đất khô phía Tây.

Scene: `scenes/objects/outdoor_decor/meadow_pond.tscn`, gốc tại (-80,-32).
Asset nước giữ nguyên bộ `Pond_Grass_Standard.png` của game. Atlas ghép theo
bốn đỉnh của mỗi ô, gồm các góc lõm, để bờ nối liền khi thay đổi độ rộng của hồ.
Không chạy terrain autotile lại bằng cách coi mọi ô bờ là ô nước giữa: cấu hình
terrain cũ của bộ asset sẽ sinh góc sai hoặc dải cỏ trên mặt nước.

`DeepWater` là các đoạn collision theo từng hàng của hình hồ, phải chỉnh cùng
`Water` khi đổi dáng. Giữ ít nhất 8 px giữa toàn bộ ô bờ hồ với ô đường vòng.
Các sprite `Reeds*` và `WaterLily*` phải nằm hoàn toàn trong các ô nước giữa,
không đặt trên ô bờ trộn cỏ. Thân cây và các cụm hoa cỏ phải nằm trên đất.

Các ràng buộc trên được kiểm tra trong `tests/integration/test_meadow_pond.gd`.
Ảnh vòng sửa cuối: `.godot/decor-review/meadow-pond/natural-04/`.
