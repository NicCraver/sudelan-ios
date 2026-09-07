import Foundation
import Photos
import UIKit
import Combine

enum AppTab: Hashable {
    case swipe
    case album
    case recycle
    case me
}

/// Photo library + soft-delete recycle bin + seen/stats — aligned with Android PhotoViewModel v0.2.
class PhotoLibraryService: NSObject, ObservableObject {
    /// Swipe feed: album minus seen (unless jumped from album).
    @Published var photos: [PHAsset] = []
    /// Full album (library minus recycle bin), newest first.
    @Published var albumPhotos: [PHAsset] = []
    /// Soft-deleted items still present in the photo library.
    @Published var recyclePhotos: [PHAsset] = []

    @Published var currentIndex: Int = 0
    @Published var selectedTab: AppTab = .swipe
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var isLoading: Bool = false
    @Published var allPhotosSeen: Bool = false
    @Published var libraryCount: Int = 0

    @Published var deletedToday: Int = 0
    @Published var deletedTotal: Int = 0
    @Published var softDeletedToday: Int = 0
    @Published var softDeletedTotal: Int = 0
    @Published var bytesFreed: Int64 = 0

    var recycleCount: Int { recyclePhotos.count }

    private let imageManager = PHCachingImageManager()
    private var cachingAssets: [PHAsset] = []
    private let imageSize = CGSize(
        width: UIScreen.main.bounds.width * UIScreen.main.scale,
        height: UIScreen.main.bounds.height * UIScreen.main.scale
    )
    private let thumbSize = CGSize(width: 200, height: 200)

    // MARK: - Persistence keys

    private let seenStoreKey = "seenPhotoIdentifiers"
    private let recycleStoreKey = "recycleBinIdentifiers"
    private let statsDayKey = "statsDayKey"
    private let deletedTodayKey = "deletedCountToday"
    private let deletedTotalKey = "deletedCountTotal"
    private let softTodayKey = "softDeletedToday"
    private let softTotalKey = "softDeletedTotal"
    private let bytesFreedKey = "bytesFreed"

    private var seenIdentifiers: Set<String> {
        get {
            Set(UserDefaults.standard.array(forKey: seenStoreKey) as? [String] ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: seenStoreKey)
        }
    }

    private var recycleIdentifiers: Set<String> {
        get {
            Set(UserDefaults.standard.array(forKey: recycleStoreKey) as? [String] ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: recycleStoreKey)
        }
    }

    override init() {
        super.init()
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        imageManager.allowsCachingHighQualityImages = false
        refreshStatsFromDefaults()
    }

    // MARK: - Auth & load

    func requestAuthorization() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                if status == .authorized || status == .limited {
                    self?.loadPhotos()
                }
            }
        }
    }

    func loadPhotos() {
        isLoading = true
        refreshStatsFromDefaults()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.includeHiddenAssets = false
            fetchOptions.includeAllBurstAssets = false

            let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            let seenIds = self.seenIdentifiers
            var binIds = self.recycleIdentifiers

            var library: [PHAsset] = []
            allPhotos.enumerateObjects { asset, _, _ in
                library.append(asset)
            }

            let liveIds = Set(library.map(\.localIdentifier))
            let stale = binIds.subtracting(liveIds)
            if !stale.isEmpty {
                binIds.subtract(stale)
                self.recycleIdentifiers = binIds
            }

            let album = library.filter { !binIds.contains($0.localIdentifier) }
            let recycle = library.filter { binIds.contains($0.localIdentifier) }
            let feed = album.filter { !seenIds.contains($0.localIdentifier) }
            let allSeen = !album.isEmpty && feed.isEmpty

            DispatchQueue.main.async {
                self.libraryCount = library.count
                self.albumPhotos = album
                self.recyclePhotos = recycle
                self.photos = feed
                self.allPhotosSeen = allSeen
                self.currentIndex = 0
                self.isLoading = false
                if !feed.isEmpty {
                    self.startCaching(for: 0)
                }
            }
        }
    }

    func selectTab(_ tab: AppTab) {
        selectedTab = tab
    }

    // MARK: - Caching & images

    func startCaching(for index: Int) {
        guard index >= 0 && index < photos.count else { return }
        let startIndex = max(0, index - 1)
        let endIndex = min(photos.count - 1, index + 3)
        let assetsToCache = Array(photos[startIndex...endIndex])
        imageManager.startCachingImages(
            for: assetsToCache,
            targetSize: imageSize,
            contentMode: .aspectFill,
            options: imageRequestOptions()
        )
        cachingAssets = assetsToCache
    }

    func loadImage(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        imageManager.requestImage(
            for: asset,
            targetSize: imageSize,
            contentMode: .aspectFill,
            options: imageRequestOptions()
        ) { image, info in
            if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                return
            }
            completion(image)
        }
    }

    func loadThumbnail(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        imageManager.requestImage(
            for: asset,
            targetSize: thumbSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            completion(image)
        }
    }

    private func imageRequestOptions() -> PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        return options
    }

    // MARK: - Navigation / seen

    func markAsSeen(asset: PHAsset) {
        var seen = seenIdentifiers
        seen.insert(asset.localIdentifier)
        seenIdentifiers = seen
    }

    func moveToNext() {
        guard !photos.isEmpty, currentIndex < photos.count else { return }
        markAsSeen(asset: photos[currentIndex])
        if currentIndex < photos.count - 1 {
            currentIndex += 1
            startCaching(for: currentIndex)
        } else if albumPhotos.isEmpty == false && photos.allSatisfy({ seenIdentifiers.contains($0.localIdentifier) }) {
            // last item marked; feed may still show it until reload — keep index
        }
    }

    func moveToPrevious() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        startCaching(for: currentIndex)
    }

    func clearSeenStore() {
        seenIdentifiers = []
        allPhotosSeen = false
        loadPhotos()
    }

    // MARK: - Soft delete / recycle

    /// Soft-delete into in-app recycle bin (UserDefaults IDs). No PHPhotoLibrary delete.
    func softDeleteCurrent() {
        guard currentIndex >= 0, currentIndex < photos.count else { return }
        softDeletePhotos([photos[currentIndex]])
    }

    func softDeletePhotos(_ assets: [PHAsset]) {
        guard !assets.isEmpty else { return }
        let ids = Set(assets.map(\.localIdentifier))
        var bin = recycleIdentifiers
        bin.formUnion(ids)
        recycleIdentifiers = bin

        for asset in assets {
            markAsSeen(asset: asset)
        }
        recordSoftDelete(count: assets.count)

        photos.removeAll { ids.contains($0.localIdentifier) }
        albumPhotos.removeAll { ids.contains($0.localIdentifier) }
        for asset in assets.reversed() {
            if !recyclePhotos.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
                recyclePhotos.insert(asset, at: 0)
            }
        }

        if currentIndex >= photos.count && currentIndex > 0 {
            currentIndex = photos.count - 1
        }
        if photos.isEmpty {
            currentIndex = 0
            if !albumPhotos.isEmpty {
                allPhotosSeen = true
            }
        } else {
            startCaching(for: currentIndex)
        }
    }

    func restoreFromRecycle(asset: PHAsset) {
        var bin = recycleIdentifiers
        bin.remove(asset.localIdentifier)
        recycleIdentifiers = bin
        recyclePhotos.removeAll { $0.localIdentifier == asset.localIdentifier }

        let date = asset.creationDate ?? .distantPast
        let insertAt = albumPhotos.firstIndex { ($0.creationDate ?? .distantPast) < date } ?? albumPhotos.count
        if !albumPhotos.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
            albumPhotos.insert(asset, at: insertAt)
        }
        if !photos.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
            let feedAt = photos.firstIndex { ($0.creationDate ?? .distantPast) < date } ?? photos.count
            photos.insert(asset, at: feedAt)
        }
        allPhotosSeen = false
    }

    func restoreAllFromRecycle() {
        for asset in recyclePhotos {
            restoreFromRecycle(asset: asset)
        }
    }

    /// Empty recycle bin: ONE PHPhotoLibrary.performChanges batch delete.
    func emptyRecycleBin(completion: @escaping (Bool, Int) -> Void) {
        guard !recyclePhotos.isEmpty else {
            completion(true, 0)
            return
        }
        let assetsToDelete = recyclePhotos
        let count = assetsToDelete.count
        let bytes = assetsToDelete.reduce(Int64(0)) { partial, asset in
            // PHAsset has no reliable byte size without resources; use approximate via resources when cheap
            partial + approximateByteSize(for: asset)
        }

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
        }) { [weak self] success, _ in
            DispatchQueue.main.async {
                guard let self else {
                    completion(false, 0)
                    return
                }
                if success {
                    self.recordPermanentDelete(count: count, bytes: bytes)
                    self.recycleIdentifiers = []
                    self.recyclePhotos = []
                    if self.photos.isEmpty && !self.albumPhotos.isEmpty {
                        self.allPhotosSeen = true
                    }
                    completion(true, count)
                } else {
                    // Cancel: leave bin untouched
                    completion(false, 0)
                }
            }
        }
    }

    private func approximateByteSize(for asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        if let resource = resources.first,
           let size = resource.value(forKey: "fileSize") as? Int64 {
            return size
        }
        // Fallback rough estimate by pixel area
        return Int64(asset.pixelWidth * asset.pixelHeight / 4)
    }

    /// Album tap: open 刷删 at that photo (full album stream, not seen-filtered).
    func jumpToPhotoFromAlbum(asset: PHAsset) {
        guard let index = albumPhotos.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) else {
            return
        }
        photos = albumPhotos
        currentIndex = index
        allPhotosSeen = false
        selectedTab = .swipe
        startCaching(for: currentIndex)
    }

    // MARK: - Stats

    private func dayKey() -> String {
        let cal = Calendar.current
        let today = Date()
        return "\(cal.component(.year, from: today))-\(cal.ordinality(of: .day, in: .year, for: today) ?? 0)"
    }

    private func ensureDayRollover() {
        let today = dayKey()
        let defaults = UserDefaults.standard
        if defaults.string(forKey: statsDayKey) != today {
            defaults.set(today, forKey: statsDayKey)
            defaults.set(0, forKey: deletedTodayKey)
            defaults.set(0, forKey: softTodayKey)
        }
    }

    private func refreshStatsFromDefaults() {
        ensureDayRollover()
        let defaults = UserDefaults.standard
        deletedToday = defaults.integer(forKey: deletedTodayKey)
        deletedTotal = defaults.integer(forKey: deletedTotalKey)
        softDeletedToday = defaults.integer(forKey: softTodayKey)
        softDeletedTotal = defaults.integer(forKey: softTotalKey)
        bytesFreed = Int64(defaults.integer(forKey: bytesFreedKey))
        // Prefer Int64 storage
        if defaults.object(forKey: bytesFreedKey) != nil {
            bytesFreed = defaults.object(forKey: bytesFreedKey) as? Int64
                ?? Int64(defaults.integer(forKey: bytesFreedKey))
        }
    }

    private func recordSoftDelete(count: Int) {
        guard count > 0 else { return }
        ensureDayRollover()
        let defaults = UserDefaults.standard
        softDeletedToday = defaults.integer(forKey: softTodayKey) + count
        softDeletedTotal = defaults.integer(forKey: softTotalKey) + count
        defaults.set(softDeletedToday, forKey: softTodayKey)
        defaults.set(softDeletedTotal, forKey: softTotalKey)
    }

    private func recordPermanentDelete(count: Int, bytes: Int64) {
        guard count > 0 else { return }
        ensureDayRollover()
        let defaults = UserDefaults.standard
        deletedToday = defaults.integer(forKey: deletedTodayKey) + count
        deletedTotal = defaults.integer(forKey: deletedTotalKey) + count
        bytesFreed = (defaults.object(forKey: bytesFreedKey) as? Int64
            ?? Int64(defaults.integer(forKey: bytesFreedKey))) + max(0, bytes)
        defaults.set(deletedToday, forKey: deletedTodayKey)
        defaults.set(deletedTotal, forKey: deletedTotalKey)
        defaults.set(bytesFreed, forKey: bytesFreedKey)
    }

    func formatBytes(_ bytes: Int64) -> String {
        if bytes <= 0 { return "0 B" }
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        if kb >= 1 { return String(format: "%.0f KB", kb) }
        return "\(bytes) B"
    }

    func recycleBinBytes() -> Int64 {
        recyclePhotos.reduce(Int64(0)) { $0 + approximateByteSize(for: $1) }
    }
}
