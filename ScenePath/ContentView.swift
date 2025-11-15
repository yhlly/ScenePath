//  ContentView.swift

import SwiftUI
import MapKit
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var collectionManager: CollectionManager?
    
    @State private var currentState: AppState = .search
    @State private var startLocation = ""
    @State private var endLocation = ""
    @State private var selectedStartLocation: LocationSuggestion?
    @State private var selectedEndLocation: LocationSuggestion?
    @State private var selectedTransportType: TransportationType = .driving
    @State private var routes: [TransportationType: [RouteInfo]] = [:]
    @State private var selectedRoute: RouteInfo?
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var errorMessage = ""
    @State private var startCoordinate: CLLocationCoordinate2D?
    @State private var endCoordinate: CLLocationCoordinate2D?
    @State private var currentLocationIndex = 0
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    // 特殊路线状态
    @State private var selectedSpecialRoute: SpecialRouteType = .none
    
    // 控制收集页面的显示
    @State private var showingCollection = false
    
    var body: some View {
        NavigationView {
            switch currentState {
            case .search:
                ZStack {
                    // 主要搜索视图 - 使用ZStack设置z-index确保正确显示顺序
                    SearchRouteView(
                        startLocation: $startLocation,
                        endLocation: $endLocation,
                        selectedStartLocation: $selectedStartLocation,
                        selectedEndLocation: $selectedEndLocation,
                        selectedTransportType: $selectedTransportType,
                        routes: $routes,
                        isSearching: $isSearching,
                        hasSearched: $hasSearched,
                        errorMessage: $errorMessage,
                        selectedSpecialRoute: $selectedSpecialRoute,
                        onRouteSelected: { route in
                            selectedRoute = route
                            currentLocationIndex = 0
                            currentState = .routePreview
                        },
                        onSearchRoutes: {
                            searchAllRoutes()
                        }
                    )
                    .zIndex(1) // 搜索视图的z-index
                    
                    // 收藏按钮 - 移到右下角避免与其他元素重叠
                    VStack {
                        Spacer() // 推到底部
                        
                        HStack {
                            Spacer() // 推到右边
                            
                            Button(action: {
                                showingCollection = true
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "bag.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                    
                                    if let manager = collectionManager {
                                        Text("\(manager.getCollectionStats().total)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(12)
                                .background(
                                    Circle()
                                        .fill(Color.blue)
                                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                                )
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, hasSearched ? 120 : 30) // 当显示路线时增加底部间距
                        }
                    }
                    .zIndex(50) // 确保收藏按钮在最上层
                }
                .sheet(isPresented: $showingCollection) {
                    if let manager = collectionManager {
                        CollectionView(collectionManager: manager)
                    } else {
                        // 显示加载视图
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("正在加载收集数据...")
                                .padding(.top)
                        }
                    }
                }
                
            case .routePreview:
                RoutePreviewView(
                    selectedRoute: selectedRoute,
                    region: $region,
                    startCoordinate: $startCoordinate,
                    endCoordinate: $endCoordinate,
                    onBackTapped: {
                        currentState = .search
                    },
                    onPlayTapped: {
                        currentState = .arNavigation
                    },
                    onSimulateTapped: {
                        currentState = .routeSimulation
                    }
                )
            case .routeSimulation:
                // 路线模拟视图
                if let route = selectedRoute {
                    RouteSimulationView(
                        route: route,
                        region: $region,
                        startCoordinate: $startCoordinate,
                        endCoordinate: $endCoordinate,
                        onBackTapped: {
                            currentState = .routePreview
                        },
                        onStartRealNavigation: {
                            currentState = .arNavigation
                        }
                    )
                } else {
                    // 回退处理
                    Text("路线数据不可用")
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                currentState = .routePreview
                            }
                        }
                }
            case .arNavigation:
                if let route = selectedRoute, let manager = collectionManager {
                    EnhancedARNavigationView(
                        route: route,
                        currentLocationIndex: $currentLocationIndex,
                        region: $region,
                        startCoordinate: $startCoordinate,
                        endCoordinate: $endCoordinate,
                        collectionManager: manager,
                        onBackTapped: {
                            currentState = .routePreview
                        }
                    )
                    .onDisappear {
                        // 确保从导航页面离开时，重置相关状态
                        print("导航视图消失，重置状态")
                    }
                } else {
                    // 如果CollectionManager还没初始化，显示加载视图
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("正在初始化收集系统...")
                            .padding(.top)
                        }
                }
            }
        }
        .onTapGesture {
            // 点击任何地方隐藏键盘
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onAppear {
            initializeCollectionManager()
        }
    }
    
    // 初始化收集管理器
    private func initializeCollectionManager() {
        if collectionManager == nil {
            collectionManager = CollectionManager(modelContext: modelContext)
        }
    }
    
    // 搜索所有路线（支持特殊路线）
    func searchAllRoutes() {
        guard let startSuggestion = selectedStartLocation,
              let endSuggestion = selectedEndLocation else {
            errorMessage = "请选择起点和终点"
            return
        }
        
        isSearching = true
        errorMessage = ""
        routes.removeAll()
        hasSearched = false
        
        // 获取起点坐标
        let searchManager = LocationSearchManager()
        searchManager.getCoordinate(for: startSuggestion) { startCoord in
            guard let startCoord = startCoord else {
                DispatchQueue.main.async {
                    self.errorMessage = "无法获取起点坐标"
                    self.isSearching = false
                }
                return
            }
            
            // 获取终点坐标
            searchManager.getCoordinate(for: endSuggestion) { endCoord in
                guard let endCoord = endCoord else {
                    DispatchQueue.main.async {
                        self.errorMessage = "无法获取终点坐标"
                        self.isSearching = false
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.startCoordinate = startCoord
                    self.endCoordinate = endCoord
                    self.calculateRoutesForAllTransportTypes(from: startCoord, to: endCoord)
                }
            }
        }
    }
    
    // 为所有交通方式计算路线（支持特殊路线）
    func calculateRoutesForAllTransportTypes(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) {
        let group = DispatchGroup()
        
        
        for transportType in TransportationType.allCases {
            group.enter()
            
            // 创建特殊路线配置
            let specialConfig = SpecialRouteConfig(
                specialType: selectedSpecialRoute,
                transportType: transportType
            )
            
            
            RouteService.shared.calculateRouteWithSpecialType(
                from: start,
                to: end,
                transportType: transportType,
                specialConfig: specialConfig
            ) { routeInfos in
                DispatchQueue.main.async {
                    self.routes[transportType] = routeInfos
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            for (transport, routeList) in self.routes {
                print("    \(transport.rawValue): \(routeList.count)条路线")
                for (index, route) in routeList.enumerated() {
                    print("      \(index + 1). \(route.type.rawValue) - 特殊类型: \(route.specialRouteType.rawValue)")
                }
            }
            
            self.isSearching = false
            self.hasSearched = true
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: CollectibleItem.self, configurations: config)
    
    return ContentView()
        .modelContainer(container)
}
