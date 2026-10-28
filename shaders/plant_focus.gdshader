// Adapted from the Godot skill wave template. Vertex deformation keeps AtlasTexture
// sampling inside its original tile and pins the bottom edge to the ground.
shader_type canvas_item;

uniform float plant_height = 32.0;
uniform float amplitude = 0.7;
uniform float speed = 1.4;
// Cây có khoảng đệm trong atlas dùng chân ảnh thật làm điểm neo.
// Mặc định tắt để giữ nguyên các material cây trồng/hoa đã có.
uniform bool anchor_visible_root = false;
uniform float ground_y = 0.0;

// HIỆU ỨNG TÙY CHỌN: shader chỉ đổi vị trí đỉnh hiển thị, không đổi collision hay dữ liệu cây.
// root được đổi sang tọa độ thế giới để tính phase: hai cây ở hai vị trí có nhịp gió khác nhau.
// Hai sóng sin có tốc độ lệch nhau tạo nhịp ít máy móc hơn một sóng lặp duy nhất.
// reach = 0 ở mép dưới và tăng về trên, nên chân đứng yên còn đỉnh quad dịch ngang.
// Giữ UV không đổi để AtlasTexture vẫn đọc đúng ô ảnh; dịch UV toàn atlas có thể kéo màu ô kế bên.
// Dùng TIME trên GPU và material dùng chung để tránh một _process/Tween lặp trên từng cây.
// Có thể đặt amplitude = 0 để tắt gió; không được dùng độ nghiêng này làm tọa độ va chạm.
void vertex() {
	float root_y = anchor_visible_root ? ground_y : plant_height * 0.5;
	vec2 root = (MODEL_MATRIX * vec4(0.0, root_y, 0.0, 1.0)).xy;
	float phase = root.x * 0.071 + root.y * 0.043;
	float reach = clamp((plant_height * 0.5 - VERTEX.y) / (plant_height * 0.7), 0.0, 1.0);
	if (anchor_visible_root) {
		// Shear tuyến tính qua cả quad: nội suy tại chân ảnh luôn bằng 0,
		// kể cả khi còn vùng trong suốt phía dưới chân cây trong atlas.
		reach = (root_y - VERTEX.y) / max(plant_height, 1.0);
	}
	float breeze = sin(TIME * speed + phase) + 0.25 * sin(TIME * speed * 0.63 + phase * 0.7);
	VERTEX.x += breeze * amplitude * reach;
}

// A translucent warm layer inside the source silhouette.
void fragment() {
	float alpha = COLOR.a;
	COLOR = vec4(1.0, 0.94, 0.76, alpha);
}
