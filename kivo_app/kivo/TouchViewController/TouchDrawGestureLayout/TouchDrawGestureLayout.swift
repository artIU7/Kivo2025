//
//  TouchDrawGestureLayout.swift
//  kivo
//
//  Created by Артем Стратиенко on 19.04.2025.
//

import Foundation
import UIKit
import CoreGraphics


class TouchDrawGestureView: UIView {
    var isDebugMode = false
    private var path = UIBezierPath()
    private var strokeColor: UIColor = .black
    private var strokeWidth: CGFloat = 10.0
    private var previousPoint: CGPoint = .zero
    private var isDrawingEnabled = false
    
    var onDrawingEnd: (() -> Void)?

    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = .white
        path.lineWidth = strokeWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        
        // Добавляем распознаватель двойного касания
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }
    
    @objc private func handleDoubleTap() {
        isDrawingEnabled.toggle()
        layer.borderWidth = isDrawingEnabled ? 2 : 0
        layer.borderColor = isDrawingEnabled ? UIColor.blue.cgColor : nil
        isUserInteractionEnabled = isDrawingEnabled // Синхронизируем состояния
        if !isDrawingEnabled {
            onDrawingEnd?()
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDrawingEnabled, let touch = touches.first else { return }
        previousPoint = touch.location(in: self)
        path.move(to: previousPoint)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDrawingEnabled, let touch = touches.first else { return }
        let currentPoint = touch.location(in: self)
        path.addLine(to: currentPoint)
        previousPoint = currentPoint
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        // Скрываем отрисовку для юзера
        // для отладки рисуем через draw слой
        if ( isDebugMode )
        {
            strokeColor.setStroke()
            path.stroke()
        }
    }
    
    func clear() {
        path.removeAllPoints()
        setNeedsDisplay()
    }
    
    func getDrawing() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        // Фон в любом режимы добавляем при конвертации фото для модели
        UIColor.white.setFill()
        UIRectFill(bounds)
        if ( !isDebugMode )
        {
            strokeColor.setStroke()
            path.stroke()
        }
        layer.render(in: UIGraphicsGetCurrentContext()!)
        guard let originalImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return nil
        }
        let targetSize = CGSize(width: 299, height: 299)
        UIGraphicsBeginImageContextWithOptions(targetSize, true, 0.0)
        originalImage.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
}
