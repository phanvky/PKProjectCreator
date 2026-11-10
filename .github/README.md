# PKProjectCreator

Ứng dụng macOS nội bộ của **PHANKY FILM**. App tạo thư mục dự án video theo mẫu, chép sẵn project Premiere Pro và DaVinci Resolve vào đúng chỗ, và đặt tên theo quy tắc `yyyy - MM - dd Loại Tên`. App chạy offline hoàn toàn.

## Tải và cài đặt
1. Vào mục **Releases** ở cột bên phải trang này, chọn bản mới nhất, tải file **PKProjectCreator.dmg**.
2. Làm theo hướng dẫn trong [Documentation/INSTALLATION.md](../Documentation/INSTALLATION.md).
   - Yêu cầu: Mac chip Apple Silicon (M1 trở lên), macOS 26 trở lên.
   - App chưa được Apple công chứng (notarize). Lần mở đầu tiên, vào **System Settings › Privacy & Security** và bấm **Open Anyway**.

## Tính năng chính
- **New Project:** tạo cây thư mục dự án và chép project Premiere và Resolve. Nếu có lỗi, app không để lại gì dở dang và không ghi đè dự án có sẵn.
- **Folder Templates:** chỉnh sửa mẫu thư mục.
- **Recent Projects:** xem các dự án đã tạo. **Update Project** cho phép thêm thư mục, xoá thư mục trống, và thêm file Premiere hoặc Resolve còn thiếu.
- Theo dõi ổ ngoài (KIOXIA, WORK) và quyền truy cập của macOS.

Chi tiết xem [RELEASE_NOTES](../Documentation/RELEASE_NOTES.md).

## Dành cho người phát triển
- Mở `PKProjectCreator.xcodeproj` bằng Xcode 27 trở lên rồi chạy scheme **PKProjectCreator**. Không dùng thư viện ngoài.
- Tài liệu kỹ thuật: [PROJECT_SPEC](../Documentation/PROJECT_SPEC.md), [ARCHITECTURE](../Documentation/ARCHITECTURE.md), [BUILD_INFO](../Documentation/BUILD_INFO.md), [QA_REPORT](../Documentation/QA_REPORT.md).
