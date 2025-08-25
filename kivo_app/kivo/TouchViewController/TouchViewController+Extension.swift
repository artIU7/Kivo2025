//
//  TouchViewController+Extension.swift
//  kivo
//
//  Created by Артем Стратиенко on 21.04.2025.
//

import Foundation
import UIKit
import CoreLocation
import AVFoundation
import SnapKit
import YandexMapsMobile
import Speech
import CoreGraphics
import CoreML
import Vision
import MapKit
import ARKit
import MessageUI
import Photos


extension TouchViewController: SFSpeechRecognizerDelegate {
}

extension TouchViewController {
    func addARDestinationNode(at coordinate: CLLocationCoordinate2D, streetName : String ) {
        sceneView.scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        let sphere = SCNSphere(radius: 0.5)
        sphere.firstMaterial?.diffuse.contents = UIColor.systemRed.withAlphaComponent(0.8)
        let node = SCNNode(geometry: sphere)
        node.position = SCNVector3(0, 0, -2)
        node.position.y += 0.5
        let textGeometry = SCNText(string: streetName, extrusionDepth: 0.1)
        textGeometry.firstMaterial?.diffuse.contents = UIColor.white
        let textNode = SCNNode(geometry: textGeometry)
        textNode.scale = SCNVector3(0.01, 0.01, 0.01)
        textNode.position.y = 1.0
        node.addChildNode(textNode)
        sceneView.scene.rootNode.addChildNode(node)
        node.opacity = 0
        node.runAction(SCNAction.fadeIn(duration: 0.5))
    }
    
    func loadAIHelper(_ endRoute : SCNVector3,name : String) {
            let ai_helper = SCNScene(named: "tourist_prepare.scn")!
            infoNode = ai_helper.rootNode.childNode(withName: "scene",
                                                     recursively: false)!.childNode(withName: "Tourist",
                                                                                   recursively: false)!
            let yFreeConstraint = SCNBillboardConstraint()
            yFreeConstraint.freeAxes = [.Y]
            infoNode.constraints = [yFreeConstraint]
            infoNode.scale = SCNVector3(1.45, 1.45, 1.45)
            infoNode.position = endRoute
            infoNode.name = name
            sceneView.scene.rootNode.addChildNode(infoNode)
    }
    
    func loadInfoPoint(_ endRoute : SCNVector3)
    {
        let arrowScene = SCNScene(named: "nodeEnergy.scn")!
        let nodeArrow = arrowScene.rootNode.childNode(withName: "sphere",
                                                   recursively: false)!
        let yFreeConstraint = SCNBillboardConstraint()
        yFreeConstraint.freeAxes = [.Y]
        nodeArrow.constraints = [yFreeConstraint]

        nodeArrow.scale = SCNVector3(0.075, 0.075, 0.075)
        nodeArrow.position = endRoute
        nodeArrow.name = "info"
        nodeArrow.nodeAnimation(nodeArrow)
        sceneView.scene.rootNode.addChildNode(nodeArrow)
    }
    
    func getPositionLeftOfCamera(distance: Float) -> SCNVector3? {
        // Новая позиция (камера + смещение)
        var newPosition = SCNVector3(
            -distance,
            -1.65,
            0
        )
        if ( distance != 3.0 )
        {
            newPosition.x = -1
            newPosition.z = -0.75
            newPosition.y = -1.65 + ( infoNode.scale.y * 1.5 )
        }
        return newPosition
    }
    
    func updateARContent() {
        guard !sceneView.isHidden, let endPoint = pointEnd else { return }
        
        //let coordinate = CLLocationCoordinate2D(
        //    latitude: endPoint.geometry.latitude,
        //    longitude: endPoint.geometry.longitude
        //)
        //addARDestinationNode(at: coordinate,streetName: speechStreetName)
        drawARRoute()
    }
}
extension TouchViewController {
    // MARK: - ARSessionDelegate
    
    // Pass camera frames received from ARKit to Vision (when not already processing one)
    /// - Tag: ConsumeARFrames
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Do not enqueue other buffers for processing while another Vision task is still running.
        // The camera stream has only a finite amount of buffers available; holding too many buffers for analysis would starve the camera.
        guard currentBuffer == nil else { return }
        
        DispatchQueue.global(qos: .userInteractive).async {
                self.currentBuffer = frame.capturedImage
                self.detectionCurrentImage()
        }
    }
    /// - Tag: DetectionCurrentImage
    private func detectionCurrentImage() {
        // Most computer vision tasks are not rotation agnostic so it is important to pass in the orientation of the image with respect to device.
        let orientation = CGImagePropertyOrientation(UIDevice.current.orientation)

        let requestHandler = VNImageRequestHandler(cvPixelBuffer: currentBuffer!, orientation: orientation)
        visionQueue.async {
            do {
                // Release the pixel buffer when done, allowing the next buffer to be processed.
                defer { self.currentBuffer = nil }
                try requestHandler.perform([self.detectionRequest])
            } catch {
                print("Error: Vision request failed with error \"\(error)\"")
            }
        }
    }
    
    func showDetectionResult(_ results: [Any])
    {
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation else {
                continue
            }
            // Select only the label with the highest confidence.
            let topLabelObservation = objectObservation.labels[0]
            if ( topLabelObservation.confidence > 0.9 ) {
                if ( topLabelObservation.identifier.contains("bicycle")     ||
                     topLabelObservation.identifier.contains("car")         ||
                     topLabelObservation.identifier.contains("motorbike")   ||
                     topLabelObservation.identifier.contains("bus")         ||
                     topLabelObservation.identifier.contains("truck")
                    )
                {
                    var stringContent = "Внимание! Обнаружено транспортное средство !"
                    self.voiceHelperUI(textSpeech: "\(stringContent)")
                    self.words = stringContent.components(separatedBy: " ")
                }
                else if ( topLabelObservation.identifier.contains("traffic light") )
                {
                    var stringContent = "Внимание! Пешеходный переход !"
                    self.voiceHelperUI(textSpeech: "\(stringContent)")
                    self.words = stringContent.components(separatedBy: " ")
                }
            }
        }
    }
}
extension CGImagePropertyOrientation {
    init(_ deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portraitUpsideDown: self = .left
        case .landscapeLeft: self = .up
        case .landscapeRight: self = .down
        default: self = .right
        }
    }
}
extension Notification.Name {
    static let SMSReceived = Notification.Name("SMSReceivedNotification")
}
extension TouchViewController: MFMessageComposeViewControllerDelegate {
    func sendSMS(messageBody : String ) {
        guard MFMessageComposeViewController.canSendText() else {
            voiceHelperUI(textSpeech: "Устройство не поддерживает SMS")
            return
        }
        
        let composer = MFMessageComposeViewController()
        composer.messageComposeDelegate = self
        composer.recipients = ["\(phoneNumber)"]
        composer.body = messageBody
        present(composer, animated: true)
    }
    
    func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                    didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true)
    }
}

extension TouchViewController {
    // MARK: - Screenshot Detection
    
    func setupScreenshotDetection() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userTookScreenshot),
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
        
        PHPhotoLibrary.requestAuthorization { status in
            print("Photo library access status: \(status.rawValue)")
        }
    }
    @objc private func userTookScreenshot() {
        voiceHelperUI(textSpeech: "Обнаружено новое уведомление. Анализирую...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.analyzeLatestScreenshot()
        }
    }
    private func analyzeLatestScreenshot() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        
        let results = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        guard let asset = results.firstObject else {
            voiceHelperUI(textSpeech: "Не удалось найти скриншот")
            return
        }
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        requestOptions.deliveryMode = .highQualityFormat
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: requestOptions
        ) { [weak self] image, info in
            guard let self = self, let image = image else { return }
            
            let croppedImage = self.cropTopPart(of: image, percent: 0.1)
            self.recognizeTextInImage(croppedImage) { recognizedText in
                self.processScreenshotText(recognizedText)
            }
        }
    }
    private func cropTopPart(of image: UIImage, percent: CGFloat) -> UIImage {
        let originalSize = image.size
        let cropHeight = originalSize.height * percent
        let cropRect = CGRect(x: 0,
                             y: 0,
                             width: originalSize.width,
                             height: cropHeight)
        
        let scale = image.scale
        let scaledCropRect = CGRect(x: cropRect.origin.x * scale,
                                   y: cropRect.origin.y * scale,
                                   width: cropRect.size.width * scale,
                                   height: cropRect.size.height * scale)
        guard let cgImage = image.cgImage?.cropping(to: scaledCropRect) else {
            return image
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    private func processScreenshotText(_ text: String) {
        guard !text.isEmpty else {
               voiceHelperUI(textSpeech: "Не удалось распознать текст на скриншоте")
               return
           }
           var stringList = text.components(separatedBy: " ")
           var messageText = ""
           if ( stringList.count != 0 )
           {
               for i in 0...stringList.count - 1
               {
                   if stringList[i].contains("+7")
                   {
                       phoneNumber = stringList[i]
                   }
                   else if !stringList[i].contains("now")
                   {
                       messageText += stringList[i] + " "
                   }
               }
           }
           let keywords = ["SMS", "сообщение", "Message", "уведомление"]
           let foundKeywords = keywords.filter { text.localizedCaseInsensitiveContains($0) }
           var message = ""
           if !foundKeywords.isEmpty {
               message = "Обнаружено уведомление типа: \(foundKeywords.joined(separator: ", ")). "
               message += "Текст уведомления: \(messageText)"
           } else {
               message = "Распознанный текст: \(messageText)"
           }
           let maxLength = 500
           let truncatedMessage = String(message.prefix(maxLength))
           voiceHelperUI(textSpeech: truncatedMessage)
    }
    
    // MARK: - Text Recognition
    
    private func recognizeTextInImage(_ image: UIImage, completion: @escaping (String) -> Void) {
        guard let cgImage = image.cgImage else {
            completion("")
            return
        }
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion("")
                return
            }
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            completion(recognizedStrings.joined(separator: " "))
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["ru-RU", "en-US"]
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                print("Text recognition error: \(error)")
                completion("")
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            let point = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
            let hitTestResults = self.sceneView.hitTest(point, options: [
                .searchMode: SCNHitTestSearchMode.all.rawValue,
                .ignoreHiddenNodes: false
            ])
            var foundInfoNode: SCNNode?
            for result in hitTestResults {
                if result.node.name == "info" {
                    foundInfoNode = result.node
                    break
                }
            }
            if let infoNode = foundInfoNode {
                if self.currentARObject != infoNode {
                    self.currentARObject = infoNode
                    self.showImageForObject()
                }
            } else {
                if self.currentARObject != nil {
                    self.hideImage()
                    self.currentARObject = nil
                }
            }
        }
    }
    
    func showImageForObject() {
        if lastGeneratedImage == nil {return}
        if let objectPos = currentARObject?.position {
            // UIImage(named: "oct")!
            addPlane(content: lastGeneratedImage!, place: objectPos)
        }
    }

    func hideImage() {
        sceneView.scene.rootNode.enumerateChildNodes { (node, stop) in
            if (node.name != nil)
            {
                if ( node.name == "imageResult" )    {
                    node.removeFromParentNode()
                }
            }
        }
    }
}
extension SCNNode {
   public func nodeAnimation(_ nodeAnimation : SCNNode) {
        let animationGroup = CAAnimationGroup.init()
        animationGroup.duration = 1.0
        animationGroup.repeatCount = .infinity
    
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = NSNumber(value: 1.0)
        opacityAnimation.toValue = NSNumber(value: 0.5)
    
        let spin = CABasicAnimation.init(keyPath: "rotation")
        spin.fromValue = NSValue(scnVector4: SCNVector4(x: 0, y: 25, z: 0, w: 0))
        spin.toValue = NSValue(scnVector4: SCNVector4(x:0, y: 25, z: 0, w: Float(CGFloat(2 * M_PI))))
        spin.duration = 3
        spin.repeatCount = .infinity
        animationGroup.animations = [opacityAnimation,spin]
        nodeAnimation.addAnimation(animationGroup, forKey: "animations")
    }
}
extension SCNVector3 {
    func length() -> Float {
        return sqrtf(x * x + y * y + z * z)
    }
    static func + (_ a : SCNVector3,_ b : SCNVector3) -> SCNVector3 {
        let c = SCNVector3(a.x+b.x, a.y+b.y, a.z + b.z)
        return c
    }
}
