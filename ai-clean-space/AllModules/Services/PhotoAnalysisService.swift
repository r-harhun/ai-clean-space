import Foundation
import Photos
import UIKit
import Vision
import CryptoKit
import CoreImage

@MainActor
final class PhotoAnalysisService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isAnalyzing = false
    @Published var analysisProgress: Double = 0.0
    @Published var duplicateGroups: [PhotoGroupModel] = []
    @Published var similarGroups: [PhotoGroupModel] = []
    
    // MARK: - Private Properties
    private let imageManager = PHImageManager.default()
    private var analysisTask: Task<Void, Never>?
    
    // MARK: - Public Methods
    
    /// Анализирует фотографии для поиска дубликатов
    func findDuplicatePhotos() async {
        guard !isAnalyzing else { return }
        
        isAnalyzing = true
        analysisProgress = 0.0
        duplicateGroups = []
        
        do {
            let assets = try await fetchAllPhotos()
            let duplicates = await analyzeDuplicates(assets: assets)
            self.duplicateGroups = duplicates
        } catch {
            print("Error finding duplicates: \(error)")
        }
        
        isAnalyzing = false
        analysisProgress = 1.0
    }
    
    /// Анализирует фотографии для поиска похожих изображений
    func findSimilarPhotos() async {
        guard !isAnalyzing else { return }
        
        isAnalyzing = true
        analysisProgress = 0.0
        similarGroups = []
        
        do {
            let assets = try await fetchAllPhotos()
            let similar = await analyzeSimilarPhotos(assets: assets)
            self.similarGroups = similar
        } catch {
            print("Error finding similar photos: \(error)")
        }
        
        isAnalyzing = false
        analysisProgress = 1.0
    }
    
    /// Отменяет текущий анализ
    func cancelAnalysis() {
        analysisTask?.cancel()
        analysisTask = nil
        isAnalyzing = false
        analysisProgress = 0.0
    }
    
    // MARK: - Private Methods
    
    /// Получает все фотографии из галереи
    private func fetchAllPhotos() async throws -> [PHAsset] {
        return await withCheckedContinuation { continuation in
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            
            let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
            var assets: [PHAsset] = []
            
            fetchResult.enumerateObjects { asset, _, _ in
                assets.append(asset)
            }
            
            continuation.resume(returning: assets)
        }
    }
    
    /// Анализирует дубликаты используя Vision Framework для более точного поиска
    private func analyzeDuplicates(assets: [PHAsset]) async -> [PhotoGroupModel] {
        var imageFeatures: [(PhotoAssetModel, [Float], String)] = [] // (photo, features, hash)
        let totalAssets = min(assets.count, 300) // Увеличиваем лимит для дубликатов
        
        // Извлекаем признаки для всех изображений
        for (index, asset) in assets.prefix(totalAssets).enumerated() {
            await MainActor.run {
                self.analysisProgress = Double(index) / Double(totalAssets)
            }
            
            if let image = await loadImage(from: asset) {
                let photoModel = PhotoAssetModel(asset: asset, image: image)
                let hash = generatePerceptualHash(image: image) ?? ""
                
                // Используем Vision для извлечения признаков
                if let features = await extractImageFeatures(from: image) {
                    imageFeatures.append((photoModel, features, hash))
                }
            }
        }
        
        // Группируем дубликаты используя комбинированный подход
        return groupDuplicatesAdvanced(imageData: imageFeatures)
    }
    
    /// Анализирует похожие изображения с использованием комбинированного подхода
    private func analyzeSimilarPhotos(assets: [PHAsset]) async -> [PhotoGroupModel] {
        var imageData: [(PhotoAssetModel, String, [Float]?)] = [] // (photo, hash, features)
        let totalAssets = min(assets.count, 150) // Оптимальный лимит для производительности
        
        // Обрабатываем изображения пакетами для лучшей производительности
        let batchSize = 10
        let assetBatches = Array(assets.prefix(totalAssets)).chunked(into: batchSize)
        
        for (batchIndex, batch) in assetBatches.enumerated() {
            // Обрабатываем пакет параллельно
            await withTaskGroup(of: (PhotoAssetModel, String, [Float]?)?.self) { group in
                for asset in batch {
                    group.addTask {
                        if let image = await self.loadImage(from: asset) {
                            let photoModel = PhotoAssetModel(asset: asset, image: image)
                            let hash = await self.generatePerceptualHashAsync(image: image) ?? ""
                            let features = await self.extractImageFeatures(from: image)
                            return (photoModel, hash, features)
                        }
                        return nil
                    }
                }
                
                for await result in group {
                    if let result = result {
                        imageData.append(result)
                    }
                }
            }
            
            // Обновляем прогресс
            await MainActor.run {
                self.analysisProgress = Double((batchIndex + 1) * batchSize) / Double(totalAssets)
            }
        }
        
        // Группируем похожие изображения
        return groupSimilarImagesAdvanced(imageData: imageData)
    }
    
    /// Загружает изображение из PHAsset оптимизированного размера
    private func loadImage(from asset: PHAsset) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .fastFormat // Быстрая загрузка
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            
            let targetSize = CGSize(width: 256, height: 256) // Оптимальный размер для анализа
            
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    
    /// Генерирует перцептивный хеш изображения для поиска дубликатов (async версия)
    private func generatePerceptualHashAsync(image: UIImage) async -> String? {
        return generatePerceptualHash(image: image)
    }
    
    /// Генерирует перцептивный хеш изображения для поиска дубликатов
    private func generatePerceptualHash(image: UIImage) -> String? {
        guard let cgImage = image.cgImage else { return nil }
        
        // Уменьшаем изображение до 8x8 пикселей для создания хеша
        let size = CGSize(width: 8, height: 8)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // Рисуем изображение в сером цвете
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext(),
              let resizedCGImage = resizedImage.cgImage else { return nil }
        
        // Получаем пиксельные данные
        let width = resizedCGImage.width
        let height = resizedCGImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context2 = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
        
        context2?.draw(resizedCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Вычисляем средний уровень яркости
        var totalBrightness: Int = 0
        var grayscaleValues: [Int] = []
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * bytesPerPixel
                let r = Int(pixelData[pixelIndex])
                let g = Int(pixelData[pixelIndex + 1])
                let b = Int(pixelData[pixelIndex + 2])
                
                // Конвертируем в оттенки серого
                let gray = Int(0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b))
                grayscaleValues.append(gray)
                totalBrightness += gray
            }
        }
        
        let averageBrightness = totalBrightness / (width * height)
        
        // Создаем бинарный хеш
        var hash = ""
        for brightness in grayscaleValues {
            hash += brightness > averageBrightness ? "1" : "0"
        }
        
        return hash
    }
    
    /// Вычисляет расстояние Хэмминга между двумя бинарными строками
    private func hammingDistance(_ hash1: String, _ hash2: String) -> Int {
        guard hash1.count == hash2.count else { return Int.max }
        
        var distance = 0
        for (char1, char2) in zip(hash1, hash2) {
            if char1 != char2 {
                distance += 1
            }
        }
        return distance
    }
    
    /// Извлекает признаки изображения с помощью Vision Framework (улучшенная версия)
    private func extractImageFeatures(from image: UIImage) async -> [Float]? {
        guard let cgImage = image.cgImage else { return nil }
        
        return await withCheckedContinuation { continuation in
            // Используем VNGenerateImageFeaturePrintRequest для получения признаков
            let request = VNGenerateImageFeaturePrintRequest { request, error in
                if let error = error {
                    print("Vision feature extraction error: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let observations = request.results as? [VNFeaturePrintObservation],
                      let featurePrint = observations.first else {
                    print("No feature print observations found")
                    continuation.resume(returning: nil)
                    return
                }
                
                // Извлекаем данные признаков
                let features = featurePrint.data.withUnsafeBytes { bytes in
                    Array(bytes.bindMemory(to: Float.self))
                }
                
                continuation.resume(returning: features)
            }
            
            // Настраиваем обработчик с оптимизированными параметрами
            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: .up,
                options: [
                    VNImageOption.ciContext: CIContext(options: [.useSoftwareRenderer: false])
                ]
            )
            
            do {
                try handler.perform([request])
            } catch {
                print("Vision handler error: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }
    

    
    /// Продвинутая группировка дубликатов с использованием Vision Framework
    private func groupDuplicatesAdvanced(imageData: [(PhotoAssetModel, [Float], String)]) -> [PhotoGroupModel] {
        var groups: [PhotoGroupModel] = []
        var processed: Set<String> = []
        
        for (i, (photo1, features1, hash1)) in imageData.enumerated() {
            if processed.contains(photo1.localIdentifier) { continue }
            
            var duplicatePhotos: [PhotoAssetModel] = [photo1]
            processed.insert(photo1.localIdentifier)
            
            for (j, (photo2, features2, hash2)) in imageData.enumerated() {
                if i == j || processed.contains(photo2.localIdentifier) { continue }
                
                var isDuplicate = false
                
                // Сначала проверяем перцептивный хеш (очень строгий для дубликатов)
                let hashDistance = hammingDistance(hash1, hash2)
                if hashDistance <= 3 { // Очень строгий порог для дубликатов
                    isDuplicate = true
                }
                
                // Если хеши не совпадают, проверяем через Vision (очень высокий порог)
                if !isDuplicate {
                    let similarity = calculateCosineSimilarity(features1, features2)
                    if similarity > 0.95 { // Очень высокий порог для дубликатов
                        isDuplicate = true
                    }
                }
                
                if isDuplicate {
                    duplicatePhotos.append(photo2)
                    processed.insert(photo2.localIdentifier)
                }
            }
            
            // Создаем группу только если найдены дубликаты
            if duplicatePhotos.count > 1 {
                // Выбираем лучшее изображение в группе
                if let bestIndex = findBestPhotoIndex(in: duplicatePhotos) {
                    duplicatePhotos[bestIndex].isBest = true
                }
                
                let group = PhotoGroupModel(groupType: .duplicates, photos: duplicatePhotos)
                groups.append(group)
            }
        }
        
        return groups.sorted { $0.photos.count > $1.photos.count }
    }
    
    /// Улучшенная группировка похожих изображений с комбинированным подходом
    private func groupSimilarImagesAdvanced(imageData: [(PhotoAssetModel, String, [Float]?)]) -> [PhotoGroupModel] {
        var groups: [PhotoGroupModel] = []
        var processed: Set<String> = []
        
        for (i, (photo1, hash1, features1)) in imageData.enumerated() {
            if processed.contains(photo1.localIdentifier) { continue }
            
            var similarPhotos: [PhotoAssetModel] = [photo1]
            processed.insert(photo1.localIdentifier)
            
            for (j, (photo2, hash2, features2)) in imageData.enumerated() {
                if i == j || processed.contains(photo2.localIdentifier) { continue }
                
                var isSimilar = false
                var similarity: Double = 0.0
                
                // Сначала проверяем перцептивный хеш (быстро)
                let hashDistance = hammingDistance(hash1, hash2)
                if hashDistance <= 15 { // Более мягкий порог для похожих
                    similarity = 1.0 - (Double(hashDistance) / 64.0) // Нормализуем
                    isSimilar = true
                }
                
                // Если хеши не очень похожи, проверяем через Vision (медленно, но точно)
                if !isSimilar, let f1 = features1, let f2 = features2 {
                    let cosineSim = calculateCosineSimilarity(f1, f2)
                    if cosineSim > 0.75 { // Более мягкий порог
                        similarity = cosineSim
                        isSimilar = true
                    }
                }
                
                if isSimilar {
                    var similarPhoto = photo2
                    similarPhoto.similarityScore = similarity
                    similarPhotos.append(similarPhoto)
                    processed.insert(photo2.localIdentifier)
                }
            }
            
            // Создаем группу только если найдены похожие изображения
            if similarPhotos.count > 1 {
                // Выбираем лучшее изображение в группе
                if let bestIndex = findBestPhotoIndex(in: similarPhotos) {
                    similarPhotos[bestIndex].isBest = true
                }
                
                let group = PhotoGroupModel(groupType: .similar, photos: similarPhotos)
                groups.append(group)
            }
        }
        
        return groups.sorted { $0.photos.count > $1.photos.count }
    }
    
    /// Вычисляет косинусное сходство между двумя векторами признаков
    private func calculateCosineSimilarity(_ vector1: [Float], _ vector2: [Float]) -> Double {
        guard vector1.count == vector2.count else { return 0.0 }
        
        let dotProduct = zip(vector1, vector2).map(*).reduce(0, +)
        let magnitude1 = sqrt(vector1.map { $0 * $0 }.reduce(0, +))
        let magnitude2 = sqrt(vector2.map { $0 * $0 }.reduce(0, +))
        
        guard magnitude1 > 0 && magnitude2 > 0 else { return 0.0 }
        
        return Double(dotProduct / (magnitude1 * magnitude2))
    }
    
    /// Находит индекс лучшего фото в группе (по дате создания и размеру)
    private func findBestPhotoIndex(in photos: [PhotoAssetModel]) -> Int? {
        guard !photos.isEmpty else { return nil }
        
        var bestIndex = 0
        var bestScore = 0.0
        
        for (index, photo) in photos.enumerated() {
            var score = 0.0
            
            // Учитываем размер изображения
            let pixelCount = Double(photo.asset.pixelWidth * photo.asset.pixelHeight)
            score += pixelCount / 1_000_000.0 // Нормализуем
            
            // Учитываем дату создания (более новые получают больше баллов)
            if let creationDate = photo.creationDate {
                let daysSinceCreation = Date().timeIntervalSince(creationDate) / (24 * 60 * 60)
                score += max(0, 365 - daysSinceCreation) / 365.0 // Новые фото получают больше баллов
            }
            
            if score > bestScore {
                bestScore = score
                bestIndex = index
            }
        }
        
        return bestIndex
    }
}

// MARK: - Array Extension for Chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
