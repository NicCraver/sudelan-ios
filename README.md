# 速删 (Quick Delete)

一个极简的 iOS 照片清理应用，采用直观的滑动手势快速删除不需要的照片。

## 🎯 核心功能

### 手势交互
- **向上滑动** → 跳过当前照片，查看下一张（标记为已查看）
- **向下滑动** → 返回上一张照片
- **向右滑动** → 标记照片为待删除（飞向右上角动画，同时标记已查看）
- **向左滑动** → 无操作（自动弹回）

### 记住浏览进度
- **自动记录**：向上滑或右滑删除的照片会被标记为"已查看"
- **持久化存储**：使用 UserDefaults 保存已查看照片的 ID
- **智能过滤**：重启应用后，已查看的照片不再显示
- **重新浏览**：当所有照片都已查看时，显示"重新浏览"按钮清空记录

### 批量删除机制
- 右滑照片时**不会立即删除**，而是暂存为"待删除"状态
- 屏幕右上角显示 `待删 N` 计数器
- 点击底部的 `删除 N 张` 按钮执行**一次性批量删除**
- 批量删除只调用一次 `PHPhotoLibrary.performChanges`，减少系统权限提示
- 删除失败时自动恢复暂存的照片

### 性能优化
- 使用 `PHCachingImageManager` 预加载前后照片
- 按屏幕尺寸请求图片，避免内存浪费
- 智能缓存管理，滑动时动态更新缓存范围

## 📱 界面说明

### 状态指示器（右上角）
- **橙色标签**：`待删 N` - 当前暂存待删除的照片数量
- **白色标签**：`今日已删 N` - 今天已成功删除的照片统计

### 批量删除按钮（底部）
- 有待删除照片时自动显示
- 红色渐变按钮：`删除 N 张`
- 点击后执行一次性批量删除

## 🚀 在 Mac 上运行

### 前置要求
- macOS 13.0+
- Xcode 15.0+
- iOS 17.0+ 设备或模拟器

### 构建步骤

1. **打开项目**
   ```bash
   open QuickDelete.xcodeproj
   ```
   或双击 `QuickDelete.xcodeproj` 文件

2. **选择目标设备**
   - 在 Xcode 顶部选择 iOS 设备或模拟器

3. **运行应用**
   - 按 `⌘ + R` 或点击播放按钮
   - 首次运行授予照片库权限

4. **测试手势**
   - 向上滑：下一张（标记已查看）
   - 向下滑：上一张（如果可用）
   - 向右滑：暂存删除（查看待删计数，同时标记已查看）
   - 点击"删除 N 张"：批量删除所有暂存照片

5. **测试浏览记录**
   - 向上滑跳过几张照片
   - 完全关闭应用（从后台杀掉）
   - 重新打开应用
   - 验证：之前跳过的照片不再出现
   - 当所有照片都已查看时，点击"重新浏览"按钮重置记录

### 代码签名
如果遇到签名问题：
1. 选择项目 → QuickDelete target
2. "Signing & Capabilities" 标签页
3. 勾选 "Automatically manage signing"
4. 选择你的开发团队

## 📂 项目结构

```
QuickDelete/
├── QuickDelete.xcodeproj/          # Xcode 项目文件
├── QuickDelete/
│   ├── Info.plist                  # 应用配置和权限描述
│   ├── QuickDeleteApp.swift        # 应用入口
│   ├── ContentView.swift           # 主视图协调器
│   ├── Services/
│   │   ├── PhotoLibraryService.swift   # 照片库服务（加载、缓存、批量删除）
│   │   └── DeleteAction.swift          # 删除反馈和动画配置
│   ├── Views/
│   │   ├── SwipeFeedView.swift         # 滑动流主视图（含批量删除按钮）
│   │   └── PhotoSwipeCard.swift        # 照片卡片组件（手势处理）
│   ├── Assets.xcassets/            # 图片资源
│   └── Preview Content/            # SwiftUI 预览资源
└── README.md                       # 本文件
```

## 🔧 技术实现

### 核心技术栈
- **语言**: Swift 5.0
- **UI 框架**: SwiftUI
- **照片管理**: PhotoKit
- **数据持久化**: UserDefaults (SeenStore)
- **最低版本**: iOS 17.0

### 浏览记录机制

1. **标记已查看**
   ```swift
   // 向上滑或右滑删除时
   func markAsSeen(asset: PHAsset) {
       var seen = seenIdentifiers  // UserDefaults Set<String>
       seen.insert(asset.localIdentifier)
       seenIdentifiers = seen
   }
   ```

2. **过滤已查看照片**
   ```swift
   // 加载照片时自动过滤
   func loadPhotos() {
       let seenIds = seenIdentifiers
       allPhotos.enumerateObjects { asset, _, _ in
           if !seenIds.contains(asset.localIdentifier) {
               assets.append(asset)
           }
       }
   }
   ```

3. **重新浏览**
   ```swift
   // 清空已查看记录
   func clearSeenStore() {
       seenIdentifiers = []
       loadPhotos()  // 重新加载所有照片
   }
   ```

### 批量删除流程

1. **暂存阶段**
   ```swift
   // 用户右滑照片
   photoService.markAsSeen(asset: asset)  // 标记已查看
   photoService.stagePendingDelete(asset: asset)
   // 从可见列表移除，但不实际删除
   visiblePhotos.remove(at: currentIndex)
   ```

2. **批量删除**
   ```swift
   // 用户点击"删除 N 张"按钮
   PHPhotoLibrary.shared().performChanges({
       PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
   })
   // 一次性删除所有暂存的 PHAsset
   ```

3. **失败恢复**
   ```swift
   // 如果删除失败，恢复暂存的照片到可见列表
   if !success {
       visiblePhotos.insert(contentsOf: restored, at: currentIndex)
   }
   ```

### 手势识别逻辑

- **水平优先**: 当水平移动距离 > 垂直移动距离时，判定为左右滑
  - 右滑超过阈值 → 执行删除动画
  - 左滑 → 回弹（不执行任何操作）
- **垂直导航**: 当垂直移动距离更大时
  - 上滑超过阈值 → 下一张
  - 下滑超过阈值 → 上一张（如果可用）

### 删除动画
- 向右上角飞出：`translate(x: +150%, y: -80%)`
- 同时旋转和缩放渐隐
- 触觉反馈：中等强度震动 + 成功提示音

## ⚠️ 注意事项

- 删除的照片会进入系统"最近删除"相册，30 天后永久删除
- 仅支持 iPhone 竖屏模式
- 批量删除按钮会触发系统权限确认（iOS 安全机制）
- 如果用户取消系统删除弹窗，照片会保留在待删除列表
- 已查看记录保存在 UserDefaults，卸载应用会清空记录
- "重新浏览"按钮会清空所有已查看记录，重新显示全部照片

## 🆚 与 Android 版本的 UX 一致性

本 iOS 版本完全匹配 Android 版本的交互设计：

| 功能 | Android | iOS (本版本) | 一致性 |
|------|---------|-------------|--------|
| 向上滑 | 下一张 + 标记已查看 | 下一张 + 标记已查看 | ✅ |
| 向下滑 | 上一张 | 上一张 | ✅ |
| 右滑 | 暂存删除 + 标记已查看 | 暂存删除 + 标记已查看 | ✅ |
| 左滑 | 弹回 | 弹回 | ✅ |
| 删除动画 | 飞向右上 | 飞向右上 | ✅ |
| 批量删除 | 一次性删除 | 一次性删除 | ✅ |
| 浏览记录 | 持久化已查看 | 持久化已查看 | ✅ |
| 重新浏览 | 清空记录 | 清空记录 | ✅ |

## 📝 License

本项目代码供学习和参考使用。

---

# Quick Delete (English)

A minimalist iOS photo cleanup app with intuitive swipe gestures.

## Features

- **Swipe UP** → Next photo (mark as seen)
- **Swipe DOWN** → Previous photo
- **Swipe RIGHT** → Stage for deletion + mark as seen (fling to upper-right)
- **Swipe LEFT** → Snap back (no action)
- **Batch Delete** → One-time delete with `删除 N 张` button
- **Remember Viewed** → Seen photos persist across app restarts
- **Review Again** → Clear seen history with `重新浏览` button
- Full-screen photo viewer with PHCachingImageManager optimization

## Tech Stack

- Swift 5.0 + SwiftUI
- PhotoKit for photo management
- iOS 17.0+ minimum deployment

## Run on Mac

1. Open `QuickDelete.xcodeproj` in Xcode 15+
2. Select iOS 17+ device or simulator
3. Press ⌘+R to build and run
4. Grant photo library permission
5. Test gestures and batch delete

For detailed Chinese documentation, see sections above.
