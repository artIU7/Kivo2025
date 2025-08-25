//
//  TouchViewController+Rouring.swift
//  kivo
//
//  Created by Артем Стратиенко on 17.08.2025.
//

import Foundation
import ARKit

extension TouchViewController {
    // прориосвка маршрута
    func drawARRoute() {
        routes = [SCNVector3]()
        if locationsPointAR != [] {
            for vector in locationsPointAR {
                let p1 = CLLocationCoordinate2D(latitude: startingLocation.coordinate.latitude,
                                                longitude: startingLocation.coordinate.longitude)
                let p2 = CLLocationCoordinate2D(latitude: vector.coordinate.latitude,
                                                longitude: vector.coordinate.longitude)
                let offset = offsetComplete(p1, p2)
                routes.append(SCNVector3(0 + offset[0], -1.65, 0 + offset[1] * -1))
            }
            //loadAIHelper(routes.first!, name: "AI+Helper")
            for i in 0...routes.count - 1 {
                if i != routes.count - 1 {
                    draw3DLine(routes[i], routes[i + 1], orderIndex: 1, color: .green)
                    //addLabel(routes[i], "⬆️", isCamera: true)
                }
            }
            self.arrowLoadMesh(routes.first!)
        }
    }
    func arrowLoadMesh(_ endRoute : SCNVector3) {
        let arrowScene = SCNScene(named: "poi.scn")!
        allowNode = arrowScene.rootNode.childNode(withName: "Meshes",
                                                   recursively: false)!
 
        allowNode.scale = SCNVector3(0.8, 0.8, 0.8)
        allowNode.position = endRoute
        allowNode.name = "poi"
        sceneView.scene.rootNode.addChildNode(allowNode)
    }
    func addPlane(content : UIImage, place : SCNVector3) {
        let plane = Plane(content : content, doubleSided: true, horizontal: true, plot: false)
        plane.position = place
        let yFreeConstraint = SCNBillboardConstraint()
        yFreeConstraint.freeAxes = [.Y]
        plane.constraints = [yFreeConstraint]
        plane.name = "imageResult"
        self.sceneView.scene.rootNode.addChildNode(plane)
    }
    func offsetComplete(_ pointStart : CLLocationCoordinate2D, _ pointEnd : CLLocationCoordinate2D) -> [Double] {
        let toRadian = Double.pi/180
        let toDegress = 180/Double.pi
        var deltaX = Double()
        var deltaZ = Double()
        var offset = [Double]()
        let defLat = (2*Double.pi * 6378.137)/360
        let defLot = (2*Double.pi*6378.137*cos(pointStart.latitude*toRadian))/360//*toDegress
            if pointStart != nil {
                if pointEnd != nil {
                    deltaX = (pointEnd.longitude - pointStart.longitude)*defLot*1000//*toDegress
                    deltaZ = (pointEnd.latitude - pointStart.latitude)*defLat*1000//*toDegress
                    var lon = (pointStart.longitude*defLot/*1000*/ + deltaX)/defLot/*1000*///*toDegress
                    var lat = (pointStart.latitude*defLat + deltaZ)/defLat//*toDegress
                    print("\(pointEnd.longitude - pointStart.longitude)")
                    print("\(pointEnd.latitude - pointStart.latitude)")
                }
            }
        offset.append(deltaX)
        offset.append(deltaZ)
        return offset
    }
    func draw3DLine(_ nodeA : SCNVector3, _ nodeB : SCNVector3, orderIndex : Int, color : UIColor) {
            //SCNTransaction.animationDuration = 1.0
        let nodeAVector3 = GLKVector3Make(nodeA.x, nodeA.y - 0.5, nodeA.z)
        let nodeBVector3 = GLKVector3Make(nodeB.x, nodeB.y - 0.5, nodeB.z)
            let line = MeasuringLineNode(startingVector: nodeAVector3 , endingVector: nodeBVector3, color: color)
            line.name = "routeAR"
            line.renderingOrder = 10 //+ orderIndex//orderIndex
            //line.opacity = 0
            //line.nodeAnimation(line)
            self.sceneView.scene.rootNode.addChildNode(line)
      }
    class MeasuringLineNode: SCNNode{
        init(startingVector vectorA: GLKVector3, endingVector vectorB: GLKVector3, color : UIColor) {
        super.init()
        let height = CGFloat(GLKVector3Distance(vectorA, vectorB))
        self.position = SCNVector3(vectorA.x, vectorA.y, vectorA.z)
        let nodeVectorTwo = SCNNode()
        nodeVectorTwo.position = SCNVector3(vectorB.x, vectorB.y, vectorB.z)
        let nodeZAlign = SCNNode()
        nodeZAlign.eulerAngles.x = Float.pi/2
        let cylinder = SCNCylinder(radius: 0.5, height: height)
        let material = SCNMaterial()
        let color_route = color
        material.diffuse.contents = color_route
        let box = SCNBox(width: 0.5, height: height, length: 0.05, chamferRadius: 0)
        box.materials = [material]
        let nodeLine = SCNNode(geometry: box)
        nodeLine.position.y = Float(-height/2)
        nodeZAlign.addChildNode(nodeLine)
        nodeZAlign.name = "route AR"
        nodeZAlign.renderingOrder = 10
        self.addChildNode(nodeZAlign)
        self.constraints = [SCNLookAtConstraint(target: nodeVectorTwo)]
    }
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    }
}
class Plane: SCNNode{
    init(width: CGFloat = 3.3, height: CGFloat = 2.2, content: Any, doubleSided: Bool, horizontal: Bool, plot : Bool) {
        super.init()
        if plot == true {
            self.geometry = SCNPlane(width: width + 2, height: height + 1)
        } else {
            self.geometry = SCNPlane(width: width - 2, height: height - 1)
        }
        let material = SCNMaterial()
        if let colour = content as? UIColor{
            material.diffuse.contents = colour
        } else if let image = content as? UIImage{
            material.diffuse.contents = image
        }else{
            material.diffuse.contents = UIColor.cyan
        }
        if plot == true {
            self.geometry?.firstMaterial?.colorBufferWriteMask = .alpha
        } else {
            self.geometry?.firstMaterial = material
        }
        if doubleSided{
            material.isDoubleSided = true
        }
        if horizontal{
            self.transform = SCNMatrix4Mult(self.transform, SCNMatrix4MakeRotation(Float(Double.pi), 1, 0, 1))
            self.transform = SCNMatrix4Mult(self.transform, SCNMatrix4MakeRotation(-Float(Double.pi)/1.0, 1, 0, 1))
        }
    }
    required init?(coder aDecoder: NSCoder) { fatalError("Plane Node Coder Not Implemented") }
}
