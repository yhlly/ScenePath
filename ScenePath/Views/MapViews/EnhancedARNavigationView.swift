//  EnhancedARNavigationView.swift

import SwiftUI
import ARKit
import SceneKit
import MapKit
import SwiftData

struct EnhancedARNavigationView: View {
    let route: RouteInfo
    @Binding var currentLocationIndex: Int
    @Binding var region: MKCoordinateRegion
    @Binding var startCoordinate: CLLocationCoordinate2D?
    @Binding var endCoordinate: CLLocationCoordinate2D?
    
    let collectionManager: CollectionManager
    let onBackTapped: () -> Void
    
    // 导航状态
    @State private var showingARUnavailable = false
    
    // 实时位置相关
    @StateObject private var locationManager = LocationManager()
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var userHeading: Double = 0
    
    // 收集功能相关
    @State private var showingCollection = false
    @State private var showingCollectionSuccess = false
    @State private var lastCollectedItem: String = ""
    @State private var showingCollectiblePopup = false
    @State private var selectedCollectible: CollectiblePoint?
    
    // 其他UI状态
    @State private var showARContent = true
    @State private var arSessionStatus = "检查AR支持..."
    @State private var routeDeviation: Double? = nil
    @State private var recalculatingRoute = false
    @State private var debugInfo = "实时位置导航模式"
    
    private var currentInstruction: NavigationInstruction? {
        guard currentLocationIndex < route.instructions.count else { return nil }
        return route.instructions[currentLocationIndex]
    }
    
    private var collectiblesInRange: [CollectiblePoint] {
        guard let userLocation = userLocation else { return [] }
        let collectibles = collectionManager.collectiblesInRange(of: userLocation)
        return collectibles
    }
    
    var body: some View {
        ZStack {
            // AR场景或备用视图
            if !ARWorldTrackingConfiguration.isSupported {
                // AR不支持时的备用地图视图
                NavigationMapView(
                    route: route.route,
                    userLocation: $userLocation,
                    startCoordinate: $startCoordinate,
                    endCoordinate: $endCoordinate,
                    currentInstruction: currentInstruction,
                    collectionManager: collectionManager,
                    onCollectibleTapped: { collectible in
                        handleCollectionTapped(collectible)
                    }
                )
                .ignoresSafeArea()
            } else if showARContent {
                // AR导航视图
                EnhancedARSceneView(
                    currentInstruction: Binding(
                        get: { self.currentInstruction },
                        set: { _ in }
                    ),
                    isNavigating: Binding(
                        get: { true },
                        set: { _ in }
                    ),
                    userLocation: $userLocation,
                    collectionManager: collectionManager,
                    route: route,
                    onCollectionTapped: { collectible in
                        handleCollectionTapped(collectible)
                    }
                )
                .ignoresSafeArea()
            } else {
                // 常规地图导航视图（用户手动切换）
                NavigationMapView(
                    route: route.route,
                    userLocation: $userLocation,
                    startCoordinate: $startCoordinate,
                    endCoordinate: $endCoordinate,
                    currentInstruction: currentInstruction,
                    collectionManager: collectionManager,
                    onCollectibleTapped: { collectible in
                        handleCollectionTapped(collectible)
                    }
                )
                .ignoresSafeArea()
            }
            
            // UI叠加层
            VStack {
                // 顶部状态栏
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        // 当前指令快速显示
                        if let instruction = currentInstruction {
                            HStack {
                                Image(systemName: instruction.icon)
                                    .foregroundColor(.blue)
                                Text(instruction.instruction)
                                    .foregroundColor(.white)
                                    .fontWeight(.bold)
                            }
                            .font(.headline)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        // 收集统计按钮
                        Button(action: {
                            showingCollection = true
                        }) {
                            HStack {
                                Image(systemName: "bag")
                                    .foregroundColor(.white)
                                Text("\(collectionManager.getCollectionStats().total)")
                                    .foregroundColor(.white)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
                .padding(.horizontal, 16)
                .padding(.top, 60)
                
                // 路线偏离警告
                if let deviation = routeDeviation, deviation > 50 {
                    RouteDeviationWarning(
                        deviation: deviation,
                        onRecalculate: {
                            recalculateRoute()
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                Spacer()
                
                // 中间区域：大号导航指令（确保用户能看到）
                if let instruction = currentInstruction {
                    VStack(spacing: 16) {
                        // 大号方向箭头
                        Image(systemName: instruction.icon)
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.blue)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 120, height: 120)
                            )
                            .shadow(color: .blue.opacity(0.5), radius: 10)
                        
                        // 指令文字
                        VStack(spacing: 8) {
                            Text(instruction.instruction)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("在 \(instruction.distance) 处")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                        )
                        
                        // 进度指示
                        HStack {
                            ForEach(0..<min(route.instructions.count, 10), id: \.self) { index in
                                Circle()
                                    .fill(index == currentLocationIndex ? Color.blue : Color.white.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                            
                            if route.instructions.count > 10 {
                                Text("...")
                                    .foregroundColor(.white.opacity(0.6))
                                    .font(.caption)
                            }
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
                
                Spacer()
                
                // 收集点距离指示器
                if !collectiblesInRange.isEmpty {
                    CollectibleDistanceIndicator(
                        collectibles: collectiblesInRange,
                        userLocation: userLocation
                    )
                    .padding(.horizontal)
                }
                
                // 底部控制栏
                HStack(spacing: 20) {
                    // 返回按钮
                    Button(action: {
                        onBackTapped()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.red, lineWidth: 2)
                                    )
                            )
                    }
                    
                    Spacer()
                    
                    // 当前位置重置按钮
                    Button(action: {
                        centerMapOnUserLocation()
                    }) {
                        Image(systemName: "location.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.blue, lineWidth: 2)
                                    )
                            )
                    }
                    
                    Spacer()
                    
                    // AR开关按钮
                    Button(action: {
                        withAnimation(.spring()) {
                            showARContent.toggle()
                        }
                    }) {
                        Image(systemName: showARContent ? "arkit" : "map")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .stroke(showARContent ? Color.blue : Color.gray, lineWidth: 2)
                                    )
                            )
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
            }
            
            // 收集成功提示
            if showingCollectionSuccess {
                VStack {
                    Spacer()
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        
                        Text("收集成功：\(lastCollectedItem)")
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    .padding(.bottom, 200)
                    
                    Spacer()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // 路线重新计算加载指示器
            if recalculatingRoute {
                ZStack {
                    Color.black.opacity(0.5)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text("重新计算路线...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(30)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                }
            }
        }
        .sheet(isPresented: $showingCollection) {
            CollectionView(collectionManager: collectionManager)
        }
        .sheet(isPresented: $showingCollectiblePopup) {
            if let collectible = selectedCollectible {
                CollectibleInfoPopup(
                    collectible: collectible,
                    onCollect: {
                        handleCollectionTapped(collectible)
                    },
                    onDismiss: {
                        showingCollectiblePopup = false
                    }
                )
            }
        }
        .onAppear {
            setupLocationManager()
            setupCollectionManager()
        }
        .onDisappear {
            // 停止导航模式
            locationManager.stopNavigation()
        }
        .onChange(of: locationManager.currentLocation) { oldValue, newValue in
            if let newLocation = newValue {
                // 更新用户位置
                userLocation = newLocation
                
                // 更新导航相关信息
                handleLocationUpdate(newLocation)
            }
        }
        .onChange(of: locationManager.heading) { oldValue, newValue in
            if let heading = newValue {
                userHeading = heading.trueHeading
            }
        }
    }
    
    
    // 初始化位置管理器
    private func setupLocationManager() {
        // 请求位置权限
        locationManager.requestLocation()
        
        // 启动导航模式
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            locationManager.startNavigation()
        }
    }
    
    // 处理位置更新
    private func handleLocationUpdate(_ location: CLLocationCoordinate2D) {
        // 更新收集器位置
        collectionManager.updateLocation(location)
        
        // 检测用户是否接近下一个导航点
        checkIfNearNextNavigationPoint()
        
        // 检测用户是否偏离路线
        checkRouteDeviation()
    }
    
    // 检查是否接近下一个导航点
    private func checkIfNearNextNavigationPoint() {
        guard currentLocationIndex < route.instructions.count,
              let userLocation = userLocation else { return }
        
        let currentInstruction = route.instructions[currentLocationIndex]
        let instructionCoordinate = currentInstruction.coordinate
        
        // 计算用户到当前导航点的距离
        let userLoc = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let targetLoc = CLLocation(latitude: instructionCoordinate.latitude, longitude: instructionCoordinate.longitude)
        let distance = userLoc.distance(from: targetLoc)
        
        // 如果接近当前导航点（在30米内），自动进入下一个导航点
        if distance < 30 && currentLocationIndex < route.instructions.count - 1 {
            withAnimation(.easeInOut) {
                currentLocationIndex += 1
            }
        }
    }
    
    // 检测路线偏离
    private func checkRouteDeviation() {
        guard let userLocation = userLocation,
              let route = route.route else { return }
        
        // 找到路线上最近的点
        if let routeInfo = locationManager.findClosestPointOnRoute(route: route) {
            let deviation = routeInfo.distance
            
            // 更新偏离状态
            routeDeviation = deviation
            
            // 如果偏离超过200米，建议重新计算路线
            if deviation > 200 && !recalculatingRoute {
            }
        }
    }
    
    // 路线重新计算
    private func recalculateRoute() {
        guard let userLocation = userLocation,
              let endCoord = endCoordinate else { return }
        
        recalculatingRoute = true
        
        // 模拟路线重新计算（实际应用中应该调用地图服务API）
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // 重置偏离状态
            routeDeviation = nil
            recalculatingRoute = false
            
            // 假设我们有了新路线，重置导航索引
            currentLocationIndex = 0
            
            // 如果你有实际的路线重新计算服务，应该在这里调用它
        }
    }
    
    // 将地图中心设置到用户位置
    private func centerMapOnUserLocation() {
        guard let userLocation = userLocation else { return }
        
        withAnimation {
            region = MKCoordinateRegion(
                center: userLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            )
        }
    }
    
    
    // 设置收集管理器
    private func setupCollectionManager() {
        collectionManager.generateCollectiblePoints(for: route.specialRouteType, instructions: route.instructions)
    }
    
    // 处理收集点点击
    private func handleCollectionTapped(_ collectible: CollectiblePoint) {
        if collectible.isCollected {
            return
        }
        
        collectionManager.collectItem(collectible, routeType: route.specialRouteType)
        
        lastCollectedItem = collectible.name
        withAnimation(.easeInOut(duration: 0.3)) {
            showingCollectionSuccess = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingCollectionSuccess = false
            }
        }
    }
}


// 路线偏离警告组件
struct RouteDeviationWarning: View {
    let deviation: Double
    let onRecalculate: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("偏离路线")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("当前偏离约\(Int(deviation))米")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            Button("重新规划") {
                onRecalculate()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.blue)
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.7))
        )
    }
}

// 导航地图视图
struct NavigationMapView: UIViewRepresentable {
    let route: MKRoute?
    @Binding var userLocation: CLLocationCoordinate2D?
    @Binding var startCoordinate: CLLocationCoordinate2D?
    @Binding var endCoordinate: CLLocationCoordinate2D?
    let currentInstruction: NavigationInstruction?
    let collectionManager: CollectionManager
    let onCollectibleTapped: (CollectiblePoint) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.showsTraffic = true
        mapView.showsBuildings = true
        mapView.pointOfInterestFilter = .includingAll
        
        // 启用跟踪模式
        mapView.userTrackingMode = .followWithHeading
        
        // 设置3D地图
        let camera = MKMapCamera()
        camera.pitch = 45 // 倾斜角度
        camera.altitude = 500 // 高度（米）
        mapView.camera = camera
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 清除现有覆盖物和标注
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        
        // 添加路线
        if let route = route {
            mapView.addOverlay(route.polyline)
            
            // 设置地图区域以显示路线
            let rect = route.polyline.boundingMapRect
            mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 100, right: 40), animated: true)
        }
        
        // 添加起点和终点标注
        if let start = startCoordinate {
            let startAnnotation = MKPointAnnotation()
            startAnnotation.coordinate = start
            startAnnotation.title = "起点"
            mapView.addAnnotation(startAnnotation)
        }
        
        if let end = endCoordinate {
            let endAnnotation = MKPointAnnotation()
            endAnnotation.coordinate = end
            endAnnotation.title = "终点"
            mapView.addAnnotation(endAnnotation)
        }
        
        // 添加当前导航指令标注
        if let instruction = currentInstruction {
            let instructionAnnotation = MKPointAnnotation()
            instructionAnnotation.coordinate = instruction.coordinate
            instructionAnnotation.title = instruction.instruction
            instructionAnnotation.subtitle = instruction.distance
            mapView.addAnnotation(instructionAnnotation)
        }
        
        // 添加收集点
        if let userLocation = userLocation {
            let collectibles = collectionManager.collectiblesInRange(of: userLocation)
            for collectible in collectibles {
                if !collectible.isCollected {
                    let annotation = CollectibleAnnotation(collectible: collectible)
                    mapView.addAnnotation(annotation)
                }
            }
        }
        
        // 如果有用户位置，更新相机
        if let userLocation = userLocation {
            // 只有在用户移动或刚初始化地图时更新相机
            if context.coordinator.shouldUpdateCamera(for: userLocation) {
                let camera = mapView.camera
                camera.centerCoordinate = userLocation
                
                // 保持当前高度和倾斜度
                mapView.setCamera(camera, animated: true)
                
                // 记录上次更新的位置
                context.coordinator.lastUserLocation = userLocation
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: NavigationMapView
        var lastUserLocation: CLLocationCoordinate2D?
        
        init(_ parent: NavigationMapView) {
            self.parent = parent
        }
        
        // 决定是否应该更新相机位置
        func shouldUpdateCamera(for location: CLLocationCoordinate2D) -> Bool {
            // 如果没有上次位置，或者距离上次位置超过10米，则更新
            if let lastLocation = lastUserLocation {
                let lastLoc = CLLocation(latitude: lastLocation.latitude, longitude: lastLocation.longitude)
                let currentLoc = CLLocation(latitude: location.latitude, longitude: location.longitude)
                return lastLoc.distance(from: currentLoc) > 10
            }
            return true
        }
        
        // 路线渲染
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 6
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        // 标注视图
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil // 使用默认用户位置标注
            }
            
            if let collectibleAnnotation = annotation as? CollectibleAnnotation {
                let identifier = "CollectibleAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                
                if view == nil {
                    view = MKMarkerAnnotationView(annotation: collectibleAnnotation, reuseIdentifier: identifier)
                    view?.canShowCallout = true
                    
                    // 添加收集按钮
                    let collectButton = UIButton(type: .contactAdd)
                    collectButton.tintColor = .systemGreen
                    view?.rightCalloutAccessoryView = collectButton
                } else {
                    view?.annotation = collectibleAnnotation
                }
                
                // 设置标注样式
                view?.markerTintColor = colorForCategory(collectibleAnnotation.collectible.category)
                view?.glyphImage = UIImage(systemName: collectibleAnnotation.collectible.category.iconName)
                
                return view
            } else {
                // 普通标注
                let identifier = "StandardAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                
                if view == nil {
                    view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view?.canShowCallout = true
                } else {
                    view?.annotation = annotation
                }
                
                // 根据标题设置不同颜色
                if annotation.title == "起点" {
                    view?.markerTintColor = .systemGreen
                } else if annotation.title == "终点" {
                    view?.markerTintColor = .systemRed
                } else {
                    view?.markerTintColor = .systemBlue
                }
                
                return view
            }
        }
        
        // 点击标注配件
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            if let collectibleAnnotation = view.annotation as? CollectibleAnnotation {
                parent.onCollectibleTapped(collectibleAnnotation.collectible)
            }
        }
        
        // 颜色转换辅助方法
        private func colorForCategory(_ category: CollectibleCategory) -> UIColor {
            switch category.color {
            case "orange": return .systemOrange
            case "green": return .systemGreen
            case "blue": return .systemBlue
            case "purple": return .systemPurple
            case "red": return .systemRed
            default: return .systemGray
            }
        }
    }
}

// 收集点标注类
class CollectibleAnnotation: NSObject, MKAnnotation {
    let collectible: CollectiblePoint
    
    var coordinate: CLLocationCoordinate2D {
        return collectible.coordinate
    }
    
    var title: String? {
        return collectible.name
    }
    
    var subtitle: String? {
        return collectible.category.rawValue
    }
    
    init(collectible: CollectiblePoint) {
        self.collectible = collectible
        super.init()
    }
}
