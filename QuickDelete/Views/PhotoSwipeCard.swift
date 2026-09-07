import SwiftUI
import Photos

struct PhotoSwipeCard: View {
    let asset: PHAsset
    @ObservedObject var photoService: PhotoLibraryService
    let onDelete: () -> Void
    let onNext: () -> Void
    let onPrevious: () -> Void
    let canGoPrevious: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var image: UIImage?
    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1
    @State private var opacity: Double = 1
    @State private var isDragging: Bool = false
    @State private var isBusy: Bool = false

    private let horizontalSwipeThreshold: CGFloat = 120
    private let verticalSwipeThreshold: CGFloat = 80
    private let flingVelocityThreshold: CGFloat = 1200

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
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .opacity(opacity)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        guard !isBusy else { return }
                        // Interrupt snap-back / soft anims by taking over from current values
                        isDragging = true
                        var next = gesture.translation
                        // Soft resistance on left (no delete)
                        if next.width < 0 {
                            next.width *= 0.3
                        }
                        offset = next
                        // Live tilt from drag; gentler on left
                        if next.width > 0 {
                            rotation = Double(min(next.width / 18, 28))
                            scale = 1 - min(next.width / 4000, 0.08)
                            opacity = 1 - Double(min(next.width / 1800, 0.18))
                        } else {
                            rotation = Double(max(next.width / 40, -8))
                            scale = 1
                            opacity = 1
                        }
                    }
                    .onEnded { gesture in
                        isDragging = false
                        guard !isBusy else { return }
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
        let translation = gesture.translation
        // predictedEnd - translation approximates release velocity projection (points)
        let predicted = gesture.predictedEndTranslation
        let velocityX = predicted.width - translation.width
        let velocityY = predicted.height - translation.height

        let absX = abs(offset.width)
        let absY = abs(offset.height)
        let towardUpperRight =
            velocityX > flingVelocityThreshold &&
            velocityY < flingVelocityThreshold * 0.45 &&
            offset.width > 48

        if (offset.width > horizontalSwipeThreshold && absX > absY) || towardUpperRight {
            animateDelete(in: geometry, velocityX: velocityX, velocityY: velocityY)
            return
        }

        if offset.height < -verticalSwipeThreshold && absY > absX {
            animateVertical(exitY: -geometry.size.height * 1.15, velocityY: velocityY, action: onNext)
            return
        }

        if offset.height > verticalSwipeThreshold && absY > absX && canGoPrevious {
            animateVertical(exitY: geometry.size.height * 1.15, velocityY: velocityY, action: onPrevious)
            return
        }

        snapBack()
    }

    private func snapBack() {
        // Critically damped — no bounce; interruptible by next drag
        withAnimation(.spring(response: 0.32, dampingFraction: 1.0, blendDuration: 0)) {
            offset = .zero
            rotation = 0
            scale = 1
            opacity = 1
        }
    }

    private func animateDelete(in geometry: GeometryProxy, velocityX: CGFloat, velocityY: CGFloat) {
        isBusy = true
        DeleteFeedback.trigger()

        if reduceMotion {
            opacity = 0
            onDelete()
            resetTransforms()
            isBusy = false
            return
        }

        let projectedX = max(offset.width + velocityX * 0.55, geometry.size.width * 1.25)
        let projectedY = min(offset.height + velocityY * 0.4, -geometry.size.height * 0.45)
        let boost = min(max(Double(velocityX) / 3200.0 * 10.0, 0), 10)
        let throwRotation = min(max(rotation + boost, 0), 32)

        withAnimation(.spring(response: 0.45, dampingFraction: 0.86, blendDuration: 0)) {
            offset = CGSize(width: projectedX, height: projectedY)
            rotation = throwRotation
            scale = 0.90
            opacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            onDelete()
            resetTransforms()
            isBusy = false
        }
    }

    private func animateVertical(exitY: CGFloat, velocityY: CGFloat, action: @escaping () -> Void) {
        isBusy = true

        if reduceMotion {
            action()
            resetTransforms()
            isBusy = false
            return
        }

        let projected = velocityY < 0
            ? min(offset.height + velocityY * 0.2, exitY)
            : max(offset.height + velocityY * 0.2, exitY)
        let speed = abs(velocityY)
        let duration = min(0.18, max(0.12, 0.18 - Double(speed) / 20000))

        withAnimation(.easeOut(duration: duration)) {
            offset = CGSize(width: 0, height: projected)
            opacity = 0.85
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            action()
            resetTransforms()
            isBusy = false
        }
    }

    private func resetTransforms() {
        offset = .zero
        rotation = 0
        scale = 1
        opacity = 1
    }

    private func loadImage() {
        photoService.loadImage(for: asset) { loadedImage in
            self.image = loadedImage
        }
    }
}
