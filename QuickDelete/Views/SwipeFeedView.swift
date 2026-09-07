import SwiftUI
import Photos

struct SwipeFeedView: View {
    @ObservedObject var photoService: PhotoLibraryService
    @State private var currentIndex: Int = 0
    @State private var showHUD: Bool = false
    @State private var hudMessage: String = ""
    @State private var visiblePhotos: [PHAsset] = []
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if currentIndex < visiblePhotos.count {
                PhotoSwipeCard(
                    asset: visiblePhotos[currentIndex],
                    photoService: photoService,
                    onDelete: handleDelete,
                    onNext: handleNext,
                    onPrevious: handlePrevious,
                    canGoPrevious: currentIndex > 0
                )
                .id(currentIndex)
            } else {
                AllDoneView()
            }
            
            VStack {
                HStack {
                    Spacer()
                    StatusHUD(
                        pendingCount: photoService.pendingDeleteAssets.count,
                        deletedToday: photoService.deletedCountToday
                    )
                    .padding(.top, 60)
                    .padding(.trailing, 20)
                }
                Spacer()
                
                if photoService.pendingDeleteAssets.count > 0 {
                    BatchDeleteButton(
                        count: photoService.pendingDeleteAssets.count,
                        onDelete: executeBatchDelete
                    )
                    .padding(.bottom, 50)
                }
            }
            
            if showHUD {
                HUDView(message: hudMessage)
                    .transition(.opacity)
            }
        }
        .statusBar(hidden: true)
        .onAppear {
            visiblePhotos = photoService.photos
            photoService.startCaching(for: currentIndex)
        }
    }
    
    private func handleDelete() {
        guard currentIndex < visiblePhotos.count else { return }
        
        DeleteFeedback.trigger()
        
        let asset = visiblePhotos[currentIndex]
        photoService.markAsSeen(asset: asset)
        photoService.stagePendingDelete(asset: asset)
        
        visiblePhotos.remove(at: currentIndex)
        
        if currentIndex < visiblePhotos.count {
            photoService.startCaching(for: currentIndex)
        }
        
        showMessage("待删 \(photoService.pendingDeleteAssets.count)")
    }
    
    private func handleNext() {
        guard currentIndex < visiblePhotos.count else { return }
        
        let asset = visiblePhotos[currentIndex]
        photoService.markAsSeen(asset: asset)
        
        guard currentIndex < visiblePhotos.count - 1 else {
            showMessage("已到最后")
            return
        }
        
        DeleteFeedback.triggerLight()
        currentIndex += 1
        
        if currentIndex < visiblePhotos.count {
            photoService.startCaching(for: currentIndex)
        }
    }
    
    private func handlePrevious() {
        guard currentIndex > 0 else { return }
        
        DeleteFeedback.triggerLight()
        currentIndex -= 1
        photoService.startCaching(for: currentIndex)
    }
    
    private func executeBatchDelete() {
        photoService.executeBatchDelete { success, count in
            if success {
                showMessage("已删除 \(count) 张")
                DeleteFeedback.triggerSuccess()
            } else {
                showMessage("删除失败")
                restorePendingPhotos()
            }
        }
    }
    
    private func restorePendingPhotos() {
        let restored = photoService.pendingDeleteAssets
        visiblePhotos.insert(contentsOf: restored, at: currentIndex)
        photoService.clearPendingDeletes()
    }
    
    private func showMessage(_ message: String) {
        hudMessage = message
        withAnimation(.easeInOut(duration: 0.2)) {
            showHUD = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showHUD = false
            }
        }
    }
}

struct StatusHUD: View {
    let pendingCount: Int
    let deletedToday: Int
    
    var body: some View {
        VStack(spacing: 8) {
            if pendingCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text("待删 \(pendingCount)")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.2))
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                        )
                )
            }
            
            if deletedToday > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 12))
                    Text("今日已删 \(deletedToday)")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                        )
                )
            }
        }
    }
}

struct BatchDeleteButton: View {
    let count: Int
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onDelete) {
            HStack(spacing: 10) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("删除 \(count) 张")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 18)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.red, Color.red.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.red.opacity(0.5), radius: 12, y: 6)
            )
        }
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.32, dampingFraction: 1.0), value: count)
    }
}

struct HUDView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.7))
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
            )
    }
}

struct AllDoneView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            VStack(spacing: 12) {
                Text("全部处理完成")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("您已经浏览完所有照片")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}
