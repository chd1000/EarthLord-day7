//
//  TerritoryMapView.swift
//  EarthLord day7
//
//  领地详情页的地图组件（UIKit）
//  显示领地多边形和建筑标记
//

import SwiftUI
import MapKit
import CoreLocation

/// 领地地图视图
struct TerritoryMapView: UIViewRepresentable {

    // MARK: - 参数

    /// 领地
    let territory: Territory

    /// 领地内的建筑
    let buildings: [PlayerBuilding]

    /// 建筑模板字典
    let buildingTemplates: [String: BuildingTemplate]

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .hybrid
        mapView.showsUserLocation = false
        mapView.delegate = context.coordinator

        // 禁用部分交互以优化性能
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false

        // 绘制领地
        drawTerritory(on: mapView)

        // 绘制建筑
        drawBuildings(on: mapView)

        // 设置初始区域
        setInitialRegion(on: mapView)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 检查建筑数量是否变化
        let currentBuildingAnnotations = mapView.annotations.compactMap { $0 as? TerritoryBuildingAnnotation }
        if currentBuildingAnnotations.count != buildings.count {
            // 重新绘制建筑
            mapView.removeAnnotations(currentBuildingAnnotations)
            drawBuildings(on: mapView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - 私有方法

    /// 绘制领地多边形
    private func drawTerritory(on mapView: MKMapView) {
        let coords = territory.coordinates
        guard coords.count >= 3 else { return }

        // 转换为 GCJ-02 坐标用于显示
        let gcj02Coords = CoordinateConverter.wgs84ToGcj02(coords)

        let polygon = MKPolygon(coordinates: gcj02Coords, count: gcj02Coords.count)
        polygon.title = "territory"
        mapView.addOverlay(polygon)
    }

    /// 绘制建筑
    private func drawBuildings(on mapView: MKMapView) {
        for building in buildings {
            guard let coord = building.coordinate else { continue }

            // 数据库中的建筑坐标已经是 GCJ-02，直接使用
            let annotation = TerritoryBuildingAnnotation(
                coordinate: coord,
                building: building,
                template: buildingTemplates[building.templateId]
            )
            mapView.addAnnotation(annotation)
        }
    }

    /// 设置初始区域
    private func setInitialRegion(on mapView: MKMapView) {
        let coords = territory.coordinates
        guard !coords.isEmpty else { return }

        // 转换为 GCJ-02
        let gcj02Coords = CoordinateConverter.wgs84ToGcj02(coords)

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

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TerritoryMapView

        init(_ parent: TerritoryMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)

                if polygon.title == "territory" {
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.25)
                    renderer.strokeColor = UIColor.systemGreen
                    renderer.lineWidth = 2
                }

                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let buildingAnnotation = annotation as? TerritoryBuildingAnnotation else {
                return nil
            }

            let identifier = "TerritoryBuilding"
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
                view?.markerTintColor = .systemOrange
            }

            // 设置图标
            if let template = buildingAnnotation.template {
                view?.glyphImage = UIImage(systemName: template.icon)
            } else {
                view?.glyphImage = UIImage(systemName: "building.2")
            }

            return view
        }
    }
}

// MARK: - 建筑标注

/// 领地建筑标注
class TerritoryBuildingAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    let building: PlayerBuilding
    let template: BuildingTemplate?

    var title: String? {
        building.buildingName
    }

    var subtitle: String? {
        if building.statusEnum == .constructing {
            return building.formattedRemainingTime
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
    TerritoryMapView(
        territory: Territory(
            id: UUID(),
            userId: UUID(),
            name: "测试领地",
            path: "[[30.5, 121.4], [30.51, 121.4], [30.51, 121.41], [30.5, 121.41]]",
            polygon: nil,
            bboxMinLat: 30.5,
            bboxMaxLat: 30.51,
            bboxMinLon: 121.4,
            bboxMaxLon: 121.41,
            area: 1000,
            pointCount: 4,
            startedAt: nil,
            completedAt: nil,
            isActive: true,
            createdAt: Date()
        ),
        buildings: [],
        buildingTemplates: [:]
    )
}
