# Danh sách kiểm tra thủ công — ổ ngoài

Những bài này cần **cắm và rút ổ thật**, nên chỉ làm bằng tay. Không dùng script để tháo ổ.

**Chuẩn bị**
- Dùng một thư mục thử trên KIOXIA, ví dụ `KIOXIA/PK TEST`. Không thử trên thư mục dự án thật.
- Trong app, vào **New Project**, bấm **Choose Another…**, chọn `PK TEST`.
- Làm xong tất cả các bài thì chọn lại `EVENT` và xoá `PK TEST`.
- Ghi kết quả vào cột cuối: ✅ đạt · ❌ lỗi, kèm ghi chú.

## 1. Rút và cắm lại KIOXIA
| Bước | Mong đợi | Kết quả |
|---|---|---|
| Mở app khi cả hai ổ đang cắm | Góc dưới trái: KIOXIA và WORK đều "Connected and authorized" | |
| Eject KIOXIA trong Finder | Trong vài giây: KIOXIA "disconnected", nút Create Project bị khoá, WORK vẫn xanh | |
| Cắm lại KIOXIA | Tự chuyển lại "Connected and authorized", không cần chọn lại thư mục | |
| Recent Projects khi KIOXIA đang rút | Dự án hiện "KIOXIA disconnected", **không** bị xoá khỏi danh sách | |

## 2. Rút và cắm lại WORK
| Bước | Mong đợi | Kết quả |
|---|---|---|
| Eject WORK | Premiere Template và Resolve Template hiện "WORK disconnected"; Create Project bị khoá khi ô Premiere đang tích | |
| Bỏ tích "Create Premiere project from template", bấm Create Project | Có hộp hỏi "Create folders only?"; bấm Cancel thì không tạo gì | |
| Cắm lại WORK | Template tự trở lại "Ready to copy" | |

## 3. Ổ cắm lại với tên khác
| Bước | Mong đợi | Kết quả |
|---|---|---|
| Đổi tên ổ KIOXIA trong Finder (ví dụ `KIOXIA2`), rồi mở app | Ổ vẫn được nhận ra (app nhận ổ theo mã nhận dạng, không theo tên); đường dẫn hiện tên mới | |
| Đổi tên lại `KIOXIA` | Mọi thứ trở lại bình thường | |

## 4. Quyền truy cập
| Bước | Mong đợi | Kết quả |
|---|---|---|
| Mở **Settings › Locations** | Mỗi mục có trạng thái, nút chọn lại hoặc Reauthorize khi cần | |
| Nếu một mục báo "Permission needed / Bookmark stale": bấm **Reauthorize…** rồi chọn đúng thư mục hoặc file | Trạng thái chuyển xanh, không phải khởi động lại app | |

## 5. Rút ổ trong lúc đang tạo dự án
Dự án tạo rất nhanh (dưới một giây), nên bài này khó canh thời điểm. Cứ thử vài lần.

| Bước | Mong đợi | Kết quả |
|---|---|---|
| Bấm Create Project và rút KIOXIA ngay lập tức | App báo lỗi, **không** hiện hộp "Project Created" | |
| Cắm lại KIOXIA, mở `PK TEST` | Không có dự án dở dang. Nếu còn thư mục `.PKProjectCreator-Staging-…` (do ổ mất trước khi app kịp dọn), hộp báo lỗi đã nêu đường dẫn để bạn tự xoá | |
| Kiểm tra file mẫu Premiere / Resolve trên WORK | Không thay đổi (ngày sửa đổi giữ nguyên) | |

## 6. Mở bằng Premiere Pro
| Bước | Mong đợi | Kết quả |
|---|---|---|
| Tạo dự án có Premiere, bấm **Open in Premiere Pro** trong hộp "Project Created" | Premiere mở đúng file `.prproj` trong dự án mới | |

## 7. Update Project trên ổ thật
| Bước | Mong đợi | Kết quả |
|---|---|---|
| Recent Projects › chọn dự án thử › **Update Project…** | Cây thư mục giống trong Finder; thư mục có file có 🔒 | |
| Thêm một thư mục, xoá một thư mục trống, bấm Update | Đúng như danh sách Changes; file có sẵn không bị đụng | |
| Rút KIOXIA rồi mở lại Recent Projects | Nút Update Project bị khoá | |
