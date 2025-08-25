//
//  CLocationManager+Helper.swift
//  kivo
//
//  Created by Артем Стратиенко on 19.04.2025.
//

import Foundation
import CoreLocation
import YandexMapsMobile

// CLLocationManagerDelegate
extension TouchViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = YMKPoint(latitude: locations.last!.coordinate.latitude, longitude: locations.last!.coordinate.longitude)
        
        ROUTE_START_POINT = userLocation!
        
        for region in offlineCacheManager.regions() {
            if region.name.contains("Elektrostal") {
                if ( !isLoadAlready )
                {
                    print("start download region Elektrostal")
                    print("Найден регион: \(region.name), ID: \(region.id)")
                    offlineCacheManager.startDownload(withRegionId: region.id)
                    
                    isLoadAlready = true
                    break
                }
            }
        }
        startingLocation = locations.last
        
        if ( requestPoints.isEmpty )
        {
            requestPoints.insert(YMKRequestPoint(point: userLocation!, type: .viapoint, pointContext: nil), at: 0)
        }
        else
        {
            if ( requestPoints.first?.point.latitude != userLocation?.latitude && requestPoints.first?.point.longitude != userLocation?.longitude )
            {
                requestPoints[0] = YMKRequestPoint(point: userLocation!, type: .viapoint, pointContext: nil)
                createLocationCircle(centr: YMKPoint(latitude: userLocation!.latitude, longitude: userLocation!.longitude))
            }
        }
        
        bearingSimulationLocation = calculateBearing(fromCoordinate: beforLocationSimulation, toCoordinate: CLLocationCoordinate2D(latitude: ROUTE_START_POINT.latitude, longitude: ROUTE_START_POINT.longitude))
        mapView.mapWindow.map.move(
                 with: YMKCameraPosition(target: ROUTE_START_POINT, zoom: 15, azimuth: Float(bearingSimulationLocation), tilt: 0),
                     animationType: YMKAnimation(type: YMKAnimationType.linear, duration: 2),
                     cameraCallback: nil)
                     beforLocationSimulation = CLLocationCoordinate2D(latitude: ROUTE_START_POINT.latitude, longitude: ROUTE_START_POINT.longitude)
    }
    // MARK 3
    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        print(error.localizedDescription)
    }
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading){
        currentMagneticHeading = newHeading
    }
    // MARK 4
    func startLocation() {
        nativeLocationManager.startUpdatingLocation()
        nativeLocationManager.startUpdatingHeading()
    }
    // MARK 5
    func stopLocation() {
        nativeLocationManager.stopUpdatingLocation()
    }
    // Вычисляем направление
    func calculateBearing(fromCoordinate from: CLLocationCoordinate2D,
                          toCoordinate to: CLLocationCoordinate2D) -> Double {
        let fLat = deg2rad(deg: from.latitude)
        let fLng = deg2rad(deg: from.longitude)
        let tLat = deg2rad(deg: to.latitude)
        let tLng = deg2rad(deg: to.longitude)

        let dLng = tLng - fLng
        let y = sin(dLng) * cos(tLat)
        let x = cos(fLat) * sin(tLat) - sin(fLat) * cos(tLat) * cos(dLng)
        let bearing = atan2(y, x)

        return rad2deg(rad: bearing)
    }

    func deg2rad(deg: Double) -> Double {
        return deg * .pi / 180
    }

    func rad2deg(rad: Double) -> Double {
        return rad * 180 / .pi
    }
    func createLocationCircle(centr : YMKPoint ) {
        let mapObjects = mapView.mapWindow.map.mapObjects;
        let circle = mapObjects.addCircle(
            with: YMKCircle(center: centr, radius: 0.5),
            stroke: UIColor.black,
            strokeWidth: 2,
            fill: UIColor.red)
        circle.zIndex = 100
    }
}
