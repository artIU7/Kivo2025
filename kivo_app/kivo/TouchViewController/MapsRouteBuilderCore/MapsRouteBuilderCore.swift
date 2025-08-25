//
//  MapsRouteBuilderCore.swift
//  kivo
//
//  Created by Артем Стратиенко on 19.04.2025.
//

import Foundation
import UIKit
import YandexMapsMobile
import CoreLocation

extension TouchViewController {
   
    func callPedestrianRoutingResponse() {
        
        if ( requestPoints.isEmpty ) {
            return
        }
        let state = offlineCacheManager.getStateWithRegionId(20523)
        let progress = offlineCacheManager.getProgressWithRegionId(20523)
        print("State : \(state)")
        switch state
        {
        case .available:
            print(" state 1")
        case .downloading:
            print(" state 2")
        case .completed:
            print(" state 3")
        case .needUpdate:
            print(" state 4")
        case .outdated:
            print(" state 5")
        case .paused:
            print(" state 5")
        case .unsupported:
            print(" state 6")
        @unknown default:
            print("NOT")
        }
        print("Progress : \(progress)")
        
        let pedestrianRouter = YMKTransport.sharedInstance().createPedestrianRouter()
                pedestrianSession = pedestrianRouter.requestRoutes(with: requestPoints,
                                                                   timeOptions: YMKTimeOptions(),
                routeHandler: { (routesResponse : [YMKMasstransitRoute]?, error :Error?) in
                 if let routes = routesResponse {
                     self.onPedestrianRoutesReceived(routes)
                     if !self.sceneView.isHidden {
                         DispatchQueue.main.async {
                             self.updateARContent()
                             var stringContent = "Маршрут построен!"
                             self.voiceHelperUI(textSpeech: "\(stringContent)")
                             self.words = stringContent.components(separatedBy: " ")
                         }
                     }
                 } else {
                     self.onRoutesError(error!)
                }
            })
    }
    func onPedestrianRoutesReceived(_ routes: [YMKMasstransitRoute]) {
        let mapObjects = mapView.mapWindow.map.mapObjects
        let route = routes.first
        if route != nil
        {
            polyLineObjectPedestrianRoute = mapObjects.addPolyline(with: route!.geometry)
            polyLineObjectPedestrianRoute!.strokeWidth = 5
            polyLineObjectPedestrianRoute!.gapLength   = 5
            polyLineObjectPedestrianRoute!.dashOffset  = 6
            polyLineObjectPedestrianRoute!.dashLength  = 7
            polyLineObjectPedestrianRoute!.setStrokeColorWith(#colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1))
            
            for point_ in route!.geometry.points {
                locationsPointAR.append(CLLocation(latitude: point_.latitude, longitude: point_.longitude))
            }
        }
    }
    func onRoutesError(_ error: Error) {
        let routingError = (error as NSError).userInfo[YRTUnderlyingErrorKey] as! YRTError
        var errorMessage = "Unknown error"
        if routingError.isKind(of: YRTNetworkError.self) {
            errorMessage = "Network error"
        } else if routingError.isKind(of: YRTRemoteError.self) {
            errorMessage = "Remote server error"
        }
        let alert = UIAlertController(title: "Error", message: errorMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    func destinationLocation(fromCoordinate from: CLLocationCoordinate2D,
                             atDistance distance: Double,
                             withBearing bearing: Double) -> CLLocationCoordinate2D
    {
        var earthRadiusInMeters = 6378.137 * 1000
        let bearingRad = deg2rad(deg: bearing)
        let fromLat = deg2rad(deg: from.latitude)
        let fromLng = deg2rad(deg: from.longitude)

        let distanceRatio = distance / earthRadiusInMeters
        let toLat = asin(sin(fromLat) * cos(distanceRatio) + cos(fromLat) * sin(distanceRatio) * cos(bearingRad))
        let toLng = fromLng + atan2(sin(bearingRad) * sin(distanceRatio) * cos(fromLat), cos(distanceRatio) - sin(fromLat) * sin(toLat))

        return CLLocationCoordinate2D(latitude: rad2deg(rad: toLat), longitude: rad2deg(rad: toLng))
    }
}
