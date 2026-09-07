import SwiftUI
import Photos

/// Gesture axis lock — mirrors Android PhotoScreen so diagonal up-swipes
/// navigate instead of accidentally deleting.
private enum AxisLock {
    case none
    case vertical
    case horizontalRight
    case horizontalLeft
}

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
    @State private var axisLock: AxisLock = .none

    /// ~14pt lock slop (matches Android 14dp).
    private let lockSlop: CGFloat = 14
    /// Strong cross-axis damp after lock (matches Android 0.08).
    private let crossAxisDamp: CGFloat = 0.08
    /// Prefer vertical when |dy| >= |dx| * verticalBias.
    private let verticalBias: CGFloat = 1.15
    /// Delete requires |offsetX| > |offsetY| * deleteAxisRatio (or Y≈0 from damp).
    private let deleteAxisRatio: CGFloat = 1.5
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
                    switch axisLock {
                    case .horizontalRight where offset.width > 30:
                        deleteIndicatorOverlay(geometry: geometry)
                    case .vertical where offset.height < -30:
                        nextIndicatorOverlay()
                    case .vertical where offset.height > 30 && canGoPrevious:
                        previousIndicatorOverlay()
                    case .none:
                        if abs(offset.width) > abs(offset.height) && offset.width > 30 {
                            deleteIndicatorOverlay(geometry: geometry)
                        } else if offset.height < -30 {
                            nextIndicatorOverlay()
                        } else if offset.height > 30 && canGoPrevious {
                            previousIndicatorOverlay()
                        }
                    default:
                        EmptyView()
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
                        let raw = gesture.translation
                        let absDx = abs(raw.width)
                        let absDy = abs(raw.height)
                        let travel = hypot(raw.width, raw.height)

                        // Decide axis once travel exceeds lock slop
                        if axisLock == .none {
                            if travel >= lockSlop || max(absDx, absDy) >= lockSlop {
                                if absDy >= absDx * verticalBias {
                                    axisLock = .vertical
                                } else if raw.width > 0 && absDx > absDy {
                                    axisLock = .horizontalRight
                                } else if raw.width < 0 {
                                    axisLock = .horizontalLeft
                                } else {
                                    // Prefer vertical on near-ties
                                    axisLock = .vertical
                                }
                            }
                        }

                        // Apply axis lock: 1:1 while unlocked; damp cross-axis after lock
                        var next: CGSize
                        switch axisLock {
                        case .none:
                            next = raw
                            if next.width < 0 { next.width *= 0.3 }
                        case .vertical:
                            // Strongly damp X; only Y drives next/prev; never delete
                            next = CGSize(width: raw.width * crossAxisDamp, height: raw.height)
                        case .horizontalRight:
                            // Strongly damp Y; only +X can delete
                            next = CGSize(width: raw.width, height: raw.height * crossAxisDamp)
                        case .horizontalLeft:
                            // Damp Y; soft left X; snap-back only (never delete)
                            next = CGSize(width: raw.width * 0.3, height: raw.height * crossAxisDamp)
                        }
                        offset = next

                        // Live tilt / scale hint only on delete axis (or unlocked rightward)
                        let showDeleteHint =
                            axisLock == .horizontalRight ||
                            (axisLock == .none && next.width > 0)
                        if showDeleteHint && next.width > 0 {
                            rotation = Double(min(next.width / 18, 28))
                            scale = 1 - min(next.width / 4000, 0.08)
                            opacity = 1 - Double(min(next.width / 1800, 0.18))
                        } else if next.width < 0 {
                            rotation = Double(max(next.width / 40, -8))
                            scale = 1
                            opacity = 1
                        } else {
                            rotation = 0
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

                    Text("回收站")
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
        let lock = axisLock
        axisLock = .none

        switch lock {
        case .horizontalRight:
            // Delete ONLY when locked HorizontalRight
            let passedDistance = offset.width > horizontalSwipeThreshold
            let passedFling = velocityX > flingVelocityThreshold && offset.width > 48
            let axisOk = absX > absY * deleteAxisRatio || absY < 12
            if (passedDistance || passedFling) && offset.width > 0 && axisOk {
                animateDelete(in: geometry, velocityX: velocityX, velocityY: velocityY)
            } else {
                snapBack()
            }

        case .vertical:
            // Next/prev ONLY when locked Vertical
            if offset.height < -verticalSwipeThreshold {
                animateVertical(exitY: -geometry.size.height * 1.15, velocityY: velocityY, action: onNext)
            } else if offset.height > verticalSwipeThreshold && canGoPrevious {
                animateVertical(exitY: geometry.size.height * 1.15, velocityY: velocityY, action: onPrevious)
            } else {
                snapBack()
            }

        case .horizontalLeft, .none:
            snapBack()
        }
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
