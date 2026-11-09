# 构建脚本

- `sync-official.sh`：拉官方 `dsh-v*` tag，默认构建最新 tag（+ 最新 stable）；`--latest` 仅最新；`--all` 全量历史。产物落 `dist/<tag>/` 并刷新 `dist/index.json`。
- `build-tag.sh <tag>`：构建单个 tag（克隆 → 打 `patches/` → `pnpm install` → 打包）。
- `package-linux.sh`：上游源码树内的完整流水线（构建 artifacts → 打包 dsh runtime → electron-builder 出 deb/AppImage）。
- `publish-mirror.sh <tag>`：把 `dist/<tag>/` 的产物发布到本仓库 Releases（`MIRROR_REPO` 环境变量 + `gh` 登录）。

依赖：Node.js >= 24.9、pnpm 11.28.5、git、python3、dpkg-deb、tar；磁盘约 20 GB。
