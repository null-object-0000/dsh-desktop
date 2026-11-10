# dsh-desktop

**DeepSeek Harness 桌面端（dsh）的 Linux 构建产物**：跟随官方 [deepseek-harness](https://github.com/deepseek-ai/deepseek-harness) 的 release tag，产出可安装的 `.deb`（以及 AppImage）。

> DeepSeek Harness（`dsh`）是 DeepSeek AI 开源的 agent harness。上游桌面端只发布 macOS / Windows 安装包，**Linux 不是官方发布目标**。本仓库是社区侧的非官方 Linux 打包，补上 `linux-x64` 目标并修正 Linux 专属二进制路径，构建流程复用上游的打包流水线。

## 下载

到 [Releases](https://github.com/null-object-0000/dsh-desktop/releases) 下载最新的：

- `deepseek-harness-<版本>-linux-amd64-unsigned.deb` —— Ubuntu 22.04+ / amd64
- （若有）`deepseek-harness-<版本>-linux-x86_64-unsigned.AppImage`

安装：

```bash
sudo dpkg -i deepseek-harness-*.deb
sudo apt -f install
```

启动：应用菜单里的 “DeepSeek Harness”，或 `/opt/DeepSeek Harness/deepseek-harness`。

> 本机构建/测试环境里 `chrome-sandbox` 没有 setuid，直接跑二进制需要加 `--no-sandbox`；由 `dpkg` 安装并由桌面环境启动时按包内配置执行。

## 版本

每个 Release 对应一个官方 tag（例如 `dsh-v0.2.2-rc.1`）。当前只有官方预发布（rc）版本，正式版发布后本仓库会跟随。版本索引见 [`dist/index.json`](dist/index.json)。

## 图片解码（Linux 修复）

`sharp` 的预编译 libvips 在 Electron 的 Node 运行时下解码会 SIGSEGV（Electron 44.7/44.9/45、sharp 0.34/0.35 均复现；随包独立 Node 24.21 正常）。本仓库补丁把光栅操作转发给 primary-runtime 里的独立 Node 子进程执行，并把 `sharp`、`@img/*`、`detect-libc`、`semver` 从 ASAR 解包供纯 Node 读取。

已验证（真实安装包启动）：粘贴 900×700 PNG、文件选择器上传 900×700 PNG 均成功保存且 Host 无崩溃；ASAR 布局下 `saveImage` / `readImageRequest` 解码+归一化+JPEG 编码均通过。

图标：构建时把 1104px 的主图标渲染成 16–1024 的标准 hicolor 尺寸再打包，桌面启动器与商店图标都能解析（此前只有 `1104x1104` 目录，图标主题不会扫描，安装后显示占位图标）。
- 无系统托盘、无应用内自动更新（更新由包管理器或重新下载完成）。
- 未做 deb/GPG 签名。
- deb 版本号按 Debian 规则把 `-rc.1` 规范成 `0.2.2~rc.1`。

## 当前版本

最新 Release 由 CI 构建并验证（图片解码回归测试通过）：

- `deepseek-harness-0.2.2-rc.1-linux-amd64-unsigned.deb` — sha256 `aef75d464861e2a7460943ab0505adb47baaa468e6e97ec0a18ec558e32116e4`（deb 版本 `0.2.2~rc.1.linux.5`）
- `deepseek-harness-0.2.2-rc.1-linux-x86_64-unsigned.AppImage` — sha256 `f80731d95fa9a8b7f5090fc5bb599bf100d8a48eb7ff57ee49ab096ef44899c2`
- 上游 commit：`66491b05e3f05ad35bcdd4f6cd7ed26041d9e3db`（tag `dsh-v0.2.2-rc.1`）

## 自动构建（GitHub Actions）

`build-linux.yml` 工作流每 6 小时检查一次上游 `dsh-v*` tag：有新版本时在 GitHub 托管 runner 上克隆该 tag、应用补丁、构建并验证图片解码，然后把 `.deb` / `.AppImage` / `manifest.json` 发布到本仓库 Releases（UManager 的 feed CI 每 30 分钟轮询 `/releases/latest`，商店自动可见）。也可以手动触发：

```bash
gh workflow run build-linux.yml --repo null-object-0000/dsh-desktop \
  -f tag=dsh-v0.2.2-rc.1 -f force=true
```

## 本地构建

见 [`scripts/`](scripts/README.md)：

```bash
./scripts/sync-official.sh              # 跟随官方：最新 tag（+ 最新 stable）
./scripts/build-tag.sh dsh-v0.2.2-rc.1  # 指定 tag
./scripts/publish-mirror.sh <tag>       # 发布到本仓库 Releases（需 gh 登录）
```

依赖 Node.js >= 24.9、pnpm 11.28.5、git、python3、dpkg-deb，磁盘约 20 GB；构建较重，推荐 16 GB 内存以上。

## 许可

构建脚本与补丁以 MIT 提供；打包产物来自上游 [deepseek-harness](https://github.com/deepseek-ai/deepseek-harness)（MIT）。
