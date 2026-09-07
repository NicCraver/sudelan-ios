import SwiftUI
import Photos

struct AlbumView: View {
    @ObservedObject var photoService: PhotoLibraryService
    @State private var selectMode = false
    @State private var selectedIds: Set<String> = []

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if photoService.albumPhotos.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.5))
                        Text("相册为空")
                            .foregroundColor(.white.opacity(0.7))
                        if photoService.recycleCount > 0 {
                            Text("部分照片在回收站中")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(photoService.albumPhotos, id: \.localIdentifier) { asset in
                                AlbumCell(
                                    asset: asset,
                                    photoService: photoService,
                                    selected: selectedIds.contains(asset.localIdentifier),
                                    selectMode: selectMode
                                ) {
                                    if selectMode {
                                        toggleSelection(asset)
                                    } else {
                                        photoService.jumpToPhotoFromAlbum(asset: asset)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
            .navigationTitle("相册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if selectMode {
                        Button("取消") {
                            selectMode = false
                            selectedIds.removeAll()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        if selectMode && !selectedIds.isEmpty {
                            Button {
                                softDeleteSelection()
                            } label: {
                                Text("移入回收站 (\(selectedIds.count))")
                                    .foregroundColor(.orange)
                            }
                        }
                        Button(selectMode ? "完成" : "选择") {
                            selectMode.toggle()
                            if !selectMode { selectedIds.removeAll() }
                        }
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func toggleSelection(_ asset: PHAsset) {
        let id = asset.localIdentifier
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    private func softDeleteSelection() {
        let assets = photoService.albumPhotos.filter { selectedIds.contains($0.localIdentifier) }
        photoService.softDeletePhotos(assets)
        selectedIds.removeAll()
        selectMode = false
        DeleteFeedback.trigger()
    }
}

struct AlbumCell: View {
    let asset: PHAsset
    @ObservedObject var photoService: PhotoLibraryService
    let selected: Bool
    let selectMode: Bool
    let onTap: () -> Void

    @State private var image: UIImage?

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipped()

                if selectMode {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(selected ? .orange : .white)
                        .padding(6)
                        .shadow(radius: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            photoService.loadThumbnail(for: asset) { img in
                image = img
            }
        }
    }
}
