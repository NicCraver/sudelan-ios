import SwiftUI
import Photos

struct ContentView: View {
    @StateObject private var photoService = PhotoLibraryService()

    var body: some View {
        Group {
            switch photoService.authorizationStatus {
            case .notDetermined, .restricted, .denied:
                PermissionView(photoService: photoService)
            case .authorized, .limited:
                if photoService.isLoading {
                    LoadingView()
                } else {
                    MainTabView(photoService: photoService)
                }
            @unknown default:
                PermissionView(photoService: photoService)
            }
        }
        .onAppear {
            photoService.requestAuthorization()
        }
    }
}

struct MainTabView: View {
    @ObservedObject var photoService: PhotoLibraryService

    var body: some View {
        TabView(selection: Binding(
            get: { photoService.selectedTab },
            set: { photoService.selectTab($0) }
        )) {
            SwipeFeedView(photoService: photoService)
                .tabItem {
                    Label("刷删", systemImage: "hand.draw.fill")
                }
                .tag(AppTab.swipe)

            AlbumView(photoService: photoService)
                .tabItem {
                    Label("相册", systemImage: "photo.on.rectangle")
                }
                .tag(AppTab.album)

            RecycleBinView(photoService: photoService)
                .tabItem {
                    Label("回收站", systemImage: "trash")
                }
                .badge(photoService.recycleCount > 0 ? photoService.recycleCount : 0)
                .tag(AppTab.recycle)

            MeView(photoService: photoService)
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(AppTab.me)
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }
}

struct PermissionView: View {
    @ObservedObject var photoService: PhotoLibraryService

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.6))

            VStack(spacing: 12) {
                Text("需要访问您的照片")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text("点击下方按钮授权「速删」访问您的照片库")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: {
                if photoService.authorizationStatus == .notDetermined {
                    photoService.requestAuthorization()
                } else if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }) {
                Text(photoService.authorizationStatus == .notDetermined ? "授权访问" : "打开设置")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("加载中...")
                .foregroundColor(.white)
                .font(.title3)
        }
    }
}

#Preview {
    ContentView()
}
