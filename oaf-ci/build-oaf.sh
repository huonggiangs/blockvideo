#!/bin/bash
# Build kmod-oaf + appfilter (+ luci-app-oaf nếu được) bằng SDK OpenWrt 25.12.5 cho mediatek/filogic.
# CHẠY TRÊN MÁY LINUX CÓ MẠNG (Ubuntu 22.04/24.04, hoặc WSL2 Ubuntu trên Windows). ~10GB trống, 20–60 phút.
# CHƯA CHẠY THỬ (môi trường của tôi không tải được downloads.openwrt.org).
#
# Windows: mở PowerShell -> `wsl --install -d Ubuntu`, vào Ubuntu rồi:
#   sudo apt update && sudo apt install -y build-essential clang flex bison g++ gawk gcc-multilib gettext git libncurses5-dev libssl-dev python3-setuptools rsync swig unzip zlib1g-dev file wget zstd python3
#   cp "/mnt/d/JOB/Block video/FW/scripts/build-oaf.sh" ~ && bash ~/build-oaf.sh
# Kết quả: ~/oaf-build/out/*.apk  +  build.log  (nếu lỗi, gửi build.log)
set -uo pipefail
REL="${REL:-25.12.5}"                 # PHẢI khớp bản trên router (kernel 6.12.94)
TARGET="mediatek/filogic"
OAF_REPO="https://github.com/destan19/OpenAppFilter.git"
OAF_COMMIT="${OAF_COMMIT:-7fcf9e87dc75f7c28c74e09504a4efa0a2db3c92}"   # commit đã xem 24/09/2026; ghim để build lặp lại được
WORK="${WORK:-$HOME/oaf-build}"
OUT="$WORK/out"; LOG="$WORK/build.log"
mkdir -p "$WORK" "$OUT"; cd "$WORK"
exec > >(tee -a "$LOG") 2>&1
step() { echo; echo "=== $* ==="; }
die()  { echo "LỖI: $*"; echo "Xem $LOG"; exit 1; }

step "Kiểm tra công cụ"
for t in gcc g++ make git python3 zstd rsync unzip wget curl file gawk; do command -v $t >/dev/null || die "thiếu $t (xem lệnh apt ở đầu file)"; done
[ "$(id -u)" != 0 ] || die "đừng build bằng root (OpenWrt từ chối)"
case "$PWD" in /mnt/*) die "đừng build trên ổ /mnt (rất chậm, lỗi quyền). Dùng WORK trong \$HOME";; esac

BASE="https://downloads.openwrt.org/releases/$REL/targets/$TARGET"
step "Tải SDK $REL"
curl -fsSL "$BASE/sha256sums" -o sha256sums || die "không tải được $BASE/sha256sums"
SDK=$(awk '{print $2}' sha256sums | sed 's/^\*//' | grep -E '^openwrt-sdk-.*\.tar\.zst$' | head -1)
[ -n "$SDK" ] || die "không tìm thấy file SDK trong sha256sums"
[ -f "$SDK" ] || curl -fSLO "$BASE/$SDK" || die "tải SDK lỗi"
grep -F "$SDK" sha256sums | sed 's/ \*/  /' | sha256sum -c - || die "SHA256 SDK không khớp"

step "Giải nén SDK"
if [ ! -d sdk ]; then mkdir sdk && tar --zstd -xf "$SDK" -C sdk --strip-components=1 || die "giải nén lỗi"; fi
cd sdk

step "Lấy mã nguồn OAF @ ${OAF_COMMIT:0:8}"
if [ ! -d package/OpenAppFilter/.git ]; then git clone "$OAF_REPO" package/OpenAppFilter || die "clone lỗi"; fi
git -C package/OpenAppFilter fetch --quiet origin || true
git -C package/OpenAppFilter checkout --quiet "$OAF_COMMIT" || die "không checkout được commit $OAF_COMMIT"
# Bản vá nhỏ: chuẩn hoá xuống dòng nếu repo có CRLF
find package/OpenAppFilter -name Makefile -exec sed -i 's/\r$//' {} +

step "Cập nhật feeds (chỉ gói cần cho OAF)"
./scripts/feeds update -a >/dev/null || die "feeds update lỗi"
./scripts/feeds install libsqlite3 libcurl libjson-c libubox libubus libuci libuci-lua lua luci-base luci-compat luci-lib-jsonc 2>&1 | tail -15
# Gói nào không còn trong 25.12 sẽ hiện "WARNING: No feed for package" ở trên -> ghi lại, KHÔNG dừng

step "Cấu hình"
cat > .config <<CFG
CONFIG_PACKAGE_kmod-oaf=m
CONFIG_PACKAGE_appfilter=m
CONFIG_PACKAGE_luci-app-oaf=m
CFG
make defconfig >/dev/null
grep -E 'kmod-oaf|appfilter|luci-app-oaf' .config

build_pkg() { # đường dẫn gói, tên
	step "Build $2"
	make "package/OpenAppFilter/$1/compile" V=s -j"$(nproc)" || { echo "!! $2 build LỖI"; return 1; }
}
build_pkg oaf kmod-oaf            || die "kmod-oaf lỗi: thường do API kernel 6.12; gửi build.log"
build_pkg open-app-filter appfilter || die "appfilter lỗi: kiểm tra libuci-lua/libsqlite3/libcurl trong log"
build_pkg luci-app-oaf luci-app-oaf || echo "(luci-app-oaf lỗi/không hỗ trợ trên 25.12 vì cần luci-compat/Lua — KHÔNG bắt buộc; dùng UCI/CLI)"

step "Gom kết quả"
find bin -type f \( -name 'kmod-oaf*.apk' -o -name 'appfilter*.apk' -o -name 'luci-app-oaf*.apk' \) -exec cp -v {} "$OUT/" \;
ls -la "$OUT"
( cd "$OUT" && sha256sum *.apk | tee SHA256SUMS )
ls "$OUT"/kmod-oaf*.apk >/dev/null 2>&1 && ls "$OUT"/appfilter*.apk >/dev/null 2>&1 || die "thiếu kmod-oaf hoặc appfilter trong kết quả"

cat <<DONE

XONG. Chép lên router (chạy ngay trong WSL/Linux này; nếu WSL không thấy router thì chép file ra Windows rồi scp từ cmd):
  ssh root@192.168.3.1 "mkdir -p /tmp/oaf"
  scp -O $OUT/*.apk root@192.168.3.1:/tmp/oaf/
Rồi chạy install-live.sh (đọc phần đầu file).
DONE
