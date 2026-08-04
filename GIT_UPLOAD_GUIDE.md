# 上传到 Git 仓库

解压源码包后，在项目根目录执行：

```powershell
git init
git add .
git commit -m "Initial Flutter work experience library"
git branch -M main
git remote add origin 你的仓库地址
git push -u origin main
```

不要把运行后生成的证书、`library.json`、`.dwr` 备份、`.dart_tool`、`build` 或 `dist` 上传到仓库。`.gitignore` 已配置这些规则。

上传前可执行：

```powershell
flutter pub get
flutter analyze
flutter test
flutter build windows --release
```

如果 Git 平台只允许网页上传，请先解压 ZIP，再上传解压后的项目文件；不要把 ZIP 本身当作仓库源码结构。
