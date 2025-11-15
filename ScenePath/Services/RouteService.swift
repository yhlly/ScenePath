//  RouteService.swift

import Foundation
import CoreLocation
import MapKit

class RouteService {
    static let shared = RouteService()
    
    private init() {}
    
    // 原有的路线计算方法
    func calculateRoute(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, transportType: TransportationType, completion: @escaping ([RouteInfo]) -> Void) {
        let defaultConfig = SpecialRouteConfig(specialType: .none, transportType: transportType)
        calculateRouteWithSpecialType(from: start, to: end, transportType: transportType, specialConfig: defaultConfig, completion: completion)
    }
    
    // 支持特殊路线的路线计算方法 - 重新实现
    func calculateRouteWithSpecialType(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, transportType: TransportationType, specialConfig: SpecialRouteConfig, completion: @escaping ([RouteInfo]) -> Void) {
        
        if specialConfig.specialType == .none {
            // 常规路线：直接计算最优路线
            calculateNormalRoutes(from: start, to: end, transportType: transportType, completion: completion)
        } else {
            // 特殊路线：先搜索POI，然后计算多段路线
            calculateSpecialRoutes(from: start, to: end, transportType: transportType, specialConfig: specialConfig, completion: completion)
        }
    }
    
    // 计算常规路线 - 修改后的方法
    private func calculateNormalRoutes(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, transportType: TransportationType, completion: @escaping ([RouteInfo]) -> Void) {
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        request.transportType = transportType.mkDirectionsTransportType
        request.requestsAlternateRoutes = true
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            guard let response = response, !response.routes.isEmpty else {
                if let error = error {
                }
                
                // 返回空数组
                let simulatedRoutes = self.generateSimulatedNormalRoutes(from: start, to: end, transportType: transportType)
                completion(simulatedRoutes)
                return
            }
            
            var routeInfos: [RouteInfo] = []
            
            // 对路线进行分类和排序
            let allRoutes = response.routes
            
            // 1. 找出最快路线 (按照预计时间排序)
            let sortedByTime = allRoutes.sorted { $0.expectedTravelTime < $1.expectedTravelTime }
            let fastestRoute = sortedByTime.first
            
            // 2. 找出最短路线 (按照距离排序)
            let sortedByDistance = allRoutes.sorted { $0.distance < $1.distance }
            let shortestRoute = sortedByDistance.first
            
            // 3. 处理剩余的路线作为备选路线
            var remainingRoutes = allRoutes.filter { route in
                route !== fastestRoute && route !== shortestRoute
            }
            
            // 记录已处理的路线
            var processedRoutes = Set<MKRoute>()
            
            // 4. 处理最快路线
            if let fastestRoute = fastestRoute {
                processedRoutes.insert(fastestRoute)
                
                // 使用真实的距离和时间数据
                let distance = String(format: "%.1f公里", fastestRoute.distance / 1000)
                let duration = String(format: "%.0f分钟", fastestRoute.expectedTravelTime / 60)
                
                // 价格 - 修改为全部免费
                let price = ""
                
                
                let instructions = self.generateNavigationInstructions(for: fastestRoute, transportType: transportType)
                
                // 基于真实距离确定难度
                let difficulty: RouteDifficulty = fastestRoute.distance / 1000 < 5 ? .easy : (fastestRoute.distance / 1000 < 15 ? .medium : .hard)
                
                let routeInfo = RouteInfo(
                    type: .fastest,
                    transportType: transportType,
                    distance: distance,
                    duration: duration,
                    price: price,
                    route: fastestRoute,
                    description: "最快路线，耗时最短，预计用时\(duration)",
                    instructions: instructions,
                    specialRouteType: .none,
                    highlights: ["高效出行", "路况良好", "省时"],
                    difficulty: difficulty
                )
                
                routeInfos.append(routeInfo)
            }
            
            // 5. 处理最短路线 (如果不是最快路线)
            if let shortestRoute = shortestRoute, !processedRoutes.contains(shortestRoute) {
                processedRoutes.insert(shortestRoute)
                
                // 使用真实的距离和时间数据
                let distance = String(format: "%.1f公里", shortestRoute.distance / 1000)
                let duration = String(format: "%.0f分钟", shortestRoute.expectedTravelTime / 60)
                
                // 价格 - 修改为全部免费
                let price = ""
                
                let instructions = self.generateNavigationInstructions(for: shortestRoute, transportType: transportType)
                
                // 基于真实距离确定难度
                let difficulty: RouteDifficulty = shortestRoute.distance / 1000 < 5 ? .easy : (shortestRoute.distance / 1000 < 15 ? .medium : .hard)
                
                let routeInfo = RouteInfo(
                    type: .shortest,
                    transportType: transportType,
                    distance: distance,
                    duration: duration,
                    price: price,
                    route: shortestRoute,
                    description: "最短路线，距离最短，总长\(distance)",
                    instructions: instructions,
                    specialRouteType: .none,
                    highlights: ["距离最短", "省油省电", "直接路线"],
                    difficulty: difficulty
                )
                
                routeInfos.append(routeInfo)
            }
            
            // 6. 处理剩余路线作为备选路线
            for route in remainingRoutes.prefix(1) { // 只处理最多1条备选路线
                let distance = String(format: "%.1f公里", route.distance / 1000)
                let duration = String(format: "%.0f分钟", route.expectedTravelTime / 60)
                
                // 价格 - 修改为全部免费
                let price = ""
                
                let instructions = self.generateNavigationInstructions(for: route, transportType: transportType)
                
                // 基于真实距离确定难度
                let difficulty: RouteDifficulty = route.distance / 1000 < 5 ? .easy : (route.distance / 1000 < 15 ? .medium : .hard)
                
                let routeInfo = RouteInfo(
                    type: .alternative,
                    transportType: transportType,
                    distance: distance,
                    duration: duration,
                    price: price,
                    route: route,
                    description: "备选路线，可能交通流量较少",
                    instructions: instructions,
                    specialRouteType: .none,
                    highlights: ["路况良好", "备选方案"],
                    difficulty: difficulty
                )
                
                routeInfos.append(routeInfo)
            }
            
            // 7. 如果没有路线，添加一个推荐路线
            if routeInfos.isEmpty && !allRoutes.isEmpty {
                let recommendedRoute = allRoutes[0]
                let distance = String(format: "%.1f公里", recommendedRoute.distance / 1000)
                let duration = String(format: "%.0f分钟", recommendedRoute.expectedTravelTime / 60)
                
                // 价格 - 修改为全部免费
                let price = ""
                
                let instructions = self.generateNavigationInstructions(for: recommendedRoute, transportType: transportType)
                
                // 基于真实距离确定难度
                let difficulty: RouteDifficulty = recommendedRoute.distance / 1000 < 5 ? .easy : (recommendedRoute.distance / 1000 < 15 ? .medium : .hard)
                
                let routeInfo = RouteInfo(
                    type: .recommended,
                    transportType: transportType,
                    distance: distance,
                    duration: duration,
                    price: price,
                    route: recommendedRoute,
                    description: "推荐路线，综合考虑时间和距离",
                    instructions: instructions,
                    specialRouteType: .none,
                    highlights: ["推荐路线", "平衡的选择"],
                    difficulty: difficulty
                )
                
                routeInfos.append(routeInfo)
            }
            
            completion(routeInfos)
        }
    }
    
    // 计算特殊路线 - 核心实现
    private func calculateSpecialRoutes(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, transportType: TransportationType, specialConfig: SpecialRouteConfig, completion: @escaping ([RouteInfo]) -> Void) {
        
        
        // 第一步：搜索相关POI
        searchPOIsForSpecialRoute(from: start, to: end, specialConfig: specialConfig) { pois in
            
            for (index, poi) in pois.enumerated() {
                print("  \(index + 1). \(poi.name ?? "未知地点") - \(poi.placemark.title ?? "")")
            }
            
            if pois.isEmpty {
                // 如果没找到POI，fallback到常规路线（使用真实数据）
                self.calculateNormalRoutes(from: start, to: end, transportType: transportType, completion: completion)
                return
            }
            
            // 第二步：选择最佳中间点
            let selectedPOIs = self.selectBestPOIs(pois: pois, from: start, to: end, maxCount: 1)
            
            for (index, poi) in selectedPOIs.enumerated() {
                print("  选中\(index + 1): \(poi.name ?? "未知地点")")
            }
            
            if selectedPOIs.isEmpty {
                // 如果没有合适的中间点，fallback到常规路线（使用真实数据）
                self.calculateNormalRoutes(from: start, to: end, transportType: transportType, completion: completion)
                return
            }
            
            // 第三步：计算多段路线
            self.calculateMultiSegmentRoutes(from: start, to: end, waypoints: selectedPOIs, transportType: transportType, specialConfig: specialConfig) { specialRoutes in
                
                
                if specialRoutes.isEmpty {
                    // 如果特殊路线计算失败，fallback到常规路线
                    self.calculateNormalRoutes(from: start, to: end, transportType: transportType, completion: completion)
                    return
                }
                
                // 第四步：同时计算一条常规路线作为对比
                self.calculateNormalRoutes(from: start, to: end, transportType: transportType) { normalRoutes in
                    
                    for (index, route) in specialRoutes.enumerated() {
                        print("    \(index + 1). \(route.type.rawValue) - \(route.distance) - \(route.duration)")
                        print("       描述: \(route.description)")
                        print("       亮点: \(route.highlights.joined(separator: ", "))")
                    }
                    
                    for (index, route) in normalRoutes.enumerated() {
                        print("    \(index + 1). \(route.type.rawValue) - \(route.distance) - \(route.duration)")
                    }
                    
                    // 合并结果，特殊路线在前
                    var allRoutes = specialRoutes
                    if let firstNormalRoute = normalRoutes.first {
                        allRoutes.append(firstNormalRoute)
                    }
                    
                    completion(allRoutes)
                }
            }
        }
    }
    
    // 搜索POI
    private func searchPOIsForSpecialRoute(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, specialConfig: SpecialRouteConfig, completion: @escaping ([MKMapItem]) -> Void) {
        
        // 计算搜索区域（起终点连线的中点及周围区域）
        let centerLat = (start.latitude + end.latitude) / 2
        let centerLng = (start.longitude + end.longitude) / 2
        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng)
        
        // 搜索半径基于起终点距离
        let distance = CLLocation(latitude: start.latitude, longitude: start.longitude)
            .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
        let searchRadius = min(max(distance / 2, 1000), 10000) // 最小1km，最大10km
        
        
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: searchRadius,
            longitudinalMeters: searchRadius
        )
        
        var allPOIs: [MKMapItem] = []
        let searchGroup = DispatchGroup()
        
        // 为每个关键词执行搜索
        for (keywordIndex, keyword) in specialConfig.priorityKeywords.prefix(3).enumerated() { // 限制搜索关键词数量
            searchGroup.enter()
            
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = keyword
            request.region = region
            
            let search = MKLocalSearch(request: request)
            search.start { response, error in
                defer { searchGroup.leave() }
                
                if let error = error {
                    return
                }
                
                if let response = response {
                    let results = Array(response.mapItems.prefix(5)) // 每个关键词最多5个结果
                    for (index, item) in results.enumerated() {
                        print("      \(index + 1). \(item.name ?? "未知") - \(item.phoneNumber ?? "无电话")")
                    }
                    allPOIs.append(contentsOf: results)
                } else {
                }
            }
        }
        
        searchGroup.notify(queue: .main) {
            completion(allPOIs)
        }
    }
    
    // 选择最佳POI作为中间点
    private func selectBestPOIs(pois: [MKMapItem], from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, maxCount: Int) -> [MKMapItem] {
        
        let startLocation = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLocation = CLLocation(latitude: end.latitude, longitude: end.longitude)
        let directDistance = startLocation.distance(from: endLocation)
        
        // 评分POI
        let scoredPOIs = pois.compactMap { poi -> (poi: MKMapItem, score: Double)? in
            guard let coordinate = poi.placemark.location?.coordinate else { return nil }
            
            let poiLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distanceFromStart = startLocation.distance(from: poiLocation)
            let distanceFromEnd = poiLocation.distance(from: endLocation)
            let totalDistance = distanceFromStart + distanceFromEnd
            
            // 绕行程度：与直线距离的比值
            let detourRatio = totalDistance / directDistance
            
            // 如果绕行太多，跳过
            if detourRatio > 1.8 { return nil }
            
            // 计算分数：距离越近越好，绕行越少越好
            let distanceScore = max(0, 1.0 - (detourRatio - 1.0) / 0.8) // 绕行率越低分数越高
            let positionScore = 1.0 - abs(0.5 - distanceFromStart / totalDistance) * 2 // 位置越居中分数越高
            
            let finalScore = distanceScore * 0.7 + positionScore * 0.3
            
            return (poi: poi, score: finalScore)
        }
        
        // 按分数排序并返回最佳的几个
        let bestPOIs = scoredPOIs
            .sorted { $0.score > $1.score }
            .prefix(maxCount)
            .map { $0.poi }
        
        return Array(bestPOIs)
    }
    
    // 计算多段路线
    private func calculateMultiSegmentRoutes(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, waypoints: [MKMapItem], transportType: TransportationType, specialConfig: SpecialRouteConfig, completion: @escaping ([RouteInfo]) -> Void) {
        
        guard let waypoint = waypoints.first,
              let waypointCoordinate = waypoint.placemark.location?.coordinate else {
            completion([])
            return
        }
        
        let routeGroup = DispatchGroup()
        var firstSegment: MKRoute?
        var secondSegment: MKRoute?
        var hasError = false
        
        // 计算第一段：起点到中间点
        routeGroup.enter()
        let firstRequest = MKDirections.Request()
        firstRequest.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        firstRequest.destination = waypoint
        firstRequest.transportType = transportType.mkDirectionsTransportType
        
        let firstDirections = MKDirections(request: firstRequest)
        firstDirections.calculate { response, error in
            defer { routeGroup.leave() }
            if let route = response?.routes.first {
                firstSegment = route
            } else {
                hasError = true
                if let error = error {
                }
            }
        }
        
        // 计算第二段：中间点到终点
        routeGroup.enter()
        let secondRequest = MKDirections.Request()
        secondRequest.source = waypoint
        secondRequest.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        secondRequest.transportType = transportType.mkDirectionsTransportType
        
        let secondDirections = MKDirections(request: secondRequest)
        secondDirections.calculate { response, error in
            defer { routeGroup.leave() }
            if let route = response?.routes.first {
                secondSegment = route
            } else {
                hasError = true
                if let error = error {
                }
            }
        }
        
        routeGroup.notify(queue: .main) {
            guard !hasError,
                  let first = firstSegment,
                  let second = secondSegment else {
                // 如果多段路线计算失败，返回空数组，让上层fallback到常规路线
                completion([])
                return
            }
            
            
            // 拼接路线信息
            let combinedRoute = self.combineRoutes(first: first, second: second, waypoint: waypoint, specialConfig: specialConfig, transportType: transportType)
            
            completion([combinedRoute])
        }
    }
    
    // 拼接两段路线 - 使用真实的路线数据
    private func combineRoutes(first: MKRoute, second: MKRoute, waypoint: MKMapItem, specialConfig: SpecialRouteConfig, transportType: TransportationType) -> RouteInfo {
        
        
        // 使用真实的距离和时间数据
        let totalDistance = first.distance + second.distance
        let totalTime = first.expectedTravelTime + second.expectedTravelTime
        
        let distance = String(format: "%.1f公里", totalDistance / 1000)
        let duration = String(format: "%.0f分钟", totalTime / 60)
        
        // 价格设置为免费
        let price = ""
        
        // 生成特殊路线的描述和亮点
        let (description, highlights) = self.generateSpecialRouteDescription(specialConfig: specialConfig, waypoint: waypoint)
        
        // 合并导航指令 - 修复版
        let firstInstructions = generateNavigationInstructions(for: first, transportType: transportType)
        let secondInstructions = generateNavigationInstructions(for: second, transportType: transportType)
        
        
        var combinedInstructions: [NavigationInstruction] = []
        
        // 1. 添加第一段指令，但排除最后的"到达目的地"
        let firstValidInstructions = firstInstructions.dropLast() // 去掉"到达目的地"
        combinedInstructions.append(contentsOf: firstValidInstructions)
        
        // 2. 在中间点添加特殊指令
        let waypointInstruction = NavigationInstruction(
            instruction: "途径\(waypoint.name ?? "兴趣点")",
            distance: "0m",
            icon: specialConfig.specialType.icon,
            coordinate: waypoint.placemark.coordinate
        )
        combinedInstructions.append(waypointInstruction)
        
        // 3. 添加第二段指令，排除"开始导航"但保留所有实际导航指令
        let secondValidInstructions: [NavigationInstruction]
        if secondInstructions.count > 1 &&
           (secondInstructions.first?.instruction.contains("开始导航") ?? false ||
            secondInstructions.first?.instruction.contains("出发") ?? false) {
            // 如果第一条是"开始导航"类型，则跳过
            secondValidInstructions = Array(secondInstructions.dropFirst())
        } else {
            // 否则保留所有指令
            secondValidInstructions = secondInstructions
        }
        
        combinedInstructions.append(contentsOf: secondValidInstructions)
        
        
        // 基于真实距离确定难度
        let difficulty: RouteDifficulty = totalDistance / 1000 < 5 ? .easy : (totalDistance / 1000 < 15 ? .medium : .hard)
      
        return RouteInfo(
            type: .recommended,
            transportType: transportType,
            distance: distance,
            duration: duration,
            price: price,
            route: first, // 主要使用第一段路线用于地图显示
            description: description,
            instructions: combinedInstructions,
            specialRouteType: specialConfig.specialType,
            highlights: highlights,
            difficulty: difficulty
        )
    }
    
    // 生成特殊路线描述
    private func generateSpecialRouteDescription(specialConfig: SpecialRouteConfig, waypoint: MKMapItem) -> (description: String, highlights: [String]) {
        let waypointName = waypoint.name ?? "兴趣点"
        
        switch specialConfig.specialType {
        case .scenic:
            return (
                description: "风景路线，途径\(waypointName)，欣赏沿途美景",
                highlights: [waypointName, "风景优美", "拍照胜地"]
            )
        case .food:
            return (
                description: "美食路线，途径\(waypointName)，体验当地美食",
                highlights: [waypointName, "美食体验", "当地特色"]
            )
        case .attractions:
            return (
                description: "景点路线，途径\(waypointName)，探索文化地标",
                highlights: [waypointName, "文化探索", "历史古迹"]
            )
        case .none:
            return (
                description: "常规路线",
                highlights: ["高效出行"]
            )
        }
    }
    
    // 保留原有方法但更新逻辑
    private func generateSimulatedNormalRoutes(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, transportType: TransportationType) -> [RouteInfo] {
        
        return []
    }
    
  
    
    // 转向类型枚举 - 简化版
    private enum TurnDirection {
        case straight   // 直行
        case left       // 左转
        case uTurn      // 掉头
        case right      // 右转
        
        var instruction: String {
            switch self {
            case .straight: return "继续直行"
            case .left: return "向左转"
            case .uTurn: return "掉头"
            case .right: return "向右转"
            }
        }
        
        var icon: String {
            switch self {
            case .straight: return "arrow.up"
            case .left: return "arrow.turn.up.left"
            case .uTurn: return "arrow.uturn.left"
            case .right: return "arrow.turn.up.right"
            }
        }
    }
    
    // 修正后的真实路线导航指令生成方法
    private func generateNavigationInstructions(for route: MKRoute, transportType: TransportationType) -> [NavigationInstruction] {
       
        var instructions: [NavigationInstruction] = []
        var lastCoordinate: CLLocationCoordinate2D? = nil
        
        let steps = route.steps
        for (index, step) in steps.enumerated() {
            // 获取当前步骤的坐标
            let coordinate: CLLocationCoordinate2D
            if step.polyline.pointCount > 0 {
                let points = step.polyline.points()
                coordinate = points[0].coordinate
            } else {
                // 如果无法获取polyline坐标，使用路线的起点或终点
                coordinate = index == 0 ? route.polyline.coordinate : route.polyline.coordinate
            }
            
            // 检查与上一个步骤点的距离，如果小于20米则跳过（除了起点和终点）
            if let lastCoord = lastCoordinate, index > 0 && index < steps.count - 1 {
                let lastLocation = CLLocation(latitude: lastCoord.latitude, longitude: lastCoord.longitude)
                let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let distance = lastLocation.distance(from: currentLocation)
                
                if distance < 20 {
                    
                    continue
                }
            }
            
            let instruction: String
            let icon: String
            
            
            
            if index == 0 {
                instruction = "开始导航"
                icon = "location.fill"
              
            } else if index == steps.count - 1 {
                instruction = "到达目的地"
                icon = "flag.fill"
               
            } else {
                // 优先解析MapKit提供的导航指令
                let parsedResult = parseMapKitInstruction(step.instructions)
                
                if let result = parsedResult {
                    instruction = result.instruction
                    icon = result.icon
                  
                } else {
                    // 如果MapKit指令无法解析，使用几何计算
                    
                    let geometricResult = calculateTurnDirectionFromStep(step, previousStep: index > 0 ? steps[index-1] : nil)
                    instruction = geometricResult.instruction
                    icon = geometricResult.icon
                }
            }
            
            let navigationInstruction = NavigationInstruction(
                instruction: instruction,
                distance: String(format: "%.0fm", step.distance),
                icon: icon,
                coordinate: coordinate
            )
            
            instructions.append(navigationInstruction)
            lastCoordinate = coordinate // 更新上一个坐标点
        }
        
        return instructions
    }
    
    // 解析MapKit指令
    private func parseMapKitInstruction(_ instruction: String) -> (instruction: String, icon: String)? {
        let lower = instruction.lowercased()
        
        // 掉头相关
        if lower.contains("掉头") || lower.contains("u-turn") || lower.contains("回转") {
            return ("掉头", "arrow.uturn.left")
        }
        
        // 左转相关 (包含所有左转类型)
        if lower.contains("左转") || lower.contains("turn left") ||
           lower.contains("稍向左转") || lower.contains("向左急转") ||
           lower.contains("靠左") || lower.contains("slight left") ||
           lower.contains("sharp left") || lower.contains("keep left") {
            return ("向左转", "arrow.turn.up.left")
        }
        
        // 右转相关 (包含所有右转类型)
        if lower.contains("右转") || lower.contains("turn right") ||
           lower.contains("稍向右转") || lower.contains("向右急转") ||
           lower.contains("靠右") || lower.contains("slight right") ||
           lower.contains("sharp right") || lower.contains("keep right") {
            return ("向右转", "arrow.turn.up.right")
        }
        
        // 直行相关
        if lower.contains("直行") || lower.contains("straight") ||
           lower.contains("继续") || lower.contains("continue") ||
           lower.contains("前行") || lower.contains("ahead") {
            return ("继续直行", "arrow.up")
        }
        
        // 其他特殊指令（环岛、合流、出口等）全部默认为直行
        if lower.contains("环岛") || lower.contains("roundabout") ||
           lower.contains("合流") || lower.contains("merge") || lower.contains("并线") ||
           lower.contains("出口") || lower.contains("exit") || lower.contains("驶出") {
            return ("继续直行", "arrow.up")
        }
        
        // 无法解析
        return nil
    }
    
    // 从路线step计算转向方向 - 简化版
    private func calculateTurnDirectionFromStep(_ step: MKRoute.Step, previousStep: MKRoute.Step?) -> (instruction: String, icon: String) {
        guard step.polyline.pointCount >= 2 else {
            return ("继续前进", "arrow.up")
        }
        
        let points = step.polyline.points()
        
        // 如果有前一个step，使用前一个step的结束点作为起点
        let startCoord: CLLocationCoordinate2D
        if let prevStep = previousStep, prevStep.polyline.pointCount > 0 {
            let prevPoints = prevStep.polyline.points()
            startCoord = prevPoints[prevStep.polyline.pointCount - 1].coordinate
        } else {
            startCoord = points[0].coordinate
        }
        
        // 使用当前step的中点和结束点
        let midIndex = step.polyline.pointCount / 2
        let midCoord = points[midIndex].coordinate
        let endCoord = points[step.polyline.pointCount - 1].coordinate
        
        
        let turnDirection = calculatePreciseTurnDirection(previous: startCoord, current: midCoord, next: endCoord)
        
        return (turnDirection.instruction, turnDirection.icon)
    }
    
    // 精确的转向计算 - 简化版
    private func calculatePreciseTurnDirection(previous: CLLocationCoordinate2D, current: CLLocationCoordinate2D, next: CLLocationCoordinate2D) -> TurnDirection {
        // 计算从前一个点到当前点的方位角
        let bearing1 = calculateGeographicBearing(from: previous, to: current)
        
        // 计算从当前点到下一个点的方位角
        let bearing2 = calculateGeographicBearing(from: current, to: next)
        
        // 计算角度变化（标准化到-180到180度之间）
        let rawAngleDiff = bearing2 - bearing1
        let angleDiff = normalizeAngle(rawAngleDiff)
        
        
        // 根据角度差确定转向类型 - 简化为四种基本转向
        let turnDirection: TurnDirection
        let absAngle = abs(angleDiff)
        
        if absAngle < 45 {
            turnDirection = .straight
        } else if absAngle < 135 {
            turnDirection = angleDiff > 0 ? .right : .left
        } else {
            turnDirection = .uTurn
        }
        
        return turnDirection
    }
    
    // 计算地理方位角
    private func calculateGeographicBearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let lat1 = start.latitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let deltaLon = (end.longitude - start.longitude) * .pi / 180
        
        let x = sin(deltaLon) * cos(lat2)
        let y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        
        let bearing = atan2(x, y)
        
        // 转换为0-360度，北为0度，顺时针为正
        return fmod(bearing * 180 / .pi + 360, 360)
    }
    
    // 标准化角度到-180到180度之间
    private func normalizeAngle(_ angle: Double) -> Double {
        var normalized = angle
        while normalized > 180 {
            normalized -= 360
        }
        while normalized < -180 {
            normalized += 360
        }
        return normalized
    }
}
