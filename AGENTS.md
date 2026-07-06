# mpv-font-loader

mpv 的 Lua 脚本，播放视频时自动解析 ASS 字幕并加载所需字体。

## 项目

- **栈**: Lua (LuaJIT + FFI), 运行于 mpv 内
- **入口点**: `font_loader/main.lua`
- **依赖** (运行时携带): libuchardet / libiconv (FFI)
- **构建工具**: `release.sh` 打包发布 tar.gz
- **无测试框架** — 纯脚本项目，拷贝到 mpv `scripts` 目录安装

## 命令

无构建/测试命令。安装方式：
1. 将 `font_loader/` 目录放入 mpv 的 `scripts/` 目录
2. 将 `font_loader.conf` 放入 `script-opts/` 目录，修改 `fontDir` 指向字体文件夹
3. 可选：设置 `remoteFontDir` 指向远程字体目录，`report=yes` 启用字体加载报告

预编译包在根目录下：`font_loader-{os}-{arch}-v{version}.tar.gz` 格式，版本号见 `release.sh`

## 架构

| 模块 | 文件 | 职责 |
|---|---|---|
| **入口 + 编排** | `font_loader/main.lua` | 读取配置、初始化模块、绑定事件。main() 创建 context 并分发给各函数 |
| **字体索引** | `font_loader/index.lua` | 索引加载/构建/缓存，mtime 检测，远程字体目录 fallback |
| **平台文件操作** | `font_loader/common.lua` | `link`/`unlink`/`mkdir`/`rmdir`/`rm` — 跨平台文件操作，通过 `subprocess` 调用系统命令 |
| **字体索引解析** | `font_loader/fc.lua` | 解析 `fc-subs.db` 建 `字体名→文件` 映射；JSON 序列化/反序列化索引缓存 |
| **ASS 解析** | `font_loader/ass.lua` | 读取 ASS 字幕，从 `[V4 Styles]` 和 `[Events]` 段提取实际使用的字体名 |
| **编码检测** | `font_loader/uchardet.lua` | FFI 调用 libuchardet 检测文件编码 |
| **编码转换** | `font_loader/iconv.lua` | FFI 调用 libiconv 转换字符集 |
| **加载报告** | `font_loader/report.lua` | 可选的字体加载审计报告，记录 Required/Loaded/Failed/Unused |
| **Unicode 工具** | `font_loader/unicode.lua` | UTF-8 ↔ UTF-16 互转，纯 Lua 实现 |
| **行读取器** | `font_loader/line_iter.lua` | 逐行读取带编码转换的文件 |

### 核心流程

1. 读取 `font_loader.conf` → 获取 `fontDir` / `cacheDir` / `remoteFontDir` / `report`
2. `index.lua` 检查 `font-index` 缓存：若不存或 `fc-subs.db` 较新则重建，JSON 序列化缓存
3. 若配置 `remoteFontDir` 且可访问，使用远程目录替代本地
4. 创建随机时间戳临时目录作为字体缓存
5. 监听 `track-list` 属性 → `loader` 扫描外挂字幕 → ASS 解析提取实际使用的字体 → 查找索引 → 创建符号链接
6. 切换视频时自动重置状态，重新解析
7. 设置 `sub-fonts-dir` 为临时目录路径
8. `shutdown` 事件清理符号链接和临时目录，可选写入字体加载报告

## 约定

- **注释/文档用中文**；代码标识符、字符串用英文
- **Git 提交信息使用英文**
- **ASS 解析前必须通过 uchardet 检测编码 + iconv 转为 UTF-8**
- **关键 IO 用 `assert()` 断言**；非关键路径用 `if not ...` + `log.warn/error`
- **日志使用 `mp.msg`**：`log.info/warn/error/debug`
- **模块化**: 每个功能一个文件，`return { ... }` 导出，`require` 引入
- **配置**: `mp.options.read_options(options, "font_loader")` 读取，前缀对应 `font_loader.conf`
- **跨平台文件操作**: Windows 用 `cmd /c mklink`，其他平台用 `ln -s`
- **main 分支上的提交需要 GPG 签名**

## 待实现功能 (TODO)

- [x] `fc-subs.db` 文件变动检查并自动更新字体索引
- [ ] 扫描字体库文件夹，去除对 `fc-subs.db` 的依赖
