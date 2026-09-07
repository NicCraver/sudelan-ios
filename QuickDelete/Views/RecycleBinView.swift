import SwiftUI
import Photos

struct RecycleBinView: View {
    @ObservedObject var photoService: PhotoLibraryService
    @State private var showEmptyConfirm = false
    @State private var isEmptying = false
    @State private var toast: String?

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if photoService.recyclePhotos.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "trash")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.5))
                        Text("回收站为空")
                            .foregroundColor(.white.opacity(0.7))
                        Text("右滑删除的照片会先进入这里")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.45))
                    }
                } else {
                    VStack(spacing: 0) {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(photoService.recyclePhotos, id: \.localIdentifier) { asset in
                                    RecycleCell(asset: asset, photoService: photoService) {
                                        photoService.restoreFromRecycle(asset: asset)
                                        DeleteFeedback.triggerLight()
                                        showToast("已恢复")
                                    }
                                }
                            }
                            .padding(.bottom, 12)
                        }

                        VStack(spacing: 10) {
                            Text("约可释放 \(photoService.formatBytes(photoService.recycleBinBytes()))")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.6))

                            HStack(spacing: 12) {
                                Button {
                                    photoService.restoreAllFromRecycle()
                                    DeleteFeedback.triggerLight()
                                    showToast("已全部恢复")
                                } label: {
                                    Text("全部恢复")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Capsule().fill(Color.white.opacity(0.15)))
                                        .foregroundColor(.white)
                                }

                                Button {
                                    showEmptyConfirm = true
                                } label: {
                                    Text(isEmptying ? "删除中…" : "清空回收站")
                                        .fontWeight(.bold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            Capsule().fill(
                                                LinearGradient(
                                                    colors: [Color.red, Color.red.opacity(0.8)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                        )
                                        .foregroundColor(.white)
                                }
                                .disabled(isEmptying)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        }
                        .padding(.top, 8)
                        .background(Color.black.opacity(0.9))
                    }
                }

                if let toast {
                    HUDView(message: toast)
                }
            }
            .navigationTitle("回收站")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .confirmationDialog(
                "清空回收站将永久删除 \(photoService.recycleCount) 张照片（系统会再次确认）",
                isPresented: $showEmptyConfirm,
                titleVisibility: .visible
            ) {
                Button("清空并删除", role: .destructive) {
                    emptyBin()
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    private func emptyBin() {
        isEmptying = true
        photoService.emptyRecycleBin { success, count in
            isEmptying = false
            if success {
                DeleteFeedback.triggerSuccess()
                showToast("已删除 \(count) 张")
            } else {
                showToast("已取消，仍保留在回收站")
            }
        }
    }

    private func showToast(_ message: String) {
        withAnimation { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { toast = nil }
        }
    }
}

struct RecycleCell: View {
    let asset: PHAsset
    @ObservedObject var photoService: PhotoLibraryService
    let onRestore: () -> Void

    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.gray.opacity(0.3)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipped()

            Button(action: onRestore) {
                Text("恢复")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.blue.opacity(0.85)))
            }
            .padding(6)
        }
        .onAppear {
            photoService.loadThumbnail(for: asset) { img in
                image = img
            }
        }
    }
}
