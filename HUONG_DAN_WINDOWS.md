# Làm trên Windows (không cần Linux)

Chỉ cần Windows 10/11 (đã có sẵn `ssh`, `scp`, `tar`). Máy tính nối Wi-Fi/cáp vào router.

## Bước 1 – Wi-Fi + mật khẩu (nháy đúp `1-wifi-va-mat-khau.bat`)
Nhập mật khẩu Wi-Fi và root theo ý bạn. Xong, kết nối lại Wi-Fi bằng mật khẩu mới.

## Bước 2 – Lấy gói OAF (build trên đám mây GitHub, miễn phí, không cần Linux)
1. Đăng nhập github.com → **New repository** (đặt Private, tên `oaf-build`).
2. **Add file → Upload files**: kéo cả thư mục `oaf-ci` vào (gồm `build-oaf.sh` và thư mục ẩn `.github`).
   Thư mục `.github` là thư mục ẩn nên đã đổi thành file `build-oaf.yml.txt`: **Add file → Create new file**, gõ tên
   `.github/workflows/build-oaf.yml`, dán nội dung file `build-oaf.yml.txt` vào.
3. Tab **Actions → build-oaf → Run workflow**. Chờ 30–90 phút.
4. Xong, mở lần chạy → mục **Artifacts** → tải `oaf-apk-và-log`, giải nén.
5. Chép các file `.apk` vào thư mục `windows\apk\`. Nếu lỗi: gửi `build.log` cho Claude.

(Cách thay thế: WSL2 — `wsl --install -d Ubuntu` rồi làm theo đầu file `build-oaf.sh`. Chậm và tốn ổ đĩa hơn.)

## Bước 3 – Cài (nháy đúp `2-cai-shield.bat`)
Chạy được cả khi chưa có OAF (khi đó bỏ qua OAF, vẫn cài chặn theo giờ + AdGuard).
Gửi lại toàn bộ chữ hiện trên màn hình cho Claude.

## Bước 4 (tuỳ chọn) – Khoá SSH
`phase0-harden.sh` cần khoá SSH: trong cmd chạy `ssh-keygen -t ed25519`, gửi nội dung file `.pub` cho Claude để lên lệnh chính xác.
