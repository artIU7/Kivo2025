//
//  StartViewController.swift
//  kivo
//
//  Created by Артем Стратиенко on 19.04.2025.
//

import Foundation
import UIKit
import SnapKit
import SceneKit
import ARKit

class StartScreenViewController: UIViewController {
    
    // SceneKit scene
    var sceneView = SCNView()
    var scene: SCNScene!
    var cameraNode: SCNNode!
    var camera: SCNCamera!
    var nodePreload = SCNNode()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.setupSceneView()
        self.configLayout()
    }
}
extension StartScreenViewController: SCNSceneRendererDelegate {
    func configLayout() {
        view.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        // заголовок экрана приветсвия
        let labelImage = UIImageView(image: UIImage(named: "n_logo"))
        view.addSubview(labelImage)
        labelImage.snp.makeConstraints { (marker) in
            marker.top.equalToSuperview().inset(150)
            marker.centerX.equalToSuperview()
            marker.width.equalTo(200)
            marker.height.equalTo(140)
        }
        // add scene view screen
        view.addSubview(sceneView)
        self.sceneView.snp.makeConstraints { (marker) in
            marker.top.equalTo(labelImage).inset(100)
            marker.left.right.equalTo(self.view).inset(20)
            marker.bottom.equalTo(self.view).inset(100)
        }
        // button continie
        let nextViewController = UIButton(type: .system)
        nextViewController.backgroundColor = #colorLiteral(red: 0.8588235294, green: 0.2156862745, blue: 0.2196078431, alpha: 1)
        nextViewController.setTitle("Продолжить", for: .normal)
        nextViewController.setTitleColor(.white, for: .normal)
        nextViewController.layer.cornerRadius = 10
        nextViewController.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)

        view.addSubview(nextViewController)
        nextViewController.snp.makeConstraints { (marker) in
            marker.bottom.equalToSuperview().inset(20)
            marker.centerX.equalToSuperview()
            marker.left.right.equalToSuperview().inset(100)
            marker.height.equalTo(50)
        }
        nextViewController.addTarget(self, action: #selector(viewNextScreenController), for: .touchUpInside)
    }
        
    @objc func viewNextScreenController() {
        // переходим на экран разрешений
        let touchViewController = TouchViewController()
        touchViewController.modalPresentationStyle = .fullScreen
        touchViewController.modalTransitionStyle = .crossDissolve
        show(touchViewController, sender: self)
    }

    func setupSceneView() {
        sceneView.backgroundColor = UIColor.clear
        //
        //sceneView.backgroundColor = .darkGray
        //sceneView.layer.borderWidth = 1
        //sceneView.layer.borderColor = UIColor.red.cgColor
        sceneView.isUserInteractionEnabled = false
        sceneView.layer.cornerRadius = 50
        sceneView.layer.masksToBounds = true
        sceneView.clipsToBounds = true
        sceneView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMaxYCorner]
        scene = SCNScene()
        sceneView.autoenablesDefaultLighting = true
        sceneView.scene = scene
        sceneView.delegate = self
        sceneView.loops = true
        sceneView.showsStatistics = false
        sceneView.isPlaying = true
        // camera
        cameraNode = SCNNode()
        camera = SCNCamera()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(x: 0, y: 15, z: 50)
        cameraNode.camera?.zFar = 150
        scene.rootNode.addChildNode(cameraNode)
        // player node
        nodePreload = SCNNode()
        let playerScene = SCNScene(named: "tourist_prepare.scn")!
        let playerModelNode = playerScene.rootNode.childNodes.first!
        playerModelNode.scale = SCNVector3(0.08, 0.08, 0.08)
        playerModelNode.position = SCNVector3(x: 0, y: 5, z: 0)
        nodePreload.addChildNode(playerModelNode)
        nodePreload.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        nodePreload.physicsBody?.isAffectedByGravity = false
        scene.rootNode.addChildNode(nodePreload)
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) {
          let rotateByNode = SCNAction.rotate(toAxisAngle: SCNVector4(0, 1, 0, -45), duration: 120.0)
          self.nodePreload.runAction(rotateByNode)
        }
    }
}
