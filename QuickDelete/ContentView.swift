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
                if photoService.photos.isEmpty {
                    EmptyStateView(
                        hasUnseenPhotos: photoService.hasUnseenPhotos,
                        onReviewAgain: {
                            photoService.clearSeenStore()
                        }
                    )
                } else {
                    SwipeFeedView(photoService: photoService)
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
                } else {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
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

struct EmptyStateView: View {
    let hasUnseenPhotos: Bool
    let onReviewAgain: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: hasUnseenPhotos ? "photo.badge.checkmark" : "eye.slash")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.6))
            
            VStack(spacing: 12) {
                Text(hasUnseenPhotos ? "照片库为空" : "已全部浏览完")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(hasUnseenPhotos ? "您的照片库中没有照片" : "所有照片都已查看过")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            if !hasUnseenPhotos {
                Button(action: onReviewAgain) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                        Text("重新浏览")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.blue.opacity(0.4), radius: 10, y: 5)
                    )
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

#Preview {
    ContentView()
}
