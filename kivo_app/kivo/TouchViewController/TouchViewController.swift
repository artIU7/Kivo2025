//
//  TouchViewController.swift
//  kivo
//
//  Created by Артем Стратиенко on 19.04.2025.
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



class TouchViewController: UIViewController,ARSessionDelegate, ARSCNViewDelegate,AVSpeechSynthesizerDelegate {
    
    var coachingOverlay: ARCoachingOverlayView!

    // Режим отладки - отображение жестов
    var isDebugMode = false
    var isModeType = 0
    var routes = [SCNVector3]()
    var allowNode : SCNNode!

    var locationsPointAR: [CLLocation] = []
    var responseLabel = UILabel()
    var lastGeneratedImage: UIImage? // Переменная для хранения последнего изображения
    
    var currentARObject: SCNNode? // Текущий AR-объект, на который наведена камера
    
    var words: [String] = []
    var currentWordIndex = 0
    
    private var notificationCheckTimer: Timer?
    private var lastNotificationCheckTime = Date()
    // Вьюха с AR режимом
    var sceneView = ARSCNView()
    var infoNode : SCNNode!

    // Вьюха с яндекс картами
    lazy var mapView: YMKMapView = MapsViewBaseLayout().mapView
    // Оффлайн режим - подгрузка карты
    let offlineCacheManager = YMKMapKit.sharedInstance().offlineCacheManager
    var isLoadAlready = false
    // точка старта маршрута от моей геолокации
    var pointStart : YMKPlacemarkMapObject!
    // точка конца маршрута
    var pointEnd :  YMKPlacemarkMapObject!
    var speechStreetName : String = ""
    var smsTextFromSpeech : String = ""
    // Точки входные для вычисления маршрута
    var requestPoints : [YMKRequestPoint] = []
    var pedestrianSession : YMKMasstransitSession?
    var polyLineObjectPedestrianRoute : YMKPolylineMapObject? = nil
    // подключаем нативную локацию через CoreLocation
    // Yandex Location не юзаем
    var nativeLocationManager = CLLocationManager()
    // Стартовая позиция пользователя ( геолокация )
    // Вычисляется после инициализации модуля CoreLocation
    var ROUTE_START_POINT = YMKPoint(latitude: 0.0, longitude: 0.0)
    // Вычисляется конечная точка после выбора обьекта на карте - и переданного в маршрутизатор
    var ROUTE_END_POINT   = YMKPoint(latitude: 0.0, longitude: 0.0)
    // Гео юзера
    var userLocation      : YMKPoint?
    // Координаты гео в CLLocation
    var startingLocation: CLLocation!
    // Курс направления
    var currentMagneticHeading = CLHeading()
    // Направление движения (вычисляемое на маршруте )
    var bearingSimulationLocation = 0.0
    // Предыдущая координата обьекта на карте
    var beforLocationSimulation = CLLocationCoordinate2D()
    // Вью для захвата жестов от пользователя
    private let drawingView = TouchDrawGestureView()
    // Дебажный лэйбл оценки жестов
    private let resultLabel = UILabel()
    // Кнопка для включения записи голоса и перевода в текст
    let voiceToTextButton   = UIButton( type : .system )
    let voiceToTextButtonARMode   = UIButton( type : .system )
    // Для озвучки текста - text-to-speech
    let synthesizer = AVSpeechSynthesizer()
    var stringTextFromVoice = String()
    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ru_RU"))!
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    let audioEngine = AVAudioEngine()
    var isRoutedMode = false
    var isSmsSendMode = false
    var phoneNumber = ""

    /// The ML model to be used for recognition of arbitrary objects. - Detection
    var _yolo3Model: YOLOv3Tiny!
    var yolo3Model: YOLOv3Tiny! {
        get {
            if let model = _yolo3Model { return model }
            _yolo3Model = {
                do {
                    let configuration = MLModelConfiguration()
                    return try YOLOv3Tiny(configuration: configuration)
                } catch {
                    fatalError("Couldn't create Inceptionv3 due to: \(error)")
                }
            }()
            return _yolo3Model
        }
    }
    
    lazy var detectionRequest: VNCoreMLRequest = {
        do{
            let model = try VNCoreMLModel(for: yolo3Model.model)
            let objectRecognition = VNCoreMLRequest(model: model, completionHandler: { (request, error) in
                DispatchQueue.main.async(execute: {
                    // perform all the UI updates on the main queue
                    if let results = request.results {
                        self.showDetectionResult(results)
                    }
                })
            })
            
            objectRecognition.imageCropAndScaleOption = .centerCrop
            objectRecognition.usesCPUOnly = true
            return objectRecognition
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    let visionQueue = DispatchQueue(label: "com.example.apple-samplecode.ARKitVision.serialVisionQueue")
    var currentBuffer: CVPixelBuffer?
    
    // Добавляем пульсацию при записи
    let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")

    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        synthesizer.delegate = self
        // Do any additional setup after loading the view.
        view.addSubview(mapView)
        lastGeneratedImage = UIImage(named: "test_check")!

        self.mapView.snp.makeConstraints { (marker) in
            marker.top.equalTo(self.view).inset(0)
            marker.left.right.equalTo(self.view).inset(0)
            marker.bottom.equalTo(self.view).inset(0)
        }
        // Запись команды или адресса
        
        pulseAnimation.duration = 1.5
        pulseAnimation.fromValue = 0.85
        pulseAnimation.toValue = 1.05
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        
        // Фон с градиентом
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            #colorLiteral(red: 0.7310847748, green: 0.7310847748, blue: 0.7310847748, alpha: 0.8036250992).cgColor,
            #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 0.8029169941).cgColor
        ]
        gradientLayer.locations = [0, 1]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        gradientLayer.cornerRadius = 45
        gradientLayer.frame = CGRect(x: 0, y: 0, width: 90, height: 90)
        
        // Фон с градиентом
        let gradientLayerAR = CAGradientLayer()
        gradientLayerAR.colors = [
            #colorLiteral(red: 0.7310847748, green: 0.7310847748, blue: 0.7310847748, alpha: 0.8036250992).cgColor,
            #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 0.8029169941).cgColor
        ]
        gradientLayerAR.locations = [0, 1]
        gradientLayerAR.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayerAR.endPoint = CGPoint(x: 0.5, y: 1)
        gradientLayerAR.cornerRadius = 45
        gradientLayerAR.frame = CGRect(x: 0, y: 0, width: 90, height: 90)
        
        // Настройка внешнего вида кнопки
        voiceToTextButton.setImage(UIImage(named: "voiceIcon"), for: .normal)
        voiceToTextButton.tintColor = #colorLiteral(red: 0.7310847748, green: 0.7310847748, blue: 0.7310847748, alpha: 1)
        voiceToTextButton.layer.insertSublayer(gradientLayer, at: 0)

        // Тень
        voiceToTextButton.layer.shadowColor = UIColor(red: 0.27, green: 0.46, blue: 0.65, alpha: 0.5).cgColor
        voiceToTextButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        voiceToTextButton.layer.shadowRadius = 8
        voiceToTextButton.layer.shadowOpacity = 0.7
        voiceToTextButton.layer.cornerRadius = 45

        // Анимация при нажатии
        voiceToTextButton.addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
        voiceToTextButton.addTarget(self, action: #selector(buttonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        view.addSubview(voiceToTextButton)
        voiceToTextButton.addTarget(self, action: #selector(self.voiceButtonAction(_:)), for: .touchUpInside)
        voiceToTextButton.snp.makeConstraints { (marker) in
            marker.height.equalTo(90)
            marker.width.equalTo(90)
            marker.bottomMargin.equalToSuperview().inset(60)
            marker.centerX.equalToSuperview().inset(0)
        }
        voiceToTextButton.isHidden = false
        
        sceneView.delegate = self
        sceneView.session.delegate = self
        let scene = SCNScene()
        sceneView.scene = scene
        self.view.addSubview(sceneView)
        sceneView.snp.makeConstraints { (marker) in
            marker.top.bottom.equalToSuperview().inset(0)
            marker.left.right.equalToSuperview().inset(0)
        }
        sceneView.isHidden = true
        
        // Запись команды или адресса ARMode
        voiceToTextButtonARMode.setImage(UIImage(named: "voiceIcon"), for: .normal)
        voiceToTextButtonARMode.tintColor = #colorLiteral(red: 0.7310847748, green: 0.7310847748, blue: 0.7310847748, alpha: 1)
        voiceToTextButtonARMode.layer.insertSublayer(gradientLayerAR, at: 0)

        // Тень
        voiceToTextButtonARMode.layer.shadowColor = UIColor(red: 0.27, green: 0.46, blue: 0.65, alpha: 0.5).cgColor
        voiceToTextButtonARMode.layer.shadowOffset = CGSize(width: 0, height: 4)
        voiceToTextButtonARMode.layer.shadowRadius = 8
        voiceToTextButtonARMode.layer.shadowOpacity = 0.7
        voiceToTextButtonARMode.layer.cornerRadius = 45

        // Анимация при нажатии
        voiceToTextButtonARMode.addTarget(self, action: #selector(buttonTouchDownAR), for: .touchDown)
        voiceToTextButtonARMode.addTarget(self, action: #selector(buttonTouchUpAR), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        sceneView.addSubview(voiceToTextButtonARMode)
        voiceToTextButtonARMode.addTarget(self, action: #selector(self.voiceButtonAction(_:)), for: .touchUpInside)
        voiceToTextButtonARMode.snp.makeConstraints { (marker) in
            marker.height.equalTo(90)
            marker.width.equalTo(90)
            marker.bottomMargin.equalToSuperview().inset(60)
            marker.centerX.equalToSuperview().inset(0)
        }
        voiceToTextButtonARMode.isHidden = false
        
        
        // CСкрываем вьюху с рисованием через CoreGraphics - для анализа жестов
        //drawingView.alpha = 0
        drawingView.backgroundColor = UIColor.clear
        view.addSubview(drawingView)
        self.drawingView.snp.makeConstraints { (marker) in
            marker.top.equalTo(self.view).inset(0)
            marker.left.right.equalTo(self.view).inset(0)
            marker.bottom.equalTo(self.view).inset(0)
        }
        view.addSubview(resultLabel)
        self.resultLabel.snp.makeConstraints { (marker) in
            marker.top.equalTo(self.view).inset(20)
            marker.left.right.equalTo(self.view).inset(0)
            marker.height.equalTo(40)
        }
        
        drawingView.onDrawingEnd = { [weak self] in
            self?.recognizeDrawing()
            self?.drawingView.clear()
        }
        drawingView.isUserInteractionEnabled = false
        setupMapView()
        
        // location manager
        if CLLocationManager.locationServicesEnabled() {
            nativeLocationManager.delegate = self
            nativeLocationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            nativeLocationManager.requestWhenInUseAuthorization()
            nativeLocationManager.startUpdatingLocation()
            nativeLocationManager.startUpdatingHeading()
            
        }
        
        let mapDoubleTap = UITapGestureRecognizer(target: self, action: #selector(handleMapDoubleTap))
        mapDoubleTap.numberOfTapsRequired = 3
        self.mapView.addGestureRecognizer(mapDoubleTap)
        let sceneDoubleTap = UITapGestureRecognizer(target: self, action: #selector(handleSceneDoubleTap))
        sceneDoubleTap.numberOfTapsRequired = 3
        self.sceneView.addGestureRecognizer(sceneDoubleTap)
        self.startLocation()
        
        speechRecognizer.delegate = self
        SFSpeechRecognizer.requestAuthorization { authStatus in
            OperationQueue.main.addOperation
            {
                switch authStatus
                {
                case .authorized:
                    print("Доступна запись")
                    self.voiceToTextButton.isEnabled = true
                default:
                    print("Нет доступа запись")
                    self.voiceToTextButton.isEnabled = false
                }
            }
        }
        setupScreenshotDetection()
        setupResponseLabel()
        try! setupAudiSessionForA2Pods()
        
        presentMessageSheet { [weak self] message in
            print("Отправлено сообщение: \(message)")
            // Здесь можно отправить сообщение на сервер или обработать его
        }
    }
    
    @objc private func buttonTouchDown() {
        UIView.animate(withDuration: 0.2) {
            self.voiceToTextButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            self.voiceToTextButton.layer.shadowOpacity = 0.4
        }
    }

    @objc private func buttonTouchUp() {
        UIView.animate(withDuration: 0.2) {
            self.voiceToTextButton.transform = .identity
            self.voiceToTextButton.layer.shadowOpacity = 0.7
        }
    }
    
    @objc private func buttonTouchDownAR() {
        UIView.animate(withDuration: 0.2) {
            self.voiceToTextButtonARMode.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            self.voiceToTextButtonARMode.layer.shadowOpacity = 0.4
        }
    }

    @objc private func buttonTouchUpAR() {
        UIView.animate(withDuration: 0.2) {
            self.voiceToTextButtonARMode.transform = .identity
            self.voiceToTextButtonARMode.layer.shadowOpacity = 0.7
        }
    }

    // Для включения/выключения пульсации при записи
    func startPulseAnimation() {
        voiceToTextButton.layer.add(pulseAnimation, forKey: "pulse")
        voiceToTextButtonARMode.layer.add(pulseAnimation, forKey: "pulse")
    }

    func stopPulseAnimation() {
        voiceToTextButton.layer.removeAnimation(forKey: "pulse")
        voiceToTextButtonARMode.layer.removeAnimation(forKey: "pulse")
    }
   
    @objc private func handleMapDoubleTap() {
        if !drawingView.isUserInteractionEnabled {
            drawingView.isUserInteractionEnabled = true
        }
    }

    @objc private func handleSceneDoubleTap() {
        if !drawingView.isUserInteractionEnabled {
            drawingView.isUserInteractionEnabled = true
        }
    }
    
    func setupResponseLabel() {
        responseLabel = UILabel()
        responseLabel.text = ""
        responseLabel.textColor = .white
        responseLabel.backgroundColor = .black.withAlphaComponent(0.7)
        responseLabel.textAlignment = .center
        responseLabel.numberOfLines = 0
        responseLabel.layer.cornerRadius = 8
        responseLabel.clipsToBounds = true
        responseLabel.frame = CGRect(x: 0, y: 0, width: 250, height: 80)
        responseLabel.isHidden = true
        view.addSubview(responseLabel)
        
        // Обновляем позицию лейбла каждые 0.1 секунды
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateLabelPosition()
        }
    }
    
    func updateLabelPosition()
    {
        if (isModeType == 1 )
        {
            guard let info = infoNode else { return }
            if ( !responseLabel.text!.isEmpty )
            {
                if ( responseLabel.isHidden ) { responseLabel.isHidden = false }
            }

            // Проецируем 3D-позицию персонажа в 2D-экранные координаты
            let projectedPosition = sceneView.projectPoint(info.position)
            
            // Обновляем позицию лейбла (с небольшим смещением вверх)
            DispatchQueue.main.async {
                    self.responseLabel.center = CGPoint(
                    x: CGFloat(projectedPosition.x),
                    y: CGFloat(projectedPosition.y) - 460
                )
            }
        }
        else
        {
            if ( !responseLabel.text!.isEmpty )
            {
                responseLabel.isHidden = false
            }
            DispatchQueue.main.async {
                // Получаем размеры экрана
                  let screenWidth = UIScreen.main.bounds.width
                  let yPosition: CGFloat = 40  // Отступ от верха
                  
                  // Устанавливаем позицию лейбла
                  self.responseLabel.frame = CGRect(
                      x: (screenWidth - self.responseLabel.frame.width) / 2,
                      y: yPosition,
                      width: self.responseLabel.frame.width,
                      height: self.responseLabel.frame.height)
            }
        }
    }
    
    func voiceRecord() {
        if audioEngine.isRunning
        {
            stopPulseAnimation()
            audioEngine.stop()
            recognitionRequest?.endAudio()
            self.voiceToTextButton.isEnabled = false
            if ( !self.stringTextFromVoice.isEmpty )
            {
                if ( self.isRoutedMode )
                {
                    self.voiceHelperUI(textSpeech: " Маршрут построен до  \(self.stringTextFromVoice) ?")
                    geocodeAddressString(self.stringTextFromVoice)
                }
                else if ( self.isSmsSendMode )
                {
                    self.smsTextFromSpeech = self.stringTextFromVoice
                    self.voiceHelperUI(textSpeech: " Смс записана :  \(self.stringTextFromVoice) ?")
                }
                else
                {
                    getTokenToGigaChat(requestString: self.stringTextFromVoice)
                }
            }
        }
        else
        {
            if ( synthesizer.isSpeaking )
            {
                synthesizer.stopSpeaking(at: .immediate)
            }
            startPulseAnimation()
            try! startRecording()
        }
    }
    @objc func voiceButtonAction(_ sender:UIButton)
    {
        voiceRecord()
    }

    func setupAudiSessionForA2Pods() throws
    {
        // Настройка аудиосессии
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        
        // Проверяем доступные входы и выбираем AirPods если они подключены
        if let availableInputs = audioSession.availableInputs {
            for input in availableInputs {
                if input.portType == .bluetoothHFP || input.portType == .bluetoothA2DP {
                    try audioSession.setPreferredInput(input)
                    break
                }
            }
        }
    }
    
    private func startRecording() throws {
        
        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
        
        recognitionRequest.shouldReportPartialResults = true
        
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                isFinal = result.isFinal
                self.stringTextFromVoice = result.bestTranscription.formattedString
                print( self.stringTextFromVoice)
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.voiceToTextButton.isEnabled = true
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            DispatchQueue.global(qos: .utility).async {
                self.recognitionRequest?.append(buffer)
            }
        }
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    func setupMapView()
    {
        // Ставим стиль карты из json файла
        mapView.mapWindow.map.setMapStyleWithStyle(TouchViewController.style())
    }
    
    func geocodeAddressString(_ address: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { [self] (placemarks, error) in
            if let error = error {
                print("Geocoding error: \(error.localizedDescription)")
                return
            }
            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                print("No location found")
                return
            }
            let coordinate = location.coordinate
            print("Координаты: \(coordinate.latitude), \(coordinate.longitude)")
            print("Детали: \(placemark.name ?? ""), \(placemark.locality ?? "")")
            speechStreetName = placemark.name!
            self.requestPoints.insert(YMKRequestPoint(point: YMKPoint(latitude: coordinate.latitude, longitude: coordinate.longitude), type: .viapoint, pointContext: nil), at: 0)
            let mapObjects = self.mapView.mapWindow.map.mapObjects
            self.pointStart = mapObjects.addPlacemark(with: YMKPoint(latitude: self.startingLocation.coordinate.latitude, longitude: self.startingLocation.coordinate.longitude))
            self.pointStart.setIconWith(UIImage(named: "custom_point")!)
            self.pointEnd = mapObjects.addPlacemark(with: YMKPoint(latitude: coordinate.latitude, longitude: coordinate.longitude))
            self.pointEnd.setIconWith(UIImage(named: "custom_point_selected")!)
            self.callPedestrianRoutingResponse()
        }
    }
    // Обработка жестов
    private func recognizeDrawing() {
        guard let image = drawingView.getDrawing(),
              let model = try? VNCoreMLModel(for: kivo_gesture().model) else { return }
        
        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            
            guard let results = request.results as? [VNClassificationObservation],
                  let topResult = results.first else { return }
            print(results)
            DispatchQueue.main.async {
                if ( topResult.confidence < 0.99 )
                {
                    if ( self!.isDebugMode )
                    {
                        self?.resultLabel.text = "Жест : не распознан)"
                    }
                    self?.voiceHelperUI(textSpeech: "Жест не распознан , повторите !")
                }
                else
                {
                    if ( self!.isDebugMode )
                    {
                        self?.resultLabel.text = "Жест: \(topResult.identifier) (\(Int(topResult.confidence * 100))%)"
                    }
                    if ( topResult.identifier == "c" )
                    {
                        self?.voiceHelperUI(textSpeech: "Желаете построить маршут ?")
                    }
                    if ( topResult.identifier == "v" )
                    {
                        if ( self!.isRoutedMode )
                        {
                            self?.voiceRecord()
                        }
                        else if ( self!.isSmsSendMode )
                        {
                            self?.voiceRecord()
                            self!.isSmsSendMode = false
                            // Включаем запись после приглашения - произнести текст
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                self?.sendSMS(messageBody: self!.smsTextFromSpeech)
                            }
                        }
                        else
                        {
                            self?.isRoutedMode = true
                            self?.voiceHelperUI(textSpeech: "Хорошо, для построения маршрута необходимо произнести адрес, как будете готовы произнести - введите команду!")
                        }
                    }
                    if ( topResult.identifier == "i" )
                    {
                        if ( self!.isRoutedMode )
                        {
                            self?.voiceHelperUI(textSpeech: "Хорошо, я слушаю!")
                            // Включаем запись после приглашения - произнести текст
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                self?.voiceRecord()
                            }
                        }
                        else
                        {
                            self!.isSmsSendMode = true
                            
                            self?.voiceHelperUI(textSpeech: "Для отправки сообщения необходимо его записать !")
                            // Включаем запись после приглашения - произнести текст
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                self?.voiceRecord()
                            }
                        }
                    }
                    if ( topResult.identifier == "x" )
                    {
                        if ( self!.isRoutedMode )
                        {
                            self!.isRoutedMode = false
                            self!.resetRoute()
                        }
                    }
                    if ( topResult.identifier == "iv" )
                    {
                        // Запускаем AR режим и наоборот
                        DispatchQueue.main.async {
                            self?.toggleARMode()
                        }
                    }
                }
            }
        }
        
        let handler = VNImageRequestHandler(cgImage: image.cgImage!)
        DispatchQueue.global().async {
            try? handler.perform([request])
        }
    }
    func resetRoute()
    {
        // По команде Х
        // очищаем маршрут - сбрасываем точки и очищаем AR сцену
        if ( self.polyLineObjectPedestrianRoute != nil )
        {
            self.mapView.mapWindow.map.mapObjects.remove(with: self.polyLineObjectPedestrianRoute!)
            self.polyLineObjectPedestrianRoute = nil
        }
        if ( self.pointStart != nil )
        {
            self.mapView.mapWindow.map.mapObjects.remove(with: self.pointStart!)
            self.pointStart = nil
        }
        if ( self.pointEnd != nil )
        {
            self.mapView.mapWindow.map.mapObjects.remove(with: self.pointEnd!)
            self.pointEnd = nil
        }
        
        removePrepareNodeRoute()
        locationsPointAR.removeAll()
        if ( !self.requestPoints.isEmpty && self.requestPoints.count > 1 )
        {
            self.requestPoints.removeLast()
        }
        //  requestPoints.removeAll()

    }
    func removePrepareNodeRoute()
    {
        sceneView.scene.rootNode.enumerateChildNodes { (node, stop) in
            if (node.name != nil)
            {
                if ( node.name!.contains("point_") || node.name!.contains("line_") || node.name == "routeAR" || node.name == "poi" || node.name == "imageResult" /*|| node.name == "info" */)
                {
                    node.removeFromParentNode()
                }
            }
        }
    }
    func toggleARMode() {
        if sceneView.isHidden {
            // Проверяем поддержку AR
            guard ARWorldTrackingConfiguration.isSupported else {
                voiceHelperUI(textSpeech: "AR не поддерживается на этом устройстве")
                return
            }
            
            // Проверяем разрешение на камеру
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.enterARMode()
                    } else {
                        self.voiceHelperUI(textSpeech: "Нужен доступ к камере для AR режима")
                    }
                }
            }
        } else {
            exitARMode()
        }
    }

    func enterARMode() {
        UIView.transition(with: view, duration: 0.5, options: [.transitionFlipFromRight], animations: {
            self.mapView.isHidden = true
            self.sceneView.isHidden = false
        }, completion: { _ in
            self.setupCoachingOverlay()
            let configuration = ARWorldTrackingConfiguration()
            configuration.worldAlignment = .gravityAndHeading
            configuration.providesAudioData = false // Отключаем ненужные данные
            self.sceneView.preferredFramesPerSecond = 30
            self.sceneView.session.run(configuration)
            var stringContent = "AR режим активирован ! Направляйте камеру в сторону обьектов !"
            self.voiceHelperUI(textSpeech: "\(stringContent)")
            self.words = stringContent.components(separatedBy: " ")
            self.isModeType = 1
        })
    }

    func exitARMode() {
        UIView.transition(with: view, duration: 0.5, options: [.transitionFlipFromLeft], animations: {
            self.mapView.isHidden = false
            self.sceneView.isHidden = true
        }, completion: { _ in
            self.sceneView.session.pause()
            self.removePrepareNodeRoute()
            var stringContent = "Режим карты активирован!"
            self.voiceHelperUI(textSpeech: "\(stringContent)")
            self.words = stringContent.components(separatedBy: " ")
            self.isModeType = 0
        })
    }
    
    public func voiceHelperUI(textSpeech : String)
    {
        let utterance = AVSpeechUtterance(string: "\(textSpeech)")
        utterance.rate = 0.445
        utterance.volume = 1.0
        let voice = AVSpeechSynthesisVoice(language: "ru-RU")
        utterance.voice = voice
        utterance.pitchMultiplier = 1.2
        if ( !synthesizer.isSpeaking )
        {
            synthesizer.speak(utterance)
        }
    }
}

extension TouchViewController {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let spokenText = utterance.speechString
        let wordRange = (spokenText as NSString).substring(with: characterRange)
        
        // Находим индекс текущего слова
        if let range = spokenText.range(of: wordRange, options: .backwards) {
            let prefix = spokenText[..<range.lowerBound]
            let prefixWords = prefix.components(separatedBy: " ").filter { !$0.isEmpty }
            currentWordIndex = prefixWords.count
        }
        // Подсвечиваем текущее слово
        highlightCurrentWord()
    }
    
    func highlightCurrentWord() {
        // Проверяем, что массив не пустой и индекс в допустимых пределах
        guard !words.isEmpty, currentWordIndex >= 0, currentWordIndex < words.count else {
            DispatchQueue.main.async {
                self.responseLabel.attributedText = nil
                self.responseLabel.text = ""
            }
            return
        }
        
        // Определяем диапазон слов для отображения (максимум 3 слова)
        let startIndex = currentWordIndex
        let endIndex = min(currentWordIndex + 2, words.count - 1)
        
        // Проверяем, что диапазон корректен
        guard startIndex <= endIndex else { return }
        
        let wordsToShow = Array(words[startIndex...endIndex])
        let textToShow = wordsToShow.joined(separator: " ")
        
        // Создаем атрибутированную строку
        let attributedString = NSMutableAttributedString(string: textToShow)
        
        // Подсвечиваем только текущее (первое) слово
        let currentWordRange = NSRange(location: 0, length: words[startIndex].count)
        attributedString.addAttribute(.foregroundColor,
                                    value: UIColor.red,
                                    range: currentWordRange)
        
        DispatchQueue.main.async {
            self.responseLabel.attributedText = attributedString
        }
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Возвращаем обычный цвет после завершения
        self.responseLabel.attributedText = NSAttributedString(string:  self.responseLabel.text ?? "")
        if ( !self.responseLabel.text!.isEmpty )
        {
            self.responseLabel.text = ""
        }
        if ( self.responseLabel.isHidden == false )
        {
            self.responseLabel.isHidden = true
        }
    }
}
extension TouchViewController : ARCoachingOverlayViewDelegate
{
    func setupCoachingOverlay() {
        coachingOverlay = ARCoachingOverlayView() // Создаем overlay
        coachingOverlay.delegate = self           // Подписываемся на события
        coachingOverlay.session = sceneView.session  // Связываем с AR сессией ← ВАЖНО!
        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false // Для AutoLayout
        
        // Добавляем на экран поверх ARView
        sceneView.addSubview(coachingOverlay)
        
        NSLayoutConstraint.activate([
            coachingOverlay.centerXAnchor.constraint(equalTo: sceneView.centerXAnchor),
            coachingOverlay.centerYAnchor.constraint(equalTo: sceneView.centerYAnchor),
            coachingOverlay.widthAnchor.constraint(equalTo: sceneView.widthAnchor),
            coachingOverlay.heightAnchor.constraint(equalTo: sceneView.heightAnchor)
        ])
        
        coachingOverlay.goal = .tracking
    }
    
    // MARK: - ARCoachingOverlayViewDelegate
    
    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        // AR сессия готова! Можно размещать контент
        print("AR session is ready for content!")
        addARContent()
    }
    
    func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
        // Coaching overlay покажется - можно приостановить game logic
        self.removePrepareNodeRoute()
        print("Coaching overlay will appear")
    }
    
    func addARContent()
    {
        if let leftPosition = self.getPositionLeftOfCamera(distance: 3.0) {
            self.loadAIHelper( leftPosition, name: "AI+Helper")
        }
        if let rightPosition = self.getPositionLeftOfCamera(distance: 3.1) {
            self.loadInfoPoint( rightPosition)
        }
        // При переходе в AR-режим обновляем контент
        if self.pointEnd != nil {
            self.updateARContent()
        }
    }
}
