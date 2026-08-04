# 工作经验库 Flutter 版

这是原“工作经验库”网页版的独立 Flutter 客户端。项目保存在 Codex 工作区，原目录不会被修改。

## 功能

- Windows 桌面应用，宽屏英文界面
- iPhone PWA，可添加到主屏幕并离线使用
- 新增、编辑、搜索、Markdown 阅读、标签、分类及回收站
- 本地优先存储、`.dwr` 导入导出、同一局域网自动双向同步
- Windows 自动生成应用专用 HTTPS 根证书；根私钥不可导出

## iPhone 使用

1. 在 Windows 应用 Settings 的 iPhone PWA 区域查看 Setup URL 和 8 位 Pairing code。
2. 电脑和 iPhone 连接同一可信 Wi-Fi；Windows 防火墙只允许“专用网络”。
3. 用 iPhone Safari 打开 Setup URL，下载并安装证书描述文件。
4. 打开“设置 → 通用 → 关于本机 → 证书信任设置”，只信任 `Work Experience Library Local Root`。
5. 返回引导页，打开安全配对页并输入电脑显示的 8 位配对码。
6. 首次同步完成后，点“分享 → 添加到主屏幕”。

电脑离线时，PWA 仍可查看和编辑本机副本；电脑重新上线且双方处于同一局域网时自动同步。

## 安全与隐私

- HTTP 安装引导页不携带访问密钥；配对码只通过已验证的 HTTPS 页面提交。
- 配对码和访问密钥有失败频率限制；接口使用严格来源 Cookie、恒定时间密钥比较及安全响应头。
- 高级同步只接受 HTTPS；仅 `localhost` 回环调试允许 HTTP。
- PWA 的 Screen Lock 只是界面锁，不是加密。`.dwr`、Windows JSON 和 iPhone IndexedDB 均没有应用级加密。
- 请为 Windows 启用登录密码和 BitLocker/设备加密，为 iPhone 启用强密码；不要在公共 Wi-Fi 上配对。
- 交付或停用后，可从 iPhone 删除证书描述文件，并在 Windows“当前用户证书”中删除应用专用根证书。
- Windows 可执行文件当前未做代码签名；正式广泛分发时应使用可信代码签名证书。

## 开发

```powershell
flutter pub get
flutter run -d windows
flutter test
flutter analyze
```

iOS/macOS 原生构建需要安装 Xcode 的 Mac；当前 iPhone 交付方式是 PWA，不需要 App Store。

## 数据位置

Windows 数据位于系统 Application Support 下的 `work_experience_library/library.json`，并保留 `library.json.bak`。请定期导出 `.dwr` 备份，并把备份放在受保护的位置。