# Fantasy Farm

Dự án Godot được tổ chức theo tính năng và thực thể. Scene, script và tài nguyên
của một tính năng nằm cùng nhánh, thay vì tách ra các thư mục toàn cục theo loại file.

```text
res://
├── common/
│   ├── autoloads/         # Dịch vụ dùng chung, khi cần
│   ├── components/        # Component dùng chung, khi cần
│   ├── art/other/         # Tài nguyên chưa thuộc tính năng cụ thể
│   └── ui/                # Theme, font, icon và hình giao diện dùng chung
├── entities/
│   ├── player/            # Scene và code player mới; dùng sprite NPC có sẵn
│   ├── npcs/              # Asset và animation NPC
│   ├── animals/           # Asset và animation động vật
│   └── enemies/           # Asset kẻ địch
├── features/
│   ├── farming/           # Ảnh gốc và resource cây trồng
│   ├── inventory/         # Dành cho hệ thống vật phẩm mới
│   └── weather/           # Ảnh gốc, texture và animation thời tiết
├── world/
│   ├── buildings/         # Nhà cửa, nội thất và TileSet liên quan
│   ├── decorations/       # Trang trí trong nhà và ngoài trời
│   ├── terrain/           # Địa hình
│   └── vegetation/        # Cây và TileSet cây
├── levels/                # Scene bản đồ và màn chơi mới
├── tools/setup/           # Công cụ tạo tài nguyên, dữ liệu đầu vào
├── docs/                  # Tài liệu thiết kế và hướng dẫn công cụ
└── addons/                # Plugin bên thứ ba
```

Khi viết lại game, đặt file ngay trong tính năng sở hữu nó, ví dụ
`entities/player/player.gd`, `entities/player/player.tscn` hoặc
`features/farming/farm_plot.gd`. Tài nguyên riêng của từng nhân vật hoặc vật thể
nên nằm cạnh scene của nó; chỉ đưa thứ được nhiều tính năng dùng vào `common/`.
Các nhánh `art/`, `animations/`, `tilesets/` hiện có chỉ phân loại bên trong
tính năng sở hữu. Giữ nguyên tên file gốc của bộ asset để tránh mất đối chiếu.

Player dùng sprite NPC nguyên nhân vật từ `entities/npcs/art/` và SpriteFrames
tương ứng trong `entities/npcs/animations/`. Bộ asset player ghép theo bộ phận
đã được xoá; không cần tách đầu, thân, chân hoặc trang phục thành các lớp sprite.

Các script setup đã cập nhật đường dẫn. Ví dụ:

```powershell
godot --headless --path . --script res://tools/setup/setup_crop_resources.gd
```

`setup_object_scenes.gd` xuất scene theo từng nhánh tính năng ở trên và tạo lại
`docs/object_scenes_index.json`. Chưa chạy lại trình tạo scene sau đợt xoá code cũ.

`tools/setup/legacy/` giữ script tạo resource gameplay cũ để tham khảo; thư mục này
có `.gdignore` vì các lớp gameplay cũ đã được xoá. Các thiết lập project, addon và
AI skills được giữ lại. Dự án chưa có main scene mới.
