# Cài đặt PKProjectCreator 1.0.1

Yêu cầu: máy Mac chip Apple Silicon (M1 trở lên), macOS 26 trở lên. App chạy hoàn toàn offline.

## Cài lần đầu
1. Bấm đúp vào file **PKProjectCreator.dmg**. Một cửa sổ mở ra, có biểu tượng app và thư mục **Applications**.
2. Kéo **PKProjectCreator** thả vào **Applications**.
3. Bấm nút ⏏ cạnh **PKProjectCreator** ở thanh bên trái Finder để tháo DMG.
4. Mở **Applications** và bấm đúp vào **PKProjectCreator**.

## Nếu macOS chặn không cho mở
App chưa được ký bằng chứng chỉ Apple Developer ID nên chưa được Apple công chứng (notarize). Trên chính máy đã build app thì thường không bị chặn. Nếu chép DMG sang máy khác (qua AirDrop, mạng, USB), macOS có thể báo không mở được. Khi đó:
1. Bấm **Done** (không bấm Move to Trash).
2. Mở **System Settings**, vào **Privacy & Security**.
3. Kéo xuống phần **Security**, sẽ thấy dòng nói PKProjectCreator bị chặn. Bấm **Open Anyway**.
4. Nhập mật khẩu máy, rồi bấm **Open** lần nữa.

Chỉ cần làm một lần cho mỗi máy.

## Lần mở đầu tiên
Cài đặt, template thư mục và danh sách dự án được lưu riêng, không nằm trong app, ở:
`~/Library/Containers/com.phankyfilm.PKProjectCreator/Data/Library/Application Support/PKProjectCreator/`.

- **Trên máy đã dùng app trước đó:** mọi thứ tự hiện lại như cũ. Thư mục đích, file mẫu Premiere và Resolve đều giữ nguyên quyền truy cập.
- **Trên máy mới:** macOS chỉ cho app dùng thư mục và file mà bạn tự chọn, nên cần chọn một lần:
  1. **New Project › Destination › Choose Another…**: chọn `KIOXIA/PROJECT VIDEO/EVENT`.
  2. **Premiere Template › Choose…**: chọn file `.prproj` mẫu trên WORK.
  3. **Resolve Template › Choose…**: chọn file `.drp` mẫu trên WORK.

## Cập nhật lên bản mới
Kéo app mới vào **Applications**, rồi chọn **Replace** khi được hỏi. Dữ liệu và quyền truy cập vẫn giữ nguyên, vì chúng không nằm trong app.

## Gỡ cài đặt
Kéo **PKProjectCreator** từ Applications vào Thùng rác. Nếu muốn xoá luôn dữ liệu, xoá thư mục `~/Library/Containers/com.phankyfilm.PKProjectCreator`. Các dự án đã tạo trên ổ **không** bị ảnh hưởng.
