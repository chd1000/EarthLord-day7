//
//  MapViewRepresentable.swift
//  EarthLord day7
//
//  MKMapView 的 SwiftUI 包装器
//  负责显示地图、应用末世滤镜、处理用户位置更新、轨迹渲染、闭环多边形填充
//

import SwiftUI
import MapKit

/// MKMapView 的 SwiftUI 包装器
struct MapViewRepresentable: UIViewRepresentable {

    // MARK: - 绑定属性（基础定位）

    /// 用户位置坐标（双向绑定）
    @Binding var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位（防止重复居中）
    @Binding var hasLocatedUser: Bool

    /// 是否需要重新居中到用户位置
    @Binding var shouldRecenter: Bool

    // MARK: - 绑定属性（路径追踪）

    /// 追踪路径坐标数组（WGS-84 原始坐标）
    @Binding var trackingPath: [CLLocationCoordinate2D]

    /// 路径更新版本号（用于触发更新）
    var pathUpdateVersion: Int

    /// 是否正在追踪
    var isTracking: Bool

    /// 路径是否已闭合
    var isPathClosed: Bool

    // MARK: - 绑定属性（探索轨迹）

    /// 探索轨迹坐标数组（WGS-84 原始坐标）
    @Binding var explorationPath: [CLLocationCoordinate2D]

    /// 探索轨迹更新版本号
    var explorationPathUpdateVersion: Int

    /// 是否正在探索追踪
    var isExplorationTracking: Bool

    // MARK: - 领地显示属性

    /// 已加载的领地列表
    var territories: [Territory]

    /// 当前用户 ID（用于区分我的领地和他人领地）
    var currentUserId: String?

    // MARK: - 常量

    /// 轨迹线的 overlay 标识符
    private static let trackingOverlayIdentifier = "trackingPath"

    /// 闭环多边形的 overlay 标识符
    private static let polygonOverlayIdentifier = "closedPolygon"

    /// 探索轨迹的 overlay 标识符
    private static let explorationOverlayIdentifier = "explorationPath"

    /// 我的领地 overlay 标识符
    private static let myTerritoryIdentifier = "mine"

    /// 他人领地 overlay 标识符
    private static let othersTerritoryIdentifier = "others"

    // MARK: - UIViewRepresentable

    /// 创建 MKMapView
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()

        // 配置地图类型：卫星图+道路标签（末世废土风格）
        mapView.mapType = .hybrid

        // 隐藏 POI 标签（商店、餐厅等）
        mapView.pointOfInterestFilter = .excludingAll

        // 隐藏 3D 建筑
        mapView.showsBuildings = false

        // 显示用户位置蓝点（关键！这会触发 MapKit 开始获取位置）
        mapView.showsUserLocation = true

        // 允许地图交互
        mapView.isZoomEnabled = true      // 允许缩放
        mapView.isScrollEnabled = true    // 允许拖动
        mapView.isRotateEnabled = true    // 允许旋转
        mapView.isPitchEnabled = true     // 允许倾斜

        // 显示指南针
        mapView.showsCompass = true

        // 设置代理（关键！否则 didUpdate userLocation 和 rendererFor overlay 不会被调用）
        mapView.delegate = context.coordinator

        // 应用末世滤镜效果
        applyApocalypseFilter(to: mapView)

        print("🗺️ MKMapView 创建完成")

        return mapView
    }

    /// 更新 MKMapView
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 检查是否需要重新居中
        if shouldRecenter, let location = userLocation {
            let region = MKCoordinateRegion(
                center: location,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
            mapView.setRegion(region, animated: true)

            // 重置标志
            DispatchQueue.main.async {
                shouldRecenter = false
            }
        }

        // 更新轨迹路径
        updateTrackingPath(on: mapView, context: context)

        // 更新探索轨迹
        updateExplorationPath(on: mapView, context: context)

        // 绘制已加载的领地
        drawTerritories(on: mapView, context: context)
    }

    /// 创建 Coordinator
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - 轨迹渲染

    /// 更新轨迹路径显示
    private func updateTrackingPath(on mapView: MKMapView, context: Context) {
        // 检查版本号是否变化（避免不必要的更新）
        guard context.coordinator.lastPathVersion != pathUpdateVersion else {
            return
        }
        context.coordinator.lastPathVersion = pathUpdateVersion

        // 更新闭环状态（用于渲染器判断颜色）
        context.coordinator.isPathClosed = isPathClosed

        // 移除旧的轨迹 overlay 和多边形
        let oldOverlays = mapView.overlays.filter { overlay in
            if let polyline = overlay as? MKPolyline {
                return polyline.title == Self.trackingOverlayIdentifier
            }
            if let polygon = overlay as? MKPolygon {
                return polygon.title == Self.polygonOverlayIdentifier
            }
            return false
        }
        mapView.removeOverlays(oldOverlays)

        // 如果路径点少于 2 个，不绘制
        guard trackingPath.count >= 2 else {
            print("🛤️ 路径点不足 2 个，跳过绘制")
            return
        }

        // ⭐ 关键：将 WGS-84 坐标转换为 GCJ-02 坐标
        // 这样轨迹才能显示在正确的位置（不会偏移 100-500 米）
        let gcj02Coordinates = CoordinateConverter.wgs84ToGcj02(trackingPath)

        // 如果已闭环且点数 >= 3，先添加多边形填充（在轨迹线下方）
        if isPathClosed && gcj02Coordinates.count >= 3 {
            let polygon = MKPolygon(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
            polygon.title = Self.polygonOverlayIdentifier
            mapView.addOverlay(polygon)
            print("🟢 添加闭环多边形填充，共 \(gcj02Coordinates.count) 个点")
        }

        // 创建 MKPolyline（轨迹线）
        let polyline = MKPolyline(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
        polyline.title = Self.trackingOverlayIdentifier

        // 添加到地图（在多边形上方）
        mapView.addOverlay(polyline)

        print("🛤️ 轨迹更新完成，共 \(trackingPath.count) 个点，闭环: \(isPathClosed)")
    }

    // MARK: - 探索轨迹渲染

    /// 更新探索轨迹显示
    private func updateExplorationPath(on mapView: MKMapView, context: Context) {
        // 检查版本号是否变化（避免不必要的更新）
        guard context.coordinator.lastExplorationPathVersion != explorationPathUpdateVersion else {
            return
        }
        context.coordinator.lastExplorationPathVersion = explorationPathUpdateVersion

        // 更新探索状态（用于渲染器判断）
        context.coordinator.isExplorationTracking = isExplorationTracking

        // 移除旧的探索轨迹 overlay
        let oldOverlays = mapView.overlays.filter { overlay in
            if let polyline = overlay as? MKPolyline {
                return polyline.title == Self.explorationOverlayIdentifier
            }
            return false
        }
        mapView.removeOverlays(oldOverlays)

        // 检查是否在探索中且有足够的点
        guard isExplorationTracking, explorationPath.count >= 2 else {
            return
        }

        // WGS-84 → GCJ-02 坐标转换
        let gcj02Coordinates = CoordinateConverter.wgs84ToGcj02(explorationPath)

        // 创建轨迹线
        let polyline = MKPolyline(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
        polyline.title = Self.explorationOverlayIdentifier
        mapView.addOverlay(polyline)

        print("🔍 探索轨迹更新，共 \(explorationPath.count) 个点")
    }

    // MARK: - 领地绘制

    /// 在地图上绘制已加载的领地
    private func drawTerritories(on mapView: MKMapView, context: Context) {
        // 检查领地数量是否变化（避免不必要的重绘）
        guard context.coordinator.lastTerritoriesCount != territories.count else {
            return
        }
        context.coordinator.lastTerritoriesCount = territories.count

        // 移除旧的领地多边形（保留路径轨迹和闭环多边形）
        let territoryOverlays = mapView.overlays.filter { overlay in
            if let polygon = overlay as? MKPolygon {
                return polygon.title == Self.myTerritoryIdentifier ||
                       polygon.title == Self.othersTerritoryIdentifier
            }
            return false
        }
        mapView.removeOverlays(territoryOverlays)

        // 如果没有领地，直接返回
        guard !territories.isEmpty else {
            print("🗺️ 没有领地需要绘制")
            return
        }

        // 绘制每个领地
        for territory in territories {
            // 获取坐标
            var coords = territory.coordinates

            // 坐标点数不足，跳过
            guard coords.count >= 3 else {
                print("⚠️ 领地 \(territory.id) 坐标点不足，跳过")
                continue
            }

            // ⚠️ 中国大陆需要坐标转换（WGS-84 → GCJ-02）
            coords = CoordinateConverter.wgs84ToGcj02(coords)

            // 创建多边形
            let polygon = MKPolygon(coordinates: coords, count: coords.count)

            // ⚠️ 关键：比较 userId 时必须统一大小写！
            // 数据库存的可能是小写 UUID，但 iOS 的 uuidString 返回大写
            let isMine = territory.userId.uuidString.lowercased() == currentUserId?.lowercased()
            polygon.title = isMine ? Self.myTerritoryIdentifier : Self.othersTerritoryIdentifier

            // 添加到地图（在道路上方）
            mapView.addOverlay(polygon, level: .aboveRoads)
        }

        print("🗺️ 绘制了 \(territories.count) 个领地")
    }

    // MARK: - 末世滤镜

    /// 应用末世废土风格滤镜
    private func applyApocalypseFilter(to mapView: MKMapView) {
        // 色调控制滤镜：降低饱和度和亮度
        guard let colorControls = CIFilter(name: "CIColorControls") else {
            print("⚠️ 无法创建 CIColorControls 滤镜")
            return
        }
        colorControls.setValue(-0.15, forKey: kCIInputBrightnessKey)  // 稍微变暗
        colorControls.setValue(0.5, forKey: kCIInputSaturationKey)    // 降低饱和度

        // 棕褐色调滤镜：废土的泛黄效果
        guard let sepiaFilter = CIFilter(name: "CISepiaTone") else {
            print("⚠️ 无法创建 CISepiaTone 滤镜")
            return
        }
        sepiaFilter.setValue(0.65, forKey: kCIInputIntensityKey)  // 泛黄强度

        // 应用滤镜到地图图层
        mapView.layer.filters = [colorControls, sepiaFilter]

        print("🎨 末世滤镜应用完成")
    }

    // MARK: - Coordinator

    /// Coordinator 类：处理 MKMapView 代理回调
    class Coordinator: NSObject, MKMapViewDelegate {

        /// 父视图引用
        var parent: MapViewRepresentable

        /// 是否已完成首次居中（防止重复居中）
        private var hasInitialCentered = false

        /// 上次更新的路径版本号（用于检测变化）
        var lastPathVersion: Int = -1

        /// 路径是否已闭合（用于渲染器判断颜色）
        var isPathClosed: Bool = false

        /// 上次绘制的领地数量（用于检测变化）
        var lastTerritoriesCount: Int = -1

        /// 上次更新的探索轨迹版本号
        var lastExplorationPathVersion: Int = -1

        /// 是否正在探索追踪（用于渲染器判断）
        var isExplorationTracking: Bool = false

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        // MARK: - MKMapViewDelegate

        /// ⭐ 关键方法：用户位置更新时调用
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // 获取用户位置
            guard let location = userLocation.location else { return }

            // 更新绑定的位置坐标
            DispatchQueue.main.async {
                self.parent.userLocation = location.coordinate
            }

            // 如果已经完成首次居中，不再自动居中
            guard !hasInitialCentered else { return }

            print("📍 首次获得用户位置，自动居中地图")

            // 创建居中区域（约1公里范围）
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )

            // 平滑居中地图
            mapView.setRegion(region, animated: true)

            // 标记已完成首次居中
            hasInitialCentered = true

            // 更新外部状态
            DispatchQueue.main.async {
                self.parent.hasLocatedUser = true
            }
        }

        /// ⭐⭐⭐ 关键方法：为 overlay 提供渲染器
        /// 如果不实现这个方法，轨迹添加了也看不见！
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // 处理多边形（领地或闭环轨迹）
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                // 根据多边形标题选择颜色
                if polygon.title == "mine" {
                    // 我的领地：绿色
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                    renderer.lineWidth = 2.0
                    print("🎨 创建我的领地渲染器: 绿色")
                } else if polygon.title == "others" {
                    // 他人领地：橙色
                    renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemOrange
                    renderer.lineWidth = 2.0
                    print("🎨 创建他人领地渲染器: 橙色")
                } else {
                    // 闭环轨迹多边形：绿色（默认）
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                    renderer.lineWidth = 2.0
                    print("🎨 创建闭环多边形渲染器: 绿色")
                }

                return renderer
            }

            // 处理轨迹线
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                // 探索轨迹：橙色
                if polyline.title == MapViewRepresentable.explorationOverlayIdentifier {
                    renderer.strokeColor = UIColor.systemOrange
                    renderer.lineWidth = 3.0
                    renderer.lineCap = .round
                    renderer.lineJoin = .round
                    renderer.alpha = 0.9
                    return renderer
                }

                // 圈地轨迹：根据闭环状态选择颜色
                if isPathClosed {
                    // 已闭环：绿色轨迹
                    renderer.strokeColor = UIColor.systemGreen
                } else {
                    // 未闭环：青色轨迹
                    renderer.strokeColor = UIColor.systemCyan
                }

                renderer.lineWidth = 4.0
                renderer.lineCap = .round
                renderer.lineJoin = .round

                // 添加半透明效果，让轨迹更有科技感
                renderer.alpha = 0.8

                return renderer
            }

            // 默认渲染器
            return MKOverlayRenderer(overlay: overlay)
        }

        /// 地图区域变化完成
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 可以在这里处理用户手动拖动地图后的逻辑
        }

        /// 地图加载完成
        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            print("🗺️ 地图加载完成")
        }

        /// 地图渲染完成
        func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
            if fullyRendered {
                print("🗺️ 地图渲染完成")
            }
        }

        /// 定位失败
        func mapView(_ mapView: MKMapView, didFailToLocateUserWithError error: Error) {
            print("❌ 地图定位失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - Preview

#Preview {
    MapViewRepresentable(
        userLocation: .constant(nil),
        hasLocatedUser: .constant(false),
        shouldRecenter: .constant(false),
        trackingPath: .constant([]),
        pathUpdateVersion: 0,
        isTracking: false,
        isPathClosed: false,
        explorationPath: .constant([]),
        explorationPathUpdateVersion: 0,
        isExplorationTracking: false,
        territories: [],
        currentUserId: nil
    )
}
