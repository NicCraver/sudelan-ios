# 速删 iOS v0.2

与 Android v0.2 对齐的极简照片整理应用：抖音式底栏 + 冻结手势刷删 + 应用内回收站。

## 底栏

| Tab | 功能 |
|-----|------|
| **刷删** | 全屏滑动流（默认） |
| **相册** | 三列网格；点按跳进刷删该张；可多选移入回收站 |
| **回收站** | 软删列表；恢复 / 全部恢复；清空 = 一次 PHPhotoLibrary 批量删除 |
| **我的** | 今日/累计软删与永久删除、约释放空间、重新浏览 |

## 手势（已冻结，与 Android 一致）

- **上滑** → 下一张（标记已浏览）
- **下滑** → 上一张
- **右滑抛出** → **软删进回收站**（不立刻调系统删除）
- **左滑** → 回弹
- **轴锁定**：约 14pt 后锁定；近对角偏好竖直；交叉轴阻尼 0.08

## 删除模型（v0.2）

1. 右滑 / 相册多选 → UserDefaults 保存 ID，从相册与刷删流隐藏
2. 回收站恢复 → 回到相册 / 流
3. 清空回收站 → 一次 PHAssetChangeRequest.deleteAssets（系统确认）；取消则仍留在回收站
4. v0.1「待删暂存 + 删除 N 张」已并入回收站语义

## 已浏览

UserDefaults `seenPhotoIdentifiers`；加载时过滤；「我的 → 重新浏览」清空。

## 运行

1. macOS + Xcode 15+，打开 `QuickDelete.xcodeproj`
2. 选 iOS 17+ 模拟器/真机，⌘R
3. 授予照片库读写权限

无需 IPA；本仓库即源码。

## 结构

```
QuickDelete/
├── QuickDeleteApp.swift
├── ContentView.swift
├── Info.plist
├── Services/
│   ├── PhotoLibraryService.swift
│   └── DeleteAction.swift
└── Views/
    ├── PhotoSwipeCard.swift
    ├── SwipeFeedView.swift
    ├── AlbumView.swift
    ├── RecycleBinView.swift
    └── MeView.swift
```

## 版本

- **0.2.0** — 底栏四 Tab、软删回收站、相册跳转、我的统计
- 0.1.4 — 轴锁定手势
- 0.1.x — 批量待删、已浏览记忆、抛出动画

## License

供学习与参考使用。
