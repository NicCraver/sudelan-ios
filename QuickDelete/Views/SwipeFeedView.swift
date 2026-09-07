import SwiftUI
import Photos

struct SwipeFeedView: View {
    @ObservedObject var photoService: PhotoLibraryService
    @State private var showHUD: Bool = false
    @State private var hudMessage: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if photoService.photos.isEmpty {
                EmptyFeedView(
                    allPhotosSeen: photoService.allPhotosSeen,
                    libraryEmpty: photoService.libraryCount == 0,
                    onReviewAgain: { photoService.clearSeenStore() }
                )
            } else if photoService.currentIndex < photoService.photos.count {
                PhotoSwipeCard(
                    asset: photoService.photos[photoService.currentIndex],
                    photoService: photoService,
                    onDelete: handleSoftDelete,
                    onNext: handleNext,
                    onPrevious: handlePrevious,
                    canGoPrevious: photoService.currentIndex > 0
                )
                .id(photoService.photos[photoService.currentIndex].localIdentifier)
            }

            VStack {
                HStack {
                    Spacer()
                    StatusHUD(
                        recycleCount: photoService.recycleCount,
                        softDeletedToday: photoService.softDeletedToday,
                        deletedToday: photoService.deletedToday
                    )
                    .padding(.top, 56)
                    .padding(.trailing, 16)
                }
                Spacer()
            }

            if showHUD {
                HUDView(message: hudMessage)
                    .transition(.opacity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if !photoService.photos.isEmpty {
                photoService.startCaching(for: photoService.currentIndex)
            }
        }
    }

    private func handleSoftDelete() {
        guard photoService.currentIndex < photoService.photos.count else { return }
        DeleteFeedback.trigger()
        photoService.softDeleteCurrent()
        showMessage("已移入回收站 \(photoService.recycleCount)")
    }

    private func handleNext() {
        guard photoService.currentIndex < photoService.photos.count else { return }
        DeleteFeedback.triggerLight()
        let wasLast = photoService.currentIndex == photoService.photos.count - 1
        photoService.moveToNext()
        if wasLast {
            showMessage("已到最后")
        }
    }

    private func handlePrevious() {
        guard photoService.currentIndex > 0 else { return }
        DeleteFeedback.triggerLight()
        photoService.moveToPrevious()
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
    let recycleCount: Int
    let softDeletedToday: Int
    let deletedToday: Int

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if recycleCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                    Text("回收站 \(recycleCount)")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.2))
                        .background(Capsule().fill(.ultraThinMaterial))
                )
            }

            if softDeletedToday > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 12))
                    Text("今日软删 \(softDeletedToday)")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .background(Capsule().fill(.ultraThinMaterial))
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
                        .background(Capsule().fill(.ultraThinMaterial))
                )
            }
        }
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
                    .background(Capsule().fill(.ultraThinMaterial))
            )
    }
}

struct EmptyFeedView: View {
    let allPhotosSeen: Bool
    let libraryEmpty: Bool
    let onReviewAgain: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: libraryEmpty ? "photo.badge.checkmark" : "eye.slash")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.6))

            VStack(spacing: 12) {
                Text(libraryEmpty ? "照片库为空" : (allPhotosSeen ? "已全部浏览完" : "暂无照片"))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text(libraryEmpty
                     ? "您的照片库中没有照片"
                     : (allPhotosSeen ? "所有照片都已查看过，可在「我的」重新浏览" : "没有可刷删的照片"))
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if allPhotosSeen && !libraryEmpty {
                Button(action: onReviewAgain) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("重新浏览")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}
