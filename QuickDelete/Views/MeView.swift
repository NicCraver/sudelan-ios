import SwiftUI

struct MeView: View {
    @ObservedObject var photoService: PhotoLibraryService
    @State private var showRebrowseConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        header

                        statsGrid

                        rebrowseCard

                        aboutCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .confirmationDialog(
                "清空已浏览记录，重新从最新照片开始刷删？",
                isPresented: $showRebrowseConfirm,
                titleVisibility: .visible
            ) {
                Button("重新浏览", role: .destructive) {
                    photoService.clearSeenStore()
                    photoService.selectTab(.swipe)
                    DeleteFeedback.triggerSuccess()
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text("速删")
                .font(.title.bold())
                .foregroundColor(.white)
            Text("v0.2 · 与 Android 对齐")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "今日软删", value: "\(photoService.softDeletedToday)", icon: "arrow.uturn.backward", color: .orange)
            StatCard(title: "累计软删", value: "\(photoService.softDeletedTotal)", icon: "tray.full", color: .orange)
            StatCard(title: "今日已删", value: "\(photoService.deletedToday)", icon: "trash.fill", color: .red)
            StatCard(title: "累计已删", value: "\(photoService.deletedTotal)", icon: "checkmark.circle", color: .green)
            StatCard(title: "约释放空间", value: photoService.formatBytes(photoService.bytesFreed), icon: "internaldrive", color: .blue)
            StatCard(title: "回收站", value: "\(photoService.recycleCount)", icon: "archivebox", color: .purple)
            StatCard(title: "相册照片", value: "\(photoService.albumPhotos.count)", icon: "photo", color: .cyan)
            StatCard(title: "待刷删", value: "\(photoService.photos.count)", icon: "hand.draw", color: .mint)
        }
    }

    private var rebrowseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("浏览进度")
                .font(.headline)
                .foregroundColor(.white)

            Text("向上滑或软删过的照片会记住进度。点下方可清空已浏览记录。")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.6))

            Button {
                showRebrowseConfirm = true
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("重新浏览")
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
        )
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("手势")
                .font(.headline)
                .foregroundColor(.white)
            Text("上滑 → 下一张　下滑 → 上一张　右滑抛出 → 进回收站")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.6))
            Text("轴锁定已冻结：对角上滑不会误删。清空回收站才真正调用系统批量删除。")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.45))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
        )
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.55))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.08))
        )
    }
}
