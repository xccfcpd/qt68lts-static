@chcp 65001
@cd /d "%~dp0"

:: 由 workflow 注入（自动解析 6.8 LTS 最新 patch），也可本地手工设置后直接运行
:: QT_VERSION  : 构建的 Qt 版本（本地默认 6.8.5；CI 由 Resolve Qt version 步骤注入）
:: QT_SRC_DIR  : 解压后的源码顶层目录名（6.8.4 起为 qt-everywhere-opensource-src-<版本>）
:: MINGW_BIN   : mingw-lite 14.4.0 的 bin 目录
:: QT_ROOT     : 构建根目录
IF NOT DEFINED QT_VERSION SET QT_VERSION=6.8.5
IF NOT DEFINED QT_ROOT SET QT_ROOT=D:\a\QtBuild
IF NOT DEFINED QT_SRC_DIR SET QT_SRC_DIR=qt-everywhere-opensource-src-%QT_VERSION%
:: mingw-lite 14.4-v1.1 的 7z 包内层级为 mingw64-ucrt-14\bin（CI 上由 workflow 递归探测后覆盖）
IF NOT DEFINED MINGW_BIN SET MINGW_BIN=%QT_ROOT%\Tools\mingw1440_64\mingw64-ucrt-14\bin

:: 设置编译器代号（影响 build / install 目录与产物命名）
SET MinGW_VERSION=mingw1440_64_UCRT

:: 设置编译器、Ninja（Qt 6.8 构建不需要 Perl）
:: 注意：不要把任何 Strawberry\c\bin 加进 PATH，它带 pg_config.exe/cmake.exe/libpq.a，
:: 会让 configure 误检测到 PostgreSQL 并链接错位的 libpq.a，同时劫持 cmake。
SET PATH=%MINGW_BIN%;%QT_ROOT%\ninja;%PATH%

:: 快速失败：工具链缺失时立刻报错，而不是等到编译中途才发现
where g++ >nul 2>nul || (echo g++ not found, check MINGW_BIN: "%MINGW_BIN%" & EXIT /B 1)
where ninja >nul 2>nul || (echo ninja not found, check "%QT_ROOT%\ninja" & EXIT /B 1)
where cmake >nul 2>nul || (echo cmake not found in PATH & EXIT /B 1)

:: 设置Qt文件夹路径
SET QT_PATH=%QT_ROOT%\Qt

::----------以下无需修改----------

:: 设置Qt源代码目录（变量本身不带引号，用时再加，避免嵌套引号）
SET SRC_QT=%QT_PATH%\%QT_VERSION%\%QT_SRC_DIR%

:: 设置安装文件夹目录
SET INSTALL_DIR=%QT_PATH%\%QT_VERSION%-static\%MinGW_VERSION%

:: 设置build文件夹目录
SET BUILD_DIR=%QT_PATH%\%QT_VERSION%\build-%MinGW_VERSION%

:: 根据需要进行全新构建（mkdir 对已存在目录会返回 1，故与 cd 解耦判断）
IF EXIST "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
mkdir "%BUILD_DIR%"
IF ERRORLEVEL 1 (echo cannot create build dir: "%BUILD_DIR%" & EXIT /B 1)
cd /d "%BUILD_DIR%"
IF ERRORLEVEL 1 (echo cannot enter build dir: "%BUILD_DIR%" & EXIT /B 1)

:: configure（多行续行：^ 后不能有任何字符；用 if errorlevel 判断结果）
:: Qt6 默认自带 harfbuzz；如需强制内联 webp/tiff，可追加 -qt-harfbuzz -qt-webp -qt-tiff
:: CI runner 的 PATH 里 Strawberry Perl 的 c\bin 带 pg_config.exe，会让 configure 误判出
:: PostgreSQL 并静态链接 Strawberry 的 libpq.a（其 pthread 符号与 mingw 的 libpthread.a 冲突，
:: assistant.exe 就会链接失败）；这里双重关闭：-no-sql-psql 关掉驱动（官方开关，定义于
:: qtbase/src/plugins/sqldrivers/qt_cmdline.cmake），CMAKE_DISABLE_FIND_PACKAGE_PostgreSQL=ON 连查找也禁止。
:: 注：CMake 变量按 Qt6 configure 语法写成 VAR=value（等价于 -- -DVAR=value），裸 -D 会被判为未知选项。
call "%SRC_QT%\configure.bat" ^
  -prefix "%INSTALL_DIR%" ^
  -release -static -static-runtime ^
  -platform win32-g++ ^
  -opensource -confirm-license ^
  -qt-zlib -qt-libpng -qt-libjpeg -qt-freetype -qt-pcre -qt-harfbuzz -qt-webp -qt-tiff ^
  -schannel -opengl desktop ^
  -no-sql-psql ^
  CMAKE_DISABLE_FIND_PACKAGE_PostgreSQL=ON ^
  -nomake examples -nomake tests ^
  -skip qtwebengine -skip qtdoc -skip qtwebview
if errorlevel 1 (echo configure FAILED & EXIT /B 1)

:: 编译、安装
cmake --build . --parallel || (echo build FAILED & EXIT /B 1)
ninja install || (echo install FAILED & EXIT /B 1)

::复制qt.conf（/y：重复运行时覆盖已存在的文件，避免交互式询问卡住）
copy /y "%~dp0qt.conf" "%INSTALL_DIR%\bin"

:: CI 下直接退出，本地运行时保留一个已定位到安装目录的窗口
IF DEFINED CI (EXIT /B 0) ELSE (@cmd /k cd /d "%INSTALL_DIR%")
