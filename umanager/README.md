# 接入 UManager 软件商店

UManager（`~/.code/self-code/umanager`）的软件信息只来自 **Ed25519 签名的 feed**；新增应用走 `feed-sources.json`（CI 目录）→ GitHub Actions 抓取 + 签名 → 发布到 Pages，**不需要发新版 App**。

DSH 桌面端是「我们自己构建的 .deb，版本跟官方 tag」，所以推荐用已有的 `releaseApi` source kind：把每个版本的 `.deb` 作为 GitHub Release 资产发布到一个镜像仓库，UManager 从 releases API 读取最新一条。这样：
- 商店里的版本永远 = 官方最新（`allowPrerelease: true` 时包含 rc）；
- 每个官方版本都留一条 release，需要时能翻到旧版本；
- 不需要给 UManager 加新 source kind。

## 方案 A（推荐）：GitHub Release 镜像 + releaseApi

### 1. 建镜像仓库并发布 deb

新建一个公开仓库（例如 `null-object-0000/deepseek-harness-linux`），每个官方 tag 发布一条 release：

```bash
# 在 dsh-linux 目录下，tag 与官方一致；资产名保持 deb 原文件名
gh release create dsh-v0.2.2-rc.1 \
  dist/dsh-v0.2.2-rc.1/deepseek-harness-0.2.2-rc.1-linux-x64-unsigned.deb \
  --repo null-object-0000/dsh-desktop \
  --title "DeepSeek Harness 0.2.2-rc.1 (Linux)" \
  --prerelease \
  --notes "Built from official tag dsh-v0.2.2-rc.1; sha256 <from manifest.json>"
```

`scripts/sync-official.sh` 产出 `dist/index.json`，可以批量发布/核对。

### 2. 在 UManager 的 `feed-sources.json` 追加应用条目

`applications` 数组里追加（示例见 `deepseek-harness-desktop.feed-entry.json`）：

```json
{
  "applicationId": "deepseek-harness-desktop",
  "packageName": "deepseek-harness",
  "displayName": "DeepSeek Harness Desktop",
  "vendor": "DeepSeek",
  "architecture": "amd64",
  "description": "DeepSeek Harness（dsh）官方桌面客户端的 Linux 构建，跟随官方版本。",
  "homepage": "https://github.com/deepseek-ai/deepseek-harness",
  "icon": "deepseek-harness",
  "accentColor": "#4d6bfe",
  "removable": true,
  "source": {
    "kind": "releaseApi",
    "releaseApiUrl": "https://api.github.com/repos/null-object-0000/dsh-desktop/releases/latest",
    "releaseApiHosts": ["api.github.com"],
    "assetNamePattern": "deepseek-harness-{tagVersion}-linux-amd64-unsigned.deb",
    "stripTagPrefix": "dsh-v",
    "assetDownloadHosts": [
      "github.com",
      "objects.githubusercontent.com",
      "release-assets.githubusercontent.com"
    ],
    "allowPrerelease": true
  }
}
```

然后让 `.github/workflows/update-feed.yml` 的 `generate` schedule/push 触发（改 `feed-sources.json` 会在 push paths 命中的工作流里自动生成签名 feed）。如果希望单独成源（例如公司内源），按 `DESIGN-multi-source.md` §7 在 `feed-sources.json` 的 `sources` 里注册新源并在 workflow matrix 里加一行。

注意：
- `packageName` **必须等于** `.deb` 控制文件里的 `Package` 字段，构建后从 `dpkg-deb -f <deb> Package` 取，不要猜；
- 分类写入 umanager 的 `feed-categories.json`（`assignments.applications`），我们用的是 `ai-tools`
- `icon` 字段指向内置图标 id；新增应用图标由 CI 从 `.deb` 里提取（`scripts/desktop-icons.mjs`），deb 里需要 `/usr/share/icons/hicolor/*/apps/*.png` 与 `.desktop` 文件（electron-builder 会生成）；
- `allowPrerelease: true` 是必须的——官方目前只发 rc；
- UManager 安装时会再次校验 deb 包名/版本/架构与 feed 一致，所以镜像的资产名与 deb 控制信息不能改。

### 3. 版本选择

`releaseApi` 只解析「最新一条 release」。若要在商店里让用户挑版本，有两条路：
1. 在镜像仓库里按「通道」拆 release（例如 `nightly-latest` 固定一条），商店只显示通道最新；
2. 或在 UManager 侧扩展（`source_engine.rs` / `release_api`）支持版本列表——这不是本仓库的范围。

## 方案 B：内部 CDN / 内网 apt 仓库

如果 UManager 部署在内网，把 `.deb` 放到内部 HTTPS 后有两种接法：

- **固定最新 URL**（`stableDownloadEndpoint`）：`downloadUrl` 指向 `.../deepseek-harness-latest-amd64.deb`，每次构建覆盖；`page_version_marker` 可留空，版本从 deb 控制文件读取。
- **内部 apt 仓库**：生成 `dists/stable/main/binary-amd64/Packages.gz` + `Release`（可选 GPG 签名），使用 `aptRepository` source kind。适合需要多版本共存、按 apt 源做依赖管理的场景。

两种方式都需要你提供：内部域名/路径、是否有 CI 签名密钥、UManager 的 feed 签名流程由谁触发。

## 需要你确认/提供的信息

1. 镜像仓库地址（或内部 CDN 地址）与发布凭据；
2. `umanager` 的 feed 签名私钥由谁持有/在哪里跑（CI secret 还是本地脚本）；
3. 是否给 `.deb` 做 GPG 签名（UManager 的 `deb` 校验目前主要看下载 sha256 + 包名/版本/架构，GPG 不是必须，但商店治理通常会要求）；
4. 是否只提供 x64（amd64），还是也要 arm64（要先补 `linux-arm64` 的打包目标与自托管构建机）。
