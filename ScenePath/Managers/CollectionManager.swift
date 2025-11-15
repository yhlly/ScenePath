//  CollectionManager.swift

import Foundation
import SwiftData
import CoreLocation
import Combine
import MapKit

@Observable
class CollectionManager {
    private var modelContext: ModelContext?
    
    // 当前可收集的点位
    var availableCollectibles: [CollectiblePoint] = []
    
    // 已收集的物品
    var collectedItems: [CollectibleItem] = []
    
    // 当前用户位置
    var currentLocation: CLLocationCoordinate2D?
    
    // 收集范围（米）
    private let collectionRadius: Double = 10000
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadCollectedItems()
    }
    
    // 基于特殊路线类型和导航指令生成可收集点
    func generateCollectiblePoints(for specialRouteType: SpecialRouteType, instructions: [NavigationInstruction]) {
        
        guard specialRouteType != .none else {
            availableCollectibles = []
            return
        }
        
        var points: [CollectiblePoint] = []
        
        // 根据特殊路线类型确定收集点类别
        let categories = getCategoriesForRouteType(specialRouteType)
        
        // 为路线上的关键点生成收集点
        for (index, instruction) in instructions.enumerated() {
            // 每隔2-3个导航点生成一个收集点，确保有足够的收集点
            if index % 2 == 1 || index % 3 == 2 {
                let category = categories.randomElement() ?? .food
                let point = generateCollectiblePoint(
                    near: instruction.coordinate,
                    category: category,
                    routeType: specialRouteType
                )
                points.append(point)
            }
        }
        
        // 添加一些随机的额外收集点，确保有足够的密度
        let extraCount = max(2, instructions.count / 3)
        let extraPoints = generateRandomCollectiblePoints(
            along: instructions,
            categories: categories,
            count: extraCount
        )
        points.append(contentsOf: extraPoints)
        
        availableCollectibles = points
        
        // 打印所有收集点详情
        for (index, point) in points.enumerated() {
            print("  \(index + 1). \(point.name) - \(point.category.rawValue) - 坐标: (\(String(format: "%.4f", point.coordinate.latitude)), \(String(format: "%.4f", point.coordinate.longitude)))")
        }
        
        // 检查哪些已经被收集过了
        updateCollectionStatus()
    }
    
    // 更新用户位置并检查可收集的点
    func updateLocation(_ location: CLLocationCoordinate2D) {
        currentLocation = location
        
        // 计算范围内的收集点
        let inRange = collectiblesInRange(of: location)
        
        for collectible in inRange {
            let distance = CLLocation(latitude: location.latitude, longitude: location.longitude)
                .distance(from: CLLocation(latitude: collectible.coordinate.latitude, longitude: collectible.coordinate.longitude))
            print("    - \(collectible.name): \(Int(distance))米")
        }
    }
    
    // 检查指定坐标是否在收集范围内
    func collectiblesInRange(of location: CLLocationCoordinate2D) -> [CollectiblePoint] {
        let userLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        let inRange = availableCollectibles.filter { point in
            if point.isCollected {
                return false
            }
            
            let pointLocation = CLLocation(latitude: point.coordinate.latitude,
                                         longitude: point.coordinate.longitude)
            let distance = userLocation.distance(from: pointLocation)
            let isInRange = distance <= collectionRadius
            
            return isInRange
        }
        
        return inRange
    }
    
    // 收集物品
    func collectItem(_ point: CollectiblePoint, routeType: SpecialRouteType) {
        
        guard let context = modelContext else {
            return
        }
        
        // 检查是否已经收集过相同位置和类型的物品
        let alreadyCollected = collectedItems.contains { item in
            let distance = CLLocation(latitude: item.latitude, longitude: item.longitude)
                .distance(from: CLLocation(latitude: point.coordinate.latitude,
                                         longitude: point.coordinate.longitude))
            let isSameTypeAndLocation = distance < 50 && item.category == point.category
            
            return isSameTypeAndLocation
        }
        
        if alreadyCollected {
            return
        }
        
        // 创建新的收集物品
        let newItem = CollectibleItem(
            name: point.name,
            category: point.category,
            coordinate: point.coordinate,
            routeType: routeType,
            description: point.description
        )
        
        
        // 保存到SwiftData
        context.insert(newItem)
        
        do {
            try context.save()
            collectedItems.append(newItem)
            
            
            // 更新可收集点状态
            updateCollectionStatus()
            
        } catch {
        }
    }
    
    // 加载已收集的物品
    private func loadCollectedItems() {
        
        guard let context = modelContext else {
            return
        }
        
        do {
            let descriptor = FetchDescriptor<CollectibleItem>(
                sortBy: [SortDescriptor(\.collectedAt, order: .reverse)]
            )
            collectedItems = try context.fetch(descriptor)
            
            // 打印已收集物品详情
            for (index, item) in collectedItems.enumerated() {
                print("    \(index + 1). \(item.name) (\(item.category.rawValue)) - \(item.collectedAt)")
            }
            
        } catch {
            collectedItems = []
        }
    }
    
    // 更新收集状态
    private func updateCollectionStatus() {
        
        var updatedCollectibles: [CollectiblePoint] = []
        
        for point in availableCollectibles {
            let isCollected = collectedItems.contains { item in
                let distance = CLLocation(latitude: item.latitude, longitude: item.longitude)
                    .distance(from: CLLocation(latitude: point.coordinate.latitude,
                                             longitude: point.coordinate.longitude))
                return distance < 50 && item.category == point.category
            }
            
            let updatedPoint = CollectiblePoint(
                name: point.name,
                category: point.category,
                coordinate: point.coordinate,
                description: point.description,
                isCollected: isCollected
            )
            
            updatedCollectibles.append(updatedPoint)
            
            if isCollected && !point.isCollected {
            }
        }
        
        availableCollectibles = updatedCollectibles
        
        let collectedCount = availableCollectibles.filter { $0.isCollected }.count
    }
    
    // 根据路线类型获取收集点类别
    private func getCategoriesForRouteType(_ routeType: SpecialRouteType) -> [CollectibleCategory] {
        let categories: [CollectibleCategory]
        
        switch routeType {
        case .food:
            categories = [.food, .culture] // 美食路线：美食 + 文化
        case .scenic:
            categories = [.scenic, .landmark] // 风景路线：风景 + 地标
        case .attractions:
            categories = [.attraction, .culture, .landmark] // 景点路线：景点 + 文化 + 地标
        case .none:
            categories = []
        }
        
        return categories
    }
    
    // 生成单个收集点 - 使用真实POI
    private func generateCollectiblePoint(near coordinate: CLLocationCoordinate2D, category: CollectibleCategory, routeType: SpecialRouteType) -> CollectiblePoint {
        // 在指定坐标附近随机生成一个点（50-200米范围内）
        let distance = Double.random(in: 50...200)
        let angle = Double.random(in: 0...(2 * .pi))
        
        let deltaLat = distance * cos(angle) / 111000 // 大约111000米每度纬度
        let deltaLng = distance * sin(angle) / (111000 * cos(coordinate.latitude * .pi / 180))
        
        let newCoordinate = CLLocationCoordinate2D(
            latitude: coordinate.latitude + deltaLat,
            longitude: coordinate.longitude + deltaLng
        )
        
        // 先使用临时名称，之后会尝试获取真实POI
        var name = getDefaultNameForCategory(category)
        var description = category.defaultDescription
        
        // 创建收集点
        let collectiblePoint = CollectiblePoint(
            name: name,
            category: category,
            coordinate: newCoordinate,
            description: description
        )
        
        // 异步查询该坐标附近的实际POI
        searchNearbyPOI(coordinate: newCoordinate, category: category) { poiName, poiDescription in
            if let poiName = poiName {
                // 有时在闭包中更新收集点名称和描述
                DispatchQueue.main.async { [weak self] in
                    // 查找并更新对应收集点
                    if let index = self?.availableCollectibles.firstIndex(where: { $0.coordinate.latitude == newCoordinate.latitude && $0.coordinate.longitude == newCoordinate.longitude }) {
                        // 创建新的收集点副本，但使用实际POI名称
                        let updatedPoint = CollectiblePoint(
                            name: poiName,
                            category: category,
                            coordinate: newCoordinate,
                            description: poiDescription ?? description,
                            isCollected: self?.availableCollectibles[index].isCollected ?? false
                        )
                        
                        // 更新收集点
                        self?.availableCollectibles[index] = updatedPoint
                        
                    }
                }
            }
        }
    
        
        return collectiblePoint
    }
    
    // 搜索附近的实际POI名称
    private func searchNearbyPOI(coordinate: CLLocationCoordinate2D, category: CollectibleCategory, completion: @escaping (String?, String?) -> Void) {
        // 定义搜索关键词
        let keywords: [String] = getCategoryKeywords(category)
        let randomKeyword = keywords.randomElement() ?? category.rawValue
        
        // 创建搜索请求
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = randomKeyword
        
        // 设置搜索区域（200米半径）
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 200,
            longitudinalMeters: 200
        )
        request.region = region
        
        // 执行搜索
        let search = MKLocalSearch(request: request)
        search.start {
 response,
 error in
            if let error = error {
                completion(nil, nil)
                return
            }
            
            guard let response = response,
 !response.mapItems.isEmpty else {
                completion(nil, nil)
                return
            }
            
            // 找到最近的POI
            if let nearestPOI = response.mapItems.first {
                let poiName = nearestPOI.name ?? self.getDefaultNameForCategory(
                    category
                )
                
                // 获取描述（如果有）
                var poiDescription = category.defaultDescription
                if let phoneNumber = nearestPOI.phoneNumber,
 !phoneNumber.isEmpty {
                    poiDescription += " (电话: \(phoneNumber))"
                }
                
                print("🔍 找到实际POI: \(poiName)")
                completion(poiName, poiDescription)
            } else {
                completion(nil, nil)
            }
        }
    }
    
    // 获取每个类别的默认名称
    private func getDefaultNameForCategory(_ category: CollectibleCategory) -> String {
        let names: [String]
        
        switch category {
        case .food:
            names = ["当地美食", "特色餐厅", "美食店", "咖啡馆", "小吃店", "甜品店"]
        case .scenic:
            names = ["风景点", "观景台", "美丽景观", "景色优美处", "自然景观"]
        case .attraction:
            names = ["旅游景点", "历史景点", "文化遗址", "特色景点", "博物馆"]
        case .landmark:
            names = ["地标建筑", "著名地标", "历史建筑", "特色建筑", "标志性建筑"]
        case .culture:
            names = ["文化场所", "文化中心", "艺术展览", "手工艺品", "传统文化"]
        }
        
        return names.randomElement() ?? category.rawValue
    }
    
    // 获取类别相关的搜索关键词
    private func getCategoryKeywords(_ category: CollectibleCategory) -> [String] {
        switch category {
        case .food:
            return ["餐厅", "咖啡厅", "美食", "小吃", "甜品", "面包店"]
        case .scenic:
            return ["公园", "花园", "风景区", "湖泊", "海滩", "自然景观"]
        case .attraction:
            return ["景点", "旅游景点", "名胜", "博物馆", "展览馆"]
        case .landmark:
            return ["地标", "建筑", "塔", "桥", "历史建筑", "纪念碑"]
        case .culture:
            return ["艺术", "文化", "表演", "剧院", "画廊", "展览中心"]
        }
    }
    
    // 生成随机收集点
    private func generateRandomCollectiblePoints(along instructions: [NavigationInstruction], categories: [CollectibleCategory], count: Int) -> [CollectiblePoint] {
        
        var points: [CollectiblePoint] = []
        
        for i in 0..<count {
            guard let randomInstruction = instructions.randomElement(),
                  let category = categories.randomElement() else {
                continue
            }
            
            let point = generateCollectiblePoint(
                near: randomInstruction.coordinate,
                category: category,
                routeType: .food // 这里传入什么都可以，因为只是用来生成点位
            )
            points.append(point)
        }
        
        return points
    }
    
    // 获取收集统计
    func getCollectionStats() -> (total: Int, byCategory: [CollectibleCategory: Int]) {
        var byCategory: [CollectibleCategory: Int] = [:]
        
        for item in collectedItems {
            byCategory[item.category, default: 0] += 1
        }
        
        let stats = (total: collectedItems.count, byCategory: byCategory)
        
        return stats
    }
    
    // 清除所有收集点（用于调试）
    func clearAllCollectibles() {
        availableCollectibles.removeAll()
    }
    
    // 强制刷新收集状态（用于调试）
    func refreshCollectionStatus() {
        loadCollectedItems()
        updateCollectionStatus()
    }
}
