# PixelLab MCP cho Fantasy Farm

Cấu hình và kiểm tra ngày 25/10/2026. Không tạo ảnh trong bước thiết lập.

## Kết nối đã thiết lập

Codex dùng Streamable HTTP trực tiếp, không cần npx/mcp-remote. Cấu hình người dùng tại `C:/Users/faker/.codex/config.toml`:

```toml
[mcp_servers.pixellab]
url = "https://api.pixellab.ai/mcp"
bearer_token_env_var = "PIXELLAB_API_KEY"
startup_timeout_sec = 60
tool_timeout_sec = 180
enabled = true
```

Token được lưu trong biến môi trường **Windows User** `PIXELLAB_API_KEY`; giá trị chỉ là token, không thêm tiền tố `Bearer`. Codex tự dựng Authorization. Không có token trong repo, tài liệu hoặc cấu hình TOML. Cấu hình Codex cũ đã được sao lưu và các server đang có được giữ nguyên.

**Đóng hẳn rồi mở lại Codex** để tiến trình mới nhận biến môi trường và tải danh sách công cụ. Nếu có nút Restart trong Settings → MCP servers, có thể dùng để tải lại server, nhưng nếu báo thiếu biến môi trường thì cần mở lại toàn bộ ứng dụng. Phiên chat đang chạy không được coi là đã tự nhận công cụ chỉ vì file config đã đổi.

## Kết quả kiểm tra thực tế

- Codex CLI nhận `pixellab` là `streamable_http`, enabled, đúng endpoint và tên biến môi trường.
- MCP initialize thành công với server **PixelLab MCP Server 0.2.0**.
- tools/list trả về **103 công cụ**; có get_balance, create_image_pixflux, create_image_pixen và get_image.
- get_balance thành công: **trial, còn 32/40 lượt, đã dùng 8; credits $0.00** tại thời điểm kiểm tra.
- Server trả daily bonus 20, hồi +5 mỗi đêm tới trần 20. Đây không phải 20 lượt cộng thêm để suy ra ngay 52 lượt: server mô tả bộ đếm ngày cũng giảm đồng thời với lượt plan trong cùng một lần tính phí. Kiểm tra get_balance lại trước khi tạo.
- Chỉ gọi initialize, notifications/initialized, tools/list, get_balance. Không tạo job, không gửi ảnh dự án, không tiêu lượt generate.

Trang pricing hiện liệt kê trial 40 lượt nhanh rồi 5 lượt chậm/ngày, tích tới 20, giới hạn ảnh tới 200×200 và không có Map tools. Tài liệu Ways to use còn ghi MCP cần subscription, khác với pricing; phép thử tài khoản này xác nhận kết nối và đọc balance hoạt động, **chưa chứng minh mọi công cụ tạo ảnh/animation đều được phép trên trial**. Không dùng lỗi giới hạn làm lý do tự nâng gói hoặc chuyển sang công cụ tốn nhiều lượt.

## Cách dùng tiết kiệm cho bộ icon

1. Rà lại asset có sẵn và chốt đúng một vật phẩm cần vẽ; chưa tạo cả bộ khi chưa duyệt mẫu.
2. Gọi get_balance. Ưu tiên `create_image_pixen` hoặc `create_image_pixflux`, tài liệu hiện ghi 1 generation/lần. Với icon, bắt đầu **32×32, nền trong suốt**. Pixflux không nhận 16×16 vì diện tích tối thiểu 32×32; không thử đi thử lại kích thước sai.
3. Giữ phong cách icon hiện tại trong `assets/Icons/No Outline/`: màu ấm, hình đơn giản đọc được ở kích thước nhỏ, không chữ, không nền, không tự ép viền đen hoặc phong cách khác. Chọn mẫu/palette dự án khi cần; MCP không đọc được đường dẫn local nên chỉ upload ảnh tham chiếu thực sự cần thiết, không gửi nguyên dự án.
4. Nhận job ID, kiểm tra bằng get_image tới khi xong, rồi tải PNG kết quả. Không gọi create lần nữa chỉ vì ảnh chưa hoàn thành.
5. Lưu bản gốc vào thư mục nguồn riêng trước; kiểm tra alpha, kích thước, silhouette và đọc được ở ô túi. Icon hiện tại phần lớn 16×16: ảnh AI 32×32 phải được rà lại khi thu nhỏ, không coi downscale tự động là art 16×16 đạt chuẩn.
6. Chỉ thay ItemDefinition.icon sau khi duyệt ảnh. Giữ nguyên item_id, giá, công thức và save. Dùng nearest filtering trong Godot, kiểm tra túi, kho và Chef.
7. Lưu prompt, seed, job ID và số lượt đã dùng để tái lập. Không tự sinh lại nhiều phiên bản, tạo character nhiều hướng hoặc dùng Pro để thay cho một icon tĩnh.

Ví dụ tham số tham khảo (không được chạy trong bước setup):

```text
create_image_pixen(
  description="Single small jar of grafting wax for a cozy farming game inventory. Warm earthy palette, clear silhouette, simple pixel clusters, no letters, no scenery.",
  width=32,
  height=32,
  no_background=True,
  outline="lineless",
  detail="low detail",
  seed=847583
)
```

Ưu tiên xử lý sau: icon vật tư dễ nhầm (sáp ghép/Root Tonic), mẫu món ăn, rồi biến thể nhãn/màu cho mật. Dấu Star, tầng chất lượng và dấu mẻ lớn có thể dùng overlay chung thay vì chi nhiều lượt tạo lại toàn bộ hình.

## Kiểm tra hoặc đổi token

- Đổi giá trị `PIXELLAB_API_KEY` ở Environment Variables của tài khoản Windows rồi mở lại Codex. Không dán token vào file dự án.
- `codex mcp get pixellab --json` xác nhận cấu hình, **không đủ để chứng minh xác thực thành công**; cần công cụ get_balance trong phiên mới.
- 401: kiểm tra token từ trang tích hợp MCP và giá trị không kèm Bearer. Thiếu biến môi trường: mở lại app. Hết lượt/không được phép trên trial: dừng, báo đúng lỗi, không tự mua credits.
- API key không cần đưa vào game hoặc bản Web export. Đây là công cụ tạo asset trong quá trình phát triển, không phải tính năng runtime.

Nguồn chính thức:

- https://api.pixellab.ai/mcp/docs
- https://www.pixellab.ai/?tier=0
- https://www.pixellab.ai/docs/ways-to-use-pixellab
- https://learn.chatgpt.com/docs/extend/mcp
