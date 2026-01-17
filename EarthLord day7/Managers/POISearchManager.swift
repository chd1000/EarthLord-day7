//
//  POISearchManager.swift
//  EarthLord day7
//
//  POI搜索管理器
//  负责使用MKLocalSearch搜索真实世界POI并转换为游戏POI
//

import Foundation
import MapKit
import Combine

/// POI搜索管理器
@MainActor
class POISearchManager: ObservableObject {

    // MARK: - 单例

    static let shared = POISearchManager()

    // MARK: - 发布的状态

    /// 是否正在搜索
    @Published var isSearching: Bool = false

    /// 搜索到的POI列表
    @Published var searchedPOIs: [POI] = []

    /// 错误信息
    @Published var errorMessage: String?

    /// 上次搜索位置
    @Published var lastSearchLocation: CLLocationCoordinate2D?

    /// 上次搜索时间
    @Published var lastSearchTime: Date?

    // MARK: - 私有属性

    /// 搜索半径（米）
    private let searchRadius: CLLocationDistance = 1000

    /// 搜索冷却时间（秒）- 防止频繁搜索
    private let searchCooldown: TimeInterval = 60

    /// 要搜索的POI类别（用于MKLocalPointsOfInterestRequest）
    private let searchCategories: [MKPointOfInterestCategory] = [
        .hospital,
        .pharmacy,
        .gasStation,
        .store,
        .foodMarket,
        .police,
        .fireStation,
        .parking,
        .bank,
        .hotel,
        .restaurant,
        .cafe
    ]

    /// 中文搜索关键词（用于MKLocalSearch文字搜索，在中国效果更好）
    private let searchKeywords: [(keyword: String, type: POIType)] = [
        ("超市", .supermarket),
        ("便利店", .supermarket),
        ("医院", .hospital),
        ("诊所", .hospital),
        ("药店", .pharmacy),
        ("药房", .pharmacy),
        ("加油站", .gasStation),
        ("餐厅", .supermarket),
        ("饭店", .supermarket),
        ("银行", .factory),
        ("酒店", .factory),
        ("宾馆", .factory),
        ("停车场", .warehouse),
        ("工厂", .factory),
        ("仓库", .warehouse)
    ]

    // MARK: - 初始化

    private init() {
        print("🔍 POISearchManager 初始化")
    }

    // MARK: - 公开方法

    /// 搜索附近POI
    /// - Parameters:
    ///   - center: 搜索中心点
    ///   - maxCount: 最大返回POI数量（默认20个）
    /// - Returns: 搜索到的POI数组
    func searchNearbyPOIs(center: CLLocationCoordinate2D, maxCount: Int = 20) async -> [POI] {
        // 检查搜索冷却
        if let lastTime = lastSearchTime,
           Date().timeIntervalSince(lastTime) < searchCooldown {
            print("⚠️ [POI搜索] 搜索冷却中，返回缓存结果")
            return searchedPOIs
        }

        isSearching = true
        errorMessage = nil
        var allPOIs: [POI] = []

        print("🔍 [POI搜索] 开始搜索附近POI，中心点: (\(center.latitude), \(center.longitude))")
        TerritoryLogger.shared.log("开始搜索附近POI", type: .info)

        // 创建搜索区域
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: searchRadius * 2,
            longitudinalMeters: searchRadius * 2
        )

        // 方法1: 使用中文关键词搜索（在中国效果更好）
        await withTaskGroup(of: [POI].self) { group in
            for keywordInfo in searchKeywords {
                group.addTask {
                    await self.searchByKeyword(keywordInfo.keyword, type: keywordInfo.type, in: region, center: center)
                }
            }

            for await pois in group {
                allPOIs.append(contentsOf: pois)
            }
        }

        print("🔍 [POI搜索] 关键词搜索找到 \(allPOIs.count) 个结果")

        // 方法2: 如果关键词搜索没结果，尝试类别搜索
        if allPOIs.isEmpty {
            print("🔍 [POI搜索] 关键词搜索无结果，尝试类别搜索...")
            await withTaskGroup(of: [POI].self) { group in
                for category in searchCategories {
                    group.addTask {
                        await self.searchCategory(category, in: region, center: center)
                    }
                }

                for await pois in group {
                    allPOIs.append(contentsOf: pois)
                }
            }
            print("🔍 [POI搜索] 类别搜索找到 \(allPOIs.count) 个结果")
        }

        // 去重（基于坐标）
        let uniquePOIs = removeDuplicates(allPOIs)

        // 按距离排序
        let sortedPOIs = sortByDistance(uniquePOIs, from: center)

        // 限制数量（根据玩家密度动态调整）
        let limitedPOIs = Array(sortedPOIs.prefix(maxCount))

        // 更新状态
        searchedPOIs = limitedPOIs
        lastSearchLocation = center
        lastSearchTime = Date()
        isSearching = false

        print("🔍 [POI搜索] 完成，找到 \(limitedPOIs.count) 个POI")
        if limitedPOIs.isEmpty {
            TerritoryLogger.shared.log("附近未发现可探索地点", type: .warning)
        } else {
            TerritoryLogger.shared.log("发现 \(limitedPOIs.count) 个附近地点", type: .success)
        }

        return limitedPOIs
    }

    /// 清除搜索结果
    func clearSearchResults() {
        searchedPOIs.removeAll()
        lastSearchLocation = nil
        lastSearchTime = nil
        print("🔍 [POI搜索] 已清除搜索结果")
    }

    // MARK: - 私有方法

    /// 使用关键词搜索POI（中文搜索，在中国效果更好）
    private func searchByKeyword(
        _ keyword: String,
        type: POIType,
        in region: MKCoordinateRegion,
        center: CLLocationCoordinate2D
    ) async -> [POI] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = keyword
        request.region = region

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()

            let pois = response.mapItems.compactMap { mapItem -> POI? in
                guard let location = mapItem.placemark.location else { return nil }

                // 检查是否在搜索半径内
                let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
                let distance = location.distance(from: centerLocation)
                guard distance <= searchRadius else { return nil }

                return convertToGamePOIFromKeyword(mapItem: mapItem, distance: distance, type: type)
            }

            if !pois.isEmpty {
                print("🔍 [POI搜索] 关键词'\(keyword)'找到 \(pois.count) 个结果")
            }
            return pois
        } catch {
            print("❌ [POI搜索] 关键词'\(keyword)'搜索失败: \(error.localizedDescription)")
            return []
        }
    }

    /// 搜索单个类别
    private func searchCategory(
        _ category: MKPointOfInterestCategory,
        in region: MKCoordinateRegion,
        center: CLLocationCoordinate2D
    ) async -> [POI] {
        let request = MKLocalPointsOfInterestRequest(coordinateRegion: region)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [category])

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()

            return response.mapItems.compactMap { mapItem -> POI? in
                guard let location = mapItem.placemark.location else { return nil }

                // 检查是否在搜索半径内
                let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
                let distance = location.distance(from: centerLocation)
                guard distance <= searchRadius else { return nil }

                return convertToGamePOI(mapItem: mapItem, distance: distance, category: category)
            }
        } catch {
            print("❌ [POI搜索] 搜索 \(category.rawValue) 失败: \(error.localizedDescription)")
            return []
        }
    }

    /// 将MKMapItem转换为游戏POI（类别搜索）
    private func convertToGamePOI(
        mapItem: MKMapItem,
        distance: Double,
        category: MKPointOfInterestCategory
    ) -> POI {
        let coordinate = mapItem.placemark.coordinate
        let originalName = mapItem.name ?? "未知地点"

        return POI(
            id: UUID(),
            name: generateGameName(from: originalName, category: category),
            type: mapCategoryToType(category),
            coordinate: POI.Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude),
            status: .discovered,
            hasLoot: generateHasLoot(category: category),
            dangerLevel: generateDangerLevel(category: category),
            description: generateDescription(category: category, originalName: originalName),
            distanceFromUser: distance,
            lastLootedAt: nil
        )
    }

    /// 将MKMapItem转换为游戏POI（关键词搜索）
    private func convertToGamePOIFromKeyword(
        mapItem: MKMapItem,
        distance: Double,
        type: POIType
    ) -> POI {
        let coordinate = mapItem.placemark.coordinate
        let originalName = mapItem.name ?? "未知地点"

        return POI(
            id: UUID(),
            name: generateGameNameFromType(from: originalName, type: type),
            type: type,
            coordinate: POI.Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude),
            status: .discovered,
            hasLoot: generateHasLootFromType(type: type),
            dangerLevel: generateDangerLevelFromType(type: type),
            description: generateDescriptionFromType(type: type, originalName: originalName),
            distanceFromUser: distance,
            lastLootedAt: nil
        )
    }

    /// 生成游戏风格名称（根据类型）
    private func generateGameNameFromType(from originalName: String, type: POIType) -> String {
        return originalName
    }

    /// 根据类型生成是否有物资
    private func generateHasLootFromType(type: POIType) -> Bool {
        let lootProbability: Double
        switch type {
        case .hospital, .pharmacy: lootProbability = 0.85
        case .supermarket: lootProbability = 0.80
        case .gasStation: lootProbability = 0.70
        case .police, .military: lootProbability = 0.60
        case .warehouse, .factory: lootProbability = 0.65
        case .house: lootProbability = 0.50
        }
        return Double.random(in: 0...1) < lootProbability
    }

    /// 根据类型生成危险等级
    private func generateDangerLevelFromType(type: POIType) -> Int {
        switch type {
        case .hospital: return Int.random(in: 3...5)
        case .police, .military: return Int.random(in: 4...5)
        case .pharmacy, .supermarket: return Int.random(in: 1...3)
        case .gasStation: return Int.random(in: 2...4)
        case .warehouse, .factory: return Int.random(in: 2...4)
        case .house: return Int.random(in: 1...2)
        }
    }

    /// 根据类型生成描述
    private func generateDescriptionFromType(type: POIType, originalName: String) -> String {
        switch type {
        case .hospital:
            return "这座曾经救死扶伤的医院如今已成废墟，但可能还残留着珍贵的医疗物资。"
        case .pharmacy:
            return "一家药店的残骸，药架已经倾倒，但仔细搜寻可能还能找到一些有用的药品。"
        case .gasStation:
            return "废弃的加油站，油罐可能已经干涸，但便利店区域或许还有一些生存物资。"
        case .supermarket:
            return "曾经热闹的商场如今空无一人，货架大多已被搜刮，但角落里可能还藏着被遗忘的物资。"
        case .police:
            return "警察局废墟，这里曾是秩序的象征，现在可能还有一些防护装备或工具。"
        case .warehouse:
            return "一座废弃的仓库，铁门已经锈蚀。里面可能还有一些被遗忘的物资。"
        case .factory:
            return "荒废的工厂，机器早已停转。小心可能存在的危险，但或许能找到有用的工具。"
        case .house:
            return "一栋破旧的民居，窗户已经破碎。或许能找到一些生活用品。"
        case .military:
            return "一处废弃的军事设施，危险但可能有稀有物资。"
        }
    }

    /// 生成游戏风格名称
    private func generateGameName(from originalName: String, category: MKPointOfInterestCategory) -> String {
        return originalName
    }

    /// 映射Apple地图分类到游戏POI类型
    private func mapCategoryToType(_ category: MKPointOfInterestCategory) -> POIType {
        switch category {
        case .hospital: return .hospital
        case .pharmacy: return .pharmacy
        case .gasStation: return .gasStation
        case .store, .foodMarket: return .supermarket
        case .police: return .police
        case .fireStation: return .warehouse
        case .parking: return .house
        case .bank, .hotel: return .factory
        case .restaurant, .cafe: return .supermarket
        default: return .house
        }
    }

    /// 根据类别生成是否有物资
    private func generateHasLoot(category: MKPointOfInterestCategory) -> Bool {
        let lootProbability: Double
        switch category {
        case .hospital, .pharmacy: lootProbability = 0.85
        case .store, .foodMarket: lootProbability = 0.80
        case .gasStation: lootProbability = 0.70
        case .police: lootProbability = 0.60
        case .restaurant, .cafe: lootProbability = 0.65
        default: lootProbability = 0.50
        }
        return Double.random(in: 0...1) < lootProbability
    }

    /// 根据类别生成危险等级
    private func generateDangerLevel(category: MKPointOfInterestCategory) -> Int {
        switch category {
        case .hospital: return Int.random(in: 3...5)
        case .police: return Int.random(in: 4...5)
        case .pharmacy, .store: return Int.random(in: 1...3)
        case .gasStation: return Int.random(in: 2...4)
        case .restaurant, .cafe: return Int.random(in: 1...2)
        default: return Int.random(in: 1...3)
        }
    }

    /// 生成描述
    private func generateDescription(category: MKPointOfInterestCategory, originalName: String) -> String {
        switch category {
        case .hospital:
            return "这座曾经救死扶伤的医院如今已成废墟，但可能还残留着珍贵的医疗物资。警惕，这里可能有其他幸存者或更危险的东西。"
        case .pharmacy:
            return "一家小型药店的残骸，药架已经倾倒，但仔细搜寻可能还能找到一些有用的药品。"
        case .gasStation:
            return "废弃的加油站，油罐可能已经干涸，但便利店区域或许还有一些生存物资。"
        case .store, .foodMarket:
            return "曾经热闹的商场如今空无一人，货架大多已被搜刮，但角落里可能还藏着被遗忘的物资。"
        case .police:
            return "警察局废墟，这里曾是秩序的象征，现在可能还有一些防护装备或工具。但要小心，这里的危险等级很高。"
        case .restaurant, .cafe:
            return "一家废弃的餐厅，厨房里可能还有一些保存完好的食物和饮用水。"
        default:
            return "一处废弃的建筑，在末日的废墟中，任何地方都可能藏有生存物资，但也伴随着未知的危险。"
        }
    }

    /// 去重（基于坐标）
    private func removeDuplicates(_ pois: [POI]) -> [POI] {
        var seen = Set<String>()
        return pois.filter { poi in
            let key = "\(poi.coordinate.latitude.rounded(toPlaces: 5)),\(poi.coordinate.longitude.rounded(toPlaces: 5))"
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
    }

    /// 按距离排序
    private func sortByDistance(_ pois: [POI], from center: CLLocationCoordinate2D) -> [POI] {
        return pois.sorted { poi1, poi2 in
            (poi1.distanceFromUser ?? Double.infinity) < (poi2.distanceFromUser ?? Double.infinity)
        }
    }
}

// MARK: - Double扩展

extension Double {
    /// 四舍五入到指定小数位
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
