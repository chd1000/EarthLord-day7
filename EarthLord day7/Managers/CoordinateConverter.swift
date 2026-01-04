//
//  CoordinateConverter.swift
//  EarthLord day7
//
//  坐标转换工具
//  实现 WGS-84 → GCJ-02 坐标转换，解决中国 GPS 偏移问题
//
//  为什么需要坐标转换？
//  - GPS 硬件返回 WGS-84 坐标（国际标准）
//  - 中国法规要求地图使用 GCJ-02 坐标（加密偏移）
//  - 如果不转换，轨迹会偏移 100-500 米！
//

import Foundation
import CoreLocation

/// 坐标转换工具
/// 提供 WGS-84 与 GCJ-02 之间的转换
struct CoordinateConverter {

    // MARK: - 常量

    /// 长半轴（赤道半径）
    private static let a: Double = 6378245.0

    /// 扁率
    private static let ee: Double = 0.00669342162296594323

    /// 圆周率
    private static let pi: Double = Double.pi

    // MARK: - 公开方法

    /// WGS-84 转 GCJ-02
    /// - Parameter wgs84: WGS-84 坐标（GPS 原始坐标）
    /// - Returns: GCJ-02 坐标（中国地图坐标）
    static func wgs84ToGcj02(_ wgs84: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 如果不在中国范围内，不进行转换
        if isOutOfChina(wgs84) {
            return wgs84
        }

        let lat = wgs84.latitude
        let lon = wgs84.longitude

        // 计算偏移量
        var dLat = transformLat(lon - 105.0, lat - 35.0)
        var dLon = transformLon(lon - 105.0, lat - 35.0)

        let radLat = lat / 180.0 * pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)

        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * pi)

        let gcj02Lat = lat + dLat
        let gcj02Lon = lon + dLon

        return CLLocationCoordinate2D(latitude: gcj02Lat, longitude: gcj02Lon)
    }

    /// GCJ-02 转 WGS-84（近似算法）
    /// - Parameter gcj02: GCJ-02 坐标
    /// - Returns: WGS-84 坐标（近似值）
    static func gcj02ToWgs84(_ gcj02: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 如果不在中国范围内，不进行转换
        if isOutOfChina(gcj02) {
            return gcj02
        }

        // 使用反向偏移近似算法
        let gcj = wgs84ToGcj02(gcj02)
        let dLat = gcj.latitude - gcj02.latitude
        let dLon = gcj.longitude - gcj02.longitude

        return CLLocationCoordinate2D(
            latitude: gcj02.latitude - dLat,
            longitude: gcj02.longitude - dLon
        )
    }

    /// 批量转换 WGS-84 坐标数组到 GCJ-02
    /// - Parameter coordinates: WGS-84 坐标数组
    /// - Returns: GCJ-02 坐标数组
    static func wgs84ToGcj02(_ coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        return coordinates.map { wgs84ToGcj02($0) }
    }

    // MARK: - 私有方法

    /// 判断坐标是否在中国范围外
    /// - Parameter coordinate: 坐标
    /// - Returns: 是否在中国范围外
    private static func isOutOfChina(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let lon = coordinate.longitude
        let lat = coordinate.latitude

        // 中国大致范围：纬度 0.8293~55.8271，经度 72.004~137.8347
        if lon < 72.004 || lon > 137.8347 {
            return true
        }
        if lat < 0.8293 || lat > 55.8271 {
            return true
        }
        return false
    }

    /// 纬度偏移转换
    private static func transformLat(_ x: Double, _ y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * pi) + 320 * sin(y * pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    /// 经度偏移转换
    private static func transformLon(_ x: Double, _ y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0
        return ret
    }
}
