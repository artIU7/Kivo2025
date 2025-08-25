//
//  AppDelegate.swift
//  kivo
//
//  Created by Артем Стратиенко on 18.04.2025.
//
import UIKit
import YandexMapsMobile


@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    // Ключ Яндекс Карт
    let MAPKIT_API_KEY = "2cd7ee1b-e363-4c18-8ee1-884ff30244f3"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        /**
         * Set API key before interaction with MapKit.
         */
        YMKMapKit.setApiKey(MAPKIT_API_KEY)

        /**
         * You can optionaly customize  locale.
         * Otherwise MapKit will use default location.
         */
        YMKMapKit.setLocale("en_US")

        /**
         * If you create instance of YMKMapKit not in application:didFinishLaunchingWithOptions:
         * you should also explicitly call YMKMapKit.sharedInstance().onStart()
         */
        YMKMapKit.sharedInstance()

        return true
    }
}

