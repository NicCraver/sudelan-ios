import SwiftUI
import Photos

struct PhotoSwipeCard: View {
    let asset: PHAsset
    @ObservedObject var photoService: PhotoLibraryService
    let onDelete: () -> Void
    let onNext: () -> Void
    let onPrevious: () -> Void
    let canGoPrevious: Bool
    
    @State private var image: UIImage?
    @State private var offset: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var isDeleting: Bool = false
    
    private let horizontalSwipeThreshold: CGFloat = 120
    private let verticalSwipeThreshold: CGFloat = 80
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    Color.gray.opacity(0.3)
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
                
                if isDragging {
                    if abs(offset.width) > abs(offset.height) && abs(offset.width) > 30 {
                        if offset.width > 0 {
                            deleteIndicatorOverlay(geometry: geometry)
                        }
                    } else if offset.height < -30 {
                        nextIndicatorOverlay()
                    } else if offset.height > 30 && canGoPrevious {
                        previousIndicatorOverlay()
                    }
                }
            }
            .offset(x: offset.width, y: offset.height)
            .rotationEffect(.degrees(Double(offset.width / 30)))
            .scaleEffect(isDeleting ? 0.7 : 1.0)
            .opacity(isDeleting ? 0 : 1)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if !isDeleting {
                            isDragging = true
                            
                            if gesture.translation.width < 0 {
                                offset = CGSize(
                                    width: gesture.translation.width * 0.3,
                                    height: gesture.translation.height
                                )
                            } else {
                                offset = gesture.translation
                            }
                        }
                    }
                    .onEnded { gesture in
                        isDragging = false
                        handleSwipeEnd(gesture: gesture, in: geometry)
                    }
            )
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func deleteIndicatorOverlay(geometry: GeometryProxy) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                VStack(spacing: 12) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                    
                    Text("删除")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(40)
                .background(
                    Circle()
                        .fill(Color.red.opacity(min(offset.width / horizontalSwipeThreshold, 1.0) * 0.8))
                        .frame(width: 140, height: 140)
                )
                
                Spacer()
            }
            Spacer()
        }
    }
    
    private func nextIndicatorOverlay() -> some View {
        VStack {
            VStack(spacing: 12) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                
                Text("下一张")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(
                Circle()
                    .fill(Color.blue.opacity(min(abs(offset.height) / verticalSwipeThreshold, 1.0) * 0.8))
                    .frame(width: 140, height: 140)
            )
            
            Spacer()
        }
        .padding(.top, 100)
    }
    
    private func previousIndicatorOverlay() -> some View {
        VStack {
            Spacer()
            
            VStack(spacing: 12) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                
                Text("上一张")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(
                Circle()
                    .fill(Color.green.opacity(min(offset.height / verticalSwipeThreshold, 1.0) * 0.8))
                    .frame(width: 140, height: 140)
            )
        }
        .padding(.bottom, 100)
    }
    
    private func handleSwipeEnd(gesture: DragGesture.Value, in geometry: GeometryProxy) {
        let horizontalDistance = abs(gesture.translation.width)
        let verticalDistance = abs(gesture.translation.height)
        
        if horizontalDistance > verticalDistance {
            if gesture.translation.width > horizontalSwipeThreshold {
                animateDelete(in: geometry)
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    offset = .zero
                }
            }
        } else {
            if gesture.translation.height < -verticalSwipeThreshold {
                animateNext()
            } else if gesture.translation.height > verticalSwipeThreshold && canGoPrevious {
                animatePrevious()
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    offset = .zero
                }
            }
        }
    }
    
    private func animateDelete(in geometry: GeometryProxy) {
        isDeleting = true
        
        withAnimation(.easeInOut(duration: DeleteAnimation.duration)) {
            offset = CGSize(
                width: DeleteAnimation.exitOffset,
                height: DeleteAnimation.exitOffsetY
            )
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + DeleteAnimation.duration) {
            onDelete()
        }
    }
    
    private func animateNext() {
        withAnimation(.easeInOut(duration: 0.25)) {
            offset = CGSize(width: 0, height: -1000)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onNext()
        }
    }
    
    private func animatePrevious() {
        withAnimation(.easeInOut(duration: 0.25)) {
            offset = CGSize(width: 0, height: 1000)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onPrevious()
        }
    }
    
    private func loadImage() {
        photoService.loadImage(for: asset) { loadedImage in
            self.image = loadedImage
        }
    }
}
