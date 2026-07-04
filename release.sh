#!/usr/bin/env bash
# release.sh — 下载依赖、组装、打包 mpv-font-loader 发布包
# 用法: ./release.sh [--version 0.5.1] [--os windows|macos|linux] [--arch amd64|arm64]
#       不指定参数则自动检测当前平台

set -euo pipefail

# ─── 参数解析 ───────────────────────────────────────────────

VERSION="0.5.1"
TARGET_OS=""
TARGET_ARCH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --os)      TARGET_OS="$2"; shift 2 ;;
        --arch)    TARGET_ARCH="$2"; shift 2 ;;
        -h|--help)
            echo "用法: $0 [--version X.Y.Z] [--os windows|macos|linux] [--arch amd64|arm64]"
            exit 0
            ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
done

# ─── 平台检测 ───────────────────────────────────────────────

detect_os() {
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        Darwin)                echo "macos" ;;
        Linux)                 echo "linux" ;;
        *) echo "未知系统: $(uname -s)"; exit 1 ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "amd64" ;;
        arm64|aarch64) echo "arm64" ;;
        *) echo "未知架构: $(uname -m)"; exit 1 ;;
    esac
}

TARGET_OS="${TARGET_OS:-$(detect_os)}"
TARGET_ARCH="${TARGET_ARCH:-$(detect_arch)}"

echo ">>> 目标: ${TARGET_OS}-${TARGET_ARCH} v${VERSION}"

# ─── 常量 — ConanCenter 已验证的包 ──────────────────────────

CONAN_BASE="https://center2.conan.io/v2/conans"

# uchardet/0.0.8  recipe_rev: 6ab25e452021fcdb560f4e37f4a27bc1
declare -A UCHARDET_PKG=(
    [windows-amd64]="a818caff19c116dafdc2337a9b30675bd75e8985"
    [macos-arm64]="c61e9af79e5b573dcc59aa722ab481a49519393e"
    [linux-amd64]="fc491156b442836722612d1aa8a8c57e406447b6"
)
declare -A UCHARDET_REV=(
    [windows-amd64]="af51f1ffe83a08d5e933783405d7af9e"
    [macos-arm64]="1e0a4214616175f56f752daad9b72b1e"
    [linux-amd64]="b856a2746238931b75bd3bf33a22b403"
)
UCHARDET_RECIPE_REV="6ab25e452021fcdb560f4e37f4a27bc1"

# libiconv/1.18  recipe_rev: 6777b6045492997dd87e1f55a027e551
declare -A ICONV_PKG=(
    [windows-amd64]="19e318a866610969ae17aaa36552350ac86725f0"
    [macos-arm64]="2f813e311fb9c41521c47949c9a19c12f085829b"
    [linux-amd64]="17561cbc2922b459119809d525458e11e7bcb047"
)
declare -A ICONV_REV=(
    [windows-amd64]="8235100425634988db101c1e360fb3f5"
    [macos-arm64]="8a3218147dde7444780cae4795ce5a5b"
    [linux-amd64]="1faa8386ec1dc01e3137188cf94a1e3e"
)
ICONV_RECIPE_REV="6777b6045492997dd87e1f55a027e551"

CBOR_URL="https://luarocks.org/manifests/zash/lua-cbor-1.0.0-1.src.rock"

PLATFORM_KEY="${TARGET_OS}-${TARGET_ARCH}"

# ─── 工作目录 ───────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$(mktemp -d)"
OUT_DIR="${BUILD_DIR}/font_loader"
trap 'rm -rf "$BUILD_DIR"' EXIT

echo ">>> 构建目录: ${BUILD_DIR}"

# ─── 工具函数 ───────────────────────────────────────────────

# 从 ConanCenter 下载包，提取指定文件到 OUT_DIR
# 参数: name version recipe_rev pkg_id pkg_rev src_file [dst_name]
download_conan() {
    local name="$1" version="$2" recipe_rev="$3" pkg_id="$4" pkg_rev="$5"
    local src="$6"
    local dst
    if [ $# -ge 7 ]; then
        dst="$7"
    else
        dst="$(basename "$src")"
    fi

    local url="${CONAN_BASE}/${name}/${version}/_/_/revisions/${recipe_rev}/packages/${pkg_id}/revisions/${pkg_rev}/files/conan_package.tgz"

    echo "    下载: ${name} → ${dst}"
    curl -fsSL "$url" | tar -xzf - -C "$OUT_DIR" --transform "s|.*/||" "$src"

    # 需要重命名
    local extracted_name
    extracted_name="$(basename "$src")"
    if [ "$extracted_name" != "$dst" ]; then
        mv "${OUT_DIR}/${extracted_name}" "${OUT_DIR}/${dst}"
    fi
}

# 从 ConanCenter 下载并提取多个文件
download_conan_multi() {
    local name="$1" version="$2" recipe_rev="$3" pkg_id="$4" pkg_rev="$5"
    shift 5
    # 剩余参数: src1 dst1 [src2 dst2 ...]

    local url="${CONAN_BASE}/${name}/${version}/_/_/revisions/${recipe_rev}/packages/${pkg_id}/revisions/${pkg_rev}/files/conan_package.tgz"

    local tmpdir="${BUILD_DIR}/_extract"
    mkdir -p "$tmpdir"
    curl -fsSL "$url" | tar -xzf - -C "$tmpdir"

    while [[ $# -ge 2 ]]; do
        local src="$1" dst="$2"
        shift 2
        echo "    提取: $(basename "$src") → ${dst}"
        cp "${tmpdir}/${src}" "${OUT_DIR}/${dst}"
    done

    rm -rf "$tmpdir"
}

# ─── 创建输出目录 ───────────────────────────────────────────

mkdir -p "$OUT_DIR"

# ─── 复制脚本文件 ───────────────────────────────────────────

echo ">>> 复制 Lua 脚本..."
cp "${SCRIPT_DIR}/font_loader/"*.lua "$OUT_DIR/"

# ─── 下载 cbor.lua ──────────────────────────────────────────

echo ">>> 下载 cbor.lua..."
curl -fsSL "$CBOR_URL" -o "${BUILD_DIR}/cbor.rock"
unzip -p "${BUILD_DIR}/cbor.rock" 'lua-cbor-1.0.0.tar.gz' \
    | tar -xzf - --to-stdout 'lua-cbor-1.0.0/cbor.lua' > "${OUT_DIR}/cbor.lua"
echo "    完成: cbor.lua"

# ─── 下载 libuchardet ───────────────────────────────────────

echo ">>> 下载 libuchardet..."

U_PKG="${UCHARDET_PKG[$PLATFORM_KEY]}"
U_REV="${UCHARDET_REV[$PLATFORM_KEY]}"

case "$TARGET_OS" in
    windows)
        download_conan "uchardet" "0.0.8" "$UCHARDET_RECIPE_REV" "$U_PKG" "$U_REV" \
            "bin/uchardet.dll"
        ;;
    macos)
        download_conan "uchardet" "0.0.8" "$UCHARDET_RECIPE_REV" "$U_PKG" "$U_REV" \
            "lib/libuchardet.dylib"
        ;;
    linux)
        download_conan "uchardet" "0.0.8" "$UCHARDET_RECIPE_REV" "$U_PKG" "$U_REV" \
            "lib/libuchardet.so"
        ;;
esac

# ─── 下载 libiconv ──────────────────────────────────────────

echo ">>> 下载 libiconv..."

I_PKG="${ICONV_PKG[$PLATFORM_KEY]}"
I_REV="${ICONV_REV[$PLATFORM_KEY]}"

case "$TARGET_OS" in
    windows)
        download_conan_multi "libiconv" "1.18" "$ICONV_RECIPE_REV" "$I_PKG" "$I_REV" \
            "bin/iconv-2.dll"   "iconv.dll" \
            "bin/charset-1.dll" "charset-1.dll"
        ;;
    macos)
        download_conan_multi "libiconv" "1.18" "$ICONV_RECIPE_REV" "$I_PKG" "$I_REV" \
            "lib/libiconv.dylib"   "libiconv.dylib" \
            "lib/libcharset.1.dylib" "libcharset.1.dylib"
        ;;
    linux)
        download_conan_multi "libiconv" "1.18" "$ICONV_RECIPE_REV" "$I_PKG" "$I_REV" \
            "lib/libiconv.so"   "libiconv.so" \
            "lib/libcharset.so" "libcharset.so"
        ;;
esac

# ─── 输出文件列表 ───────────────────────────────────────────

echo ""
echo ">>> font_loader/ 内容:"
ls -la "$OUT_DIR"

# ─── 打包 ───────────────────────────────────────────────────

OUTPUT_NAME="font_loader-${TARGET_OS}-${TARGET_ARCH}-v${VERSION}.tar.gz"
OUTPUT_PATH="${SCRIPT_DIR}/${OUTPUT_NAME}"

echo ""
echo ">>> 打包: ${OUTPUT_NAME}"

tar -czf "$OUTPUT_PATH" \
    -C "$BUILD_DIR" \
    "font_loader" \
    -C "$SCRIPT_DIR" \
    "font_loader.conf"

echo ""
echo ">>> 完成! ${OUTPUT_PATH}"
ls -lh "$OUTPUT_PATH"
