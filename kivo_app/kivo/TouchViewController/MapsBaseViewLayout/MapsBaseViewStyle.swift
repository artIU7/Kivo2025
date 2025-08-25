//
//  MapsBaseViewStyle.swift
//  kivo
//
//  Created by Артем Стратиенко on 19.04.2025.
//

import Foundation

extension TouchViewController
{
    static func style() -> String {
        return TouchViewController.readRawJson(resourceName: "customization")!
    }

    static func readRawJson(resourceName: String) -> String? {
        if let filepath: String = Bundle.main.path(forResource: resourceName, ofType: "json") {
            do {
                let contents = try String(contentsOfFile: filepath)
                return contents
            } catch {
                NSLog("JsonError: Contents could not be loaded from json file: " + resourceName)
                return nil
            }
        } else {
            NSLog("JsonError: json file not found: " + resourceName)
            return nil
        }
    }
}
