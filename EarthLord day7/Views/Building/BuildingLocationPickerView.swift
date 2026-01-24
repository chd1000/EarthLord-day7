//
//  BuildingLocationPickerView.swift
//  EarthLord day7
//
//  地图位置选择器
//  使用 UIKit 的 MKMapView 实现
//  显示领地多边形边界、已有建筑、点击选择位置
//

import SwiftUI
import MapKit
import CoreLocation

/// 地图位置选择器视图
struct BuildingLocationPickerView: View {

    // MARK: - 环境

    @Environment(\.dismiss) private var dismiss

    // MARK: - 参数

    /// 领地坐标（WGS-84）
    let territoryCoordinates: [CLLocationCoordinate2D]

    /// 已有建筑
    let existingBuildings: [PlayerBuilding]

    /// 建筑模板字典
    let buildingTemplates: [String: BuildingTemplate]

    /// 选中的坐标（GCJ-02，用于保存到数据库）
    @Binding var selectedCoordinate: CLLocationCoordinate2D?

    // MARK: - 状态

    /// 地图上显示的选中位置（GCJ-02）
    @State private var displayCoordinate: CLLocationCoordinate2D?

    /// 提示消息
    @State private var tipMessage: String?

    // MARK: - 视图

    var body: some View {
        NavigationStack {
            ZStack {
                // 地图
                LocationPickerMapView(
                    territoryCoordinates: territoryCoordinates,
                    existingBuildings: existingBuildings,
                    buildingTemplates: buildingTemplates,
                    selectedCoordinate: $displayCoordinate,
                    tipMessage: $tipMessage
                )
                .ignoresSafeArea(edges: .bottom)

                // 提示消息
                VStack {
                    if let tip = tipMessage {
                        Text(tip)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(.top, 10)
                    }

                    Spacer()

                    // 底部信息栏
                    bottomBar
                }
            }
            .navigationTitle(String(localized: "building_select_location"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "取消")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "确定")) {
                        selectedCoordinate = displayCoordinate
                        dismiss()
                    }
                    .disabled(displayCoordinate == nil)
                }
            }
        }
    }

    // MARK: - 子视图

    /// 底部信息栏
    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)

                if let coord = displayCoordinate {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "building_location_selected"))
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(String(format: "%.6f, %.6f", coord.latitude, coord.longitude))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(String(localized: "building_tap_map_to_select"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - 地图 UIViewRepresentable

/// 位置选择地图（UIKit）
struct LocationPickerMapView: UIViewRepresentable {

    // MARK: - 参数

    /// 领地坐标（WGS-84）
    let territoryCoordinates: [CLLocationCoordinate2D]

    /// 已有建筑
    let existingBuildings: [PlayerBuilding]

    /// 建筑模板字典
    let buildingTemplates: [String: BuildingTemplate]

    /// 选中的坐标
    @Binding var selectedCoordinate: CLLocationCoordinate2D?

    /// 提示消息
    @Binding var tipMessage: String?

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .hybrid
        mapView.showsUserLocation = true
        mapView.delegate = context.coordinator

        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)

        // 初始绘制领地
        drawTerritory(on: mapView)

        // 绘制已有建筑
        drawExistingBuildings(on: mapView)

        // 设置初始区域
        setInitialRegion(on: mapView)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新选中位置标注
        updateSelectedAnnotation(on: mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - 私有方法

    /// 绘制领地多边形
    private func drawTerritory(on mapView: MKMapView) {
        guard territoryCoordinates.count >= 3 else { return }

        // 转换为 GCJ-02 坐标用于显示
        let gcj02Coords = CoordinateConverter.wgs84ToGcj02(territoryCoordinates)

        let polygon = MKPolygon(coordinates: gcj02Coords, count: gcj02Coords.count)
        polygon.title = "territory"
        mapView.addOverlay(polygon)
    }

    /// 绘制已有建筑
    private func drawExistingBuildings(on mapView: MKMapView) {
        for building in existingBuildings {
            guard let coord = building.coordinate else { continue }

            // 数据库中的建筑坐标已经是 GCJ-02，直接使用
            let annotation = BuildingAnnotation(
                coordinate: coord,
                building: building,
                template: buildingTemplates[building.templateId]
            )
            mapView.addAnnotation(annotation)
        }
    }

    /// 设置初始区域
    private func setInitialRegion(on mapView: MKMapView) {
        guard !territoryCoordinates.isEmpty else { return }

        // 计算领地中心和范围
        let gcj02Coords = CoordinateConverter.wgs84ToGcj02(territoryCoordinates)

        var minLat = gcj02Coords[0].latitude
        var maxLat = gcj02Coords[0].latitude
        var minLon = gcj02Coords[0].longitude
        var maxLon = gcj02Coords[0].longitude

        for coord in gcj02Coords {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.5,
            longitudeDelta: (maxLon - minLon) * 1.5
        )

        let region = MKCoordinateRegion(center: center, span: span)
        mapView.setRegion(region, animated: false)
    }

    /// 更新选中位置标注
    private func updateSelectedAnnotation(on mapView: MKMapView) {
        // 移除旧的选中标注
        let oldAnnotations = mapView.annotations.compactMap { $0 as? SelectedLocationAnnotation }
        mapView.removeAnnotations(oldAnnotations)

        // 添加新的选中标注
        if let coord = selectedCoordinate {
            let annotation = SelectedLocationAnnotation(coordinate: coord)
            mapView.addAnnotation(annotation)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: LocationPickerMapView

        /// 领地多边形（GCJ-02 坐标）
        private var territoryPolygonGCJ02: [CLLocationCoordinate2D] {
            CoordinateConverter.wgs84ToGcj02(parent.territoryCoordinates)
        }

        init(_ parent: LocationPickerMapView) {
            self.parent = parent
        }

        /// 处理点击事件
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }

            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

            // 检查点是否在领地多边形内
            if isPointInPolygon(coordinate, polygon: territoryPolygonGCJ02) {
                // 在领地内，设置选中位置
                parent.selectedCoordinate = coordinate
                parent.tipMessage = nil
            } else {
                // 不在领地内，显示提示
                parent.tipMessage = String(localized: "building_location_outside_territory")

                // 2秒后清除提示
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.parent.tipMessage = nil
                }
            }
        }

        /// 射线法判断点是否在多边形内
        private func isPointInPolygon(_ point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
            guard polygon.count >= 3 else { return false }

            var isInside = false
            var j = polygon.count - 1

            for i in 0..<polygon.count {
                let xi = polygon[i].longitude
                let yi = polygon[i].latitude
                let xj = polygon[j].longitude
                let yj = polygon[j].latitude

                if ((yi > point.latitude) != (yj > point.latitude)) &&
                   (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi) {
                    isInside = !isInside
                }
                j = i
            }

            return isInside
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                if polygon.title == "territory" {
                    // 领地多边形
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.2)
                    renderer.strokeColor = UIColor.systemGreen
                    renderer.lineWidth = 2
                }

                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 忽略用户位置
            if annotation is MKUserLocation { return nil }

            // 选中位置标注
            if let selectedAnnotation = annotation as? SelectedLocationAnnotation {
                let identifier = "SelectedLocation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if view == nil {
                    view = MKMarkerAnnotationView(annotation: selectedAnnotation, reuseIdentifier: identifier)
                } else {
                    view?.annotation = selectedAnnotation
                }

                view?.markerTintColor = .systemOrange
                view?.glyphImage = UIImage(systemName: "mappin")
                view?.displayPriority = .required

                return view
            }

            // 已有建筑标注
            if let buildingAnnotation = annotation as? BuildingAnnotation {
                let identifier = "BuildingAnnotation"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if view == nil {
                    view = MKMarkerAnnotationView(annotation: buildingAnnotation, reuseIdentifier: identifier)
                    view?.canShowCallout = true
                } else {
                    view?.annotation = buildingAnnotation
                }

                // 根据建筑状态设置颜色
                if buildingAnnotation.building.statusEnum == .constructing {
                    view?.markerTintColor = .systemBlue
                } else {
                    view?.markerTintColor = .systemGray
                }

                if let template = buildingAnnotation.template {
                    view?.glyphImage = UIImage(systemName: template.icon)
                }

                return view
            }

            return nil
        }
    }
}

// MARK: - 自定义标注

/// 选中位置标注
class SelectedLocationAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D

    var title: String? {
        String(localized: "building_selected_location")
    }

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        super.init()
    }
}

/// 建筑标注
class BuildingAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    let building: PlayerBuilding
    let template: BuildingTemplate?

    var title: String? {
        building.buildingName
    }

    var subtitle: String? {
        if building.statusEnum == .constructing {
            return String(localized: "building_status_constructing")
        }
        return "Lv.\(building.level)"
    }

    init(coordinate: CLLocationCoordinate2D, building: PlayerBuilding, template: BuildingTemplate?) {
        self.coordinate = coordinate
        self.building = building
        self.template = template
        super.init()
    }
}

// MARK: - 预览

#Preview {
    BuildingLocationPickerView(
        territoryCoordinates: [
            CLLocationCoordinate2D(latitude: 30.5, longitude: 121.4),
            CLLocationCoordinate2D(latitude: 30.51, longitude: 121.4),
            CLLocationCoordinate2D(latitude: 30.51, longitude: 121.41),
            CLLocationCoordinate2D(latitude: 30.5, longitude: 121.41)
        ],
        existingBuildings: [],
        buildingTemplates: [:],
        selectedCoordinate: .constant(nil)
    )
}
