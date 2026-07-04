# mpv-font-loader

mpv 的 Lua 脚本，播放视频时自动解析 ASS 字幕并加载所需字体。

## 项目

- **栈**: Lua (LuaJIT + FFI), 运行于 mpv 内
- **入口点**: `font_loader/main.lua`
- **依赖** (运行时携带): libuchardet / libiconv (FFI)、lua-cbor (CBOR 序列化)
- **无构建系统 / 无测试框架** — 纯脚本项目，拷贝到 mpv `scripts` 目录安装

## 命令

无构建/测试命令。安装方式：
1. 将 `font_loader/` 目录放入 mpv 的 `scripts/` 目录
2. 将 `font_loader.conf` 放入 `script-opts/` 目录，修改 `fontDir` 指向字体文件夹

预编译包在根目录下：`font_loader-{os}-{arch}-v0.5.1.tar.gz`

## 架构

| 模块 | 文件 | 职责 |
|---|---|---|
| **入口 + 编排** | `font_loader/main.lua` | 读取配置、加载/构建字体索引、监听 mpv 事件、管理临时字体缓存目录 |
| **平台文件操作** | `font_loader/common.lua` | `link`/`unlink`/`mkdir`/`rmdir`/`rm` — 跨平台文件操作，通过 `subprocess` 调用系统命令 |
| **字体索引** | `font_loader/fc.lua` | 解析 `fc-subs.db` 建立 `字体名→文件` 映射；CBOR 序列化/反序列化索引缓存 |
| **ASS 解析** | `font_loader/ass.lua` | 读取 ASS 字幕，从 `[V4 Styles]` 和 `[Events]` 段提取字体名 |
| **编码检测** | `font_loader/uchardet.lua` | FFI 调用 libuchardet 检测文件编码 |
| **编码转换** | `font_loader/iconv.lua` | FFI 调用 libiconv 转换字符集 |
| **Unicode 工具** | `font_loader/unicode.lua` | UTF-8 ↔ UTF-16 互转，纯 Lua 实现 |
| **行读取器** | `font_loader/line_iter.lua` | 逐行读取带编码转换的文件 |

### 核心流程

1. 读取 `font_loader.conf` → 获取 `fontDir` / `cacheDir` / `fontIndexFile`
2. 检查 `font-index` 缓存文件；若不存在或有 `update.txt` 标记，从 `fc-subs.db` 重建索引
3. 将索引缓存为 CBOR 文件
4. 创建随机时间戳临时目录作为字体缓存
5. 监听 `track-list` 属性 → 扫描外挂字幕轨道 → 解析 ASS 提取字体名 → 索引中查找 → 在临时目录创建符号链接
6. 设置 `sub-fonts-dir` 为临时目录路径
7. `shutdown` 事件清理所有符号链接和临时目录

## 约定

- **注释/文档用中文**；代码标识符、字符串用英文
- **ASS 解析前必须通过 uchardet 检测编码 + iconv 转为 UTF-8**
- **关键 IO 用 `assert()` 断言**；非关键路径用 `if not ...` + `log.warn/error`
- **日志使用 `mp.msg`**：`log.info/warn/error/debug`
- **模块化**: 每个功能一个文件，`return { ... }` 导出，`require` 引入
- **配置**: `mp.options.read_options(options, "font_loader")` 读取，前缀对应 `font_loader.conf`
- **跨平台文件操作**: Windows 用 `cmd /c mklink`，其他平台用 `ln -s`；可选 busybox 替代

## 待实现功能 (TODO)

- [ ] `fc-subs.db` 文件变动检查并自动更新字体索引
- [ ] 扫描字体库文件夹，去除对 `fc-subs.db` 的依赖
