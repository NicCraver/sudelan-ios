import Foundation
import Photos
import UIKit
import Combine

class PhotoLibraryService: NSObject, ObservableObject {
    @Published var photos: [PHAsset] = []
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var deletedCountToday: Int = 0
    @Published var pendingDeleteAssets: [PHAsset] = []
    @Published var hasUnseenPhotos: Bool = true
    
    private let imageManager = PHCachingImageManager()
    private var cachingAssets: [PHAsset] = []
    private let imageSize = CGSize(width: UIScreen.main.bounds.width * UIScreen.main.scale,
                                   height: UIScreen.main.bounds.height * UIScreen.main.scale)
    
    private let seenStoreKey = "seenPhotoIdentifiers"
    private var seenIdentifiers: Set<String> {
        get {
            let array = UserDefaults.standard.array(forKey: seenStoreKey) as? [String] ?? []
            return Set(array)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: seenStoreKey)
        }
    }
    
    override init() {
        super.init()
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        imageManager.allowsCachingHighQualityImages = false
        loadDeletedCountToday()
    }
    
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
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.includeHiddenAssets = false
        fetchOptions.includeAllBurstAssets = false
        
        let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let seenIds = seenIdentifiers
        
        var assets: [PHAsset] = []
        var totalCount = 0
        allPhotos.enumerateObjects { asset, _, _ in
            totalCount += 1
            if !seenIds.contains(asset.localIdentifier) {
                assets.append(asset)
            }
        }
        
        DispatchQueue.main.async {
            self.photos = assets
            self.hasUnseenPhotos = !assets.isEmpty || totalCount == 0
            if !assets.isEmpty {
                self.startCaching(for: 0)
            }
        }
    }
    
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
    
    func stopCaching() {
        if !cachingAssets.isEmpty {
            imageManager.stopCachingImages(
                for: cachingAssets,
                targetSize: imageSize,
                contentMode: .aspectFill,
                options: imageRequestOptions()
            )
            cachingAssets = []
        }
    }
    
    func loadImage(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let options = imageRequestOptions()
        
        imageManager.requestImage(
            for: asset,
            targetSize: imageSize,
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                return
            }
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
    
    func stagePendingDelete(asset: PHAsset) {
        if !pendingDeleteAssets.contains(asset) {
            pendingDeleteAssets.append(asset)
        }
    }
    
    func executeBatchDelete(completion: @escaping (Bool, Int) -> Void) {
        guard !pendingDeleteAssets.isEmpty else {
            completion(true, 0)
            return
        }
        
        let assetsToDelete = pendingDeleteAssets
        let deleteCount = assetsToDelete.count
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.pendingDeleteAssets.removeAll()
                    self?.incrementDeletedCount(by: deleteCount)
                    completion(true, deleteCount)
                } else {
                    completion(false, 0)
                }
            }
        }
    }
    
    func clearPendingDeletes() {
        pendingDeleteAssets.removeAll()
    }
    
    private func loadDeletedCountToday() {
        let defaults = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date())
        
        if let savedDate = defaults.object(forKey: "lastDeleteDate") as? Date,
           Calendar.current.isDate(savedDate, inSameDayAs: today) {
            deletedCountToday = defaults.integer(forKey: "deletedCountToday")
        } else {
            deletedCountToday = 0
            defaults.set(today, forKey: "lastDeleteDate")
            defaults.set(0, forKey: "deletedCountToday")
        }
    }
    
    private func incrementDeletedCount(by count: Int) {
        deletedCountToday += count
        let defaults = UserDefaults.standard
        defaults.set(deletedCountToday, forKey: "deletedCountToday")
    }
    
    func markAsSeen(asset: PHAsset) {
        var seen = seenIdentifiers
        seen.insert(asset.localIdentifier)
        seenIdentifiers = seen
    }
    
    func clearSeenStore() {
        seenIdentifiers = []
        loadPhotos()
    }
}
