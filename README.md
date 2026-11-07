# qt68lts-static

用 GitHub Actions 从源码自动构建 **Qt 6.8 LTS 最新 patch** 的 Windows x86_64 **静态 Release** 版，并发布到 Releases。

## 特性

- 自动从 `download.qt.io/archive/qt/6.8/` 解析最新 `6.8.x`，也可手动指定版本复现构建
- 工具链：[mingw-lite 14.4.0-r1.1](https://github.com/xccfcpd/mingw-lite/releases/tag/14.4-v1.1) 的 `mingw64-ucrt`（GCC 14.4.0 / UCRT / posix / seh）
- 源码包按 Qt 官方同名 `.sha256` 强制校验，工具链包按固定 SHA256 校验，产物附 `.sha256`
- 静态配置：`-static -static-runtime -release`、`-schannel -opengl desktop`，跳过 `qtwebengine` / `qtdoc` / `qtwebview`，内联 zlib / libpng / libjpeg / freetype / pcre / harfbuzz / webp / tiff

## 使用

1. 打开仓库 **Actions** → `build_Qt6.8_MinGW1440_64` → **Run workflow**
2. `qt_version` 填 `latest`（默认，自动取 6.8 最新 patch），或填 `6.8.5` 这类具体版本复现旧构建
3. 完成后自动发布 Release，tag 与产物名为 `Qt_<版本>-static-Release_mingw1440_64_UCRT`

产物：`Qt_<版本>-static-Release_mingw1440_64_UCRT.7z`（完整安装目录）及同名 `.sha256`。

## 使用静态 Qt

- 编译自己的程序时必须用**同一套 mingw-lite 14.4.0 UCRT** 工具链，不要与 Qt 官方预编译包或其它 MinGW 混用
- `bin/qt.conf` 已配置 `Prefix = ..`，解压到任意目录后配合 CMake 的 `CMAKE_PREFIX_PATH` 使用
- 静态构建下需要的插件请在代码中用 `Q_IMPORT_PLUGIN` 引入

## 目录

```
.github/workflows/buildQt6_MinGW1440_64.yml   CI 工作流
buildQt6/build-Qt6mingw1440_64.cmd            编译脚本（也可本地运行）
buildQt6/qt.conf                              安装到 bin 的 qt.conf
LICENSE                                       GPLv3
```

## 说明

编译脚本派生自 [yuanpeirong/buildQt](https://github.com/yuanpeirong/buildQt)，沿用其 GPLv3 许可。
