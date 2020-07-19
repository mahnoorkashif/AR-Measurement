//
//  ViewController.swift
//  Plane Detection
//
//  Created by Mahnoor Khan on 15/07/2020.
//  Copyright © 2020 Mahnoor Khan. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {

    @IBOutlet weak var distanceLabel    : UILabel!
    @IBOutlet weak var centerPoint      : UILabel!
    @IBOutlet weak var addPointButton   : UIButton!
    @IBOutlet var sceneView             : ARSCNView!
    @IBOutlet weak var heightSlider     : UISlider!
    
    var diagonal    : SCNNode?
    var heightBox   : SCNNode?
    var pointNodes  : [SCNNode]?
    var lineNodes   : [[SCNNode?]]?
    
    var index = -1
        
    override func viewDidLoad() {
        super.viewDidLoad()
        setupScene()
        initUI()
        pointNodes = []
        lineNodes = []
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupARSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        /// Pause the view's session
        sceneView.session.pause()
    }
}

// MARK: - Initialisation Functions
extension ViewController {
    private func setupScene() {
        /// Set the view's delegate - ARSCNViewDelegate
        sceneView.delegate = self
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        /// add omnidirectional light in our AR App
        self.sceneView.autoenablesDefaultLighting = true
        /// debug points
        sceneView.debugOptions = [.showFeaturePoints]
    }
    
    private func setupARSession() {
        /// Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        /// set the configuration to start detecting horizontal planes
        configuration.planeDetection = .horizontal
        /// Run the view's session
        sceneView.session.run(configuration)
        /// disable the timer otherwise the phone will close when our app is running
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    private func initUI() {
        centerPoint.layer.cornerRadius = centerPoint.frame.width / 2
        addPointButton.layer.cornerRadius = addPointButton.frame.width / 2
        heightSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi/2))
        view.layoutIfNeeded()
    }
    
    private func resetMeasurements() {
        distanceLabel.text = ""
        index = -1
        guard let pointNodes = self.pointNodes else { return }
        for node in pointNodes {
            node.removeFromParentNode()
        }
        self.pointNodes?.removeAll()
        guard let lineNodes = self.lineNodes else { return }
        var i = 0
        for lineNode in lineNodes {
            for line in lineNode {
                line?.removeFromParentNode()
            }
            self.lineNodes?[i].removeAll()
            i += 1
        }
        diagonal?.removeFromParentNode()
        diagonal = nil
        heightBox?.removeFromParentNode()
        heightBox = nil
        heightSlider.isHidden = true
        heightSlider.value = 0.0
    }
    
    private func addCuboid() {
        let center = getCenterPoint(pointA: (pointNodes?[0].position)!, pointB: (pointNodes?[2].position)!)
        let width = distanceBetweenPoints(pointA: (pointNodes?[0].position)!, pointB: (pointNodes?[1].position)!)
        let length = distanceBetweenPoints(pointA: (pointNodes?[1].position)!, pointB: (pointNodes?[2].position)!)
        let cube = SCNBox(width: width, height: 0, length: length, chamferRadius: 0)
        cube.firstMaterial?.diffuse.contents = #colorLiteral(red: 0.3647058904, green: 0.06666667014, blue: 0.9686274529, alpha: 0.8794849537)
        let node = SCNNode(geometry: cube)
        node.position = center
        sceneView.scene.rootNode.addChildNode(node)
        heightBox = node
    }
}

// MARK: - IBActions
extension ViewController {
    @IBAction func hitTest(_ sender: UIButton) {
        if index == 2 { return }
        if let position = doHitTestingOnExistingPlanes() {
            let node = createNewNode(at: position)
            sceneView.scene.rootNode.addChildNode(node)
            pointNodes?.append(node)
            index += 1
            lineNodes?.append([SCNNode]())
            if index == 2 {
                let diagonal = getLineNode(from: (pointNodes?[index].position)!, to: (pointNodes?[0].position)!)
                sceneView.scene.rootNode.addChildNode(diagonal)
                self.diagonal = diagonal
                addCuboid()
                if let box = heightBox?.geometry as? SCNBox {
                    heightSlider.value = Float(box.height)
                }
                heightSlider.isHidden = false
            }
        }
    }
    
    @IBAction func resetTapped(_ sender: UIButton) {
        resetMeasurements()
    }
    
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        print(sender.value)
        if let box = heightBox?.geometry as? SCNBox {
            box.height = CGFloat(sender.value)
        }
    }
}

// MARK: - ARSCNViewDelegate
extension ViewController: ARSCNViewDelegate {
   //  Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
        return node
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        let meshNode: SCNNode

        /// anchors are the world objects that are detected by the mobile device
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }

        guard let meshGeometry = ARSCNPlaneGeometry(device: sceneView.device!)
            else { fatalError("Can't create a plane geometry") }
        meshGeometry.update(from: planeAnchor.geometry)
        meshNode = SCNNode(geometry: meshGeometry)
        meshNode.opacity = 0.5
        meshNode.name = "MeshNode"

        guard let material = meshNode.geometry?.firstMaterial
            else { fatalError("ARSCNPlaneGeometry always has one material") }
        material.diffuse.contents = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)

        node.addChildNode(meshNode)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        if let planeGeometry = node.childNode(withName: "MeshNode", recursively: false)?.geometry as? ARSCNPlaneGeometry {
            planeGeometry.update(from: planeAnchor.geometry)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if index == 2 || index == -1 { return }
        DispatchQueue.main.async {
            guard let currentPosition = self.doHitTestingOnExistingPlanes(), let start = self.pointNodes?[self.index] else { return }

            for node in (self.lineNodes?[self.index])! {
                node?.removeFromParentNode()
            }

            self.lineNodes?[self.index].removeAll()

            let lineNode = self.getLineNode(from: currentPosition, to: start.position)
            self.lineNodes?[self.index].append(lineNode)
            self.sceneView.scene.rootNode.addChildNode(lineNode)

            let distance = self.getDistance(from: currentPosition, to: start.position, unit: "cm")
            self.distanceLabel.text = distance
        }
    }
}

// MARK: - Helper Functions
extension ViewController {
    private func doHitTestingOnExistingPlanes() -> SCNVector3? {
        let results = sceneView.hitTest(view.center, types: .existingPlane)
        if let result = results.first {
            let hitPos = self.positionFromTransform(result.worldTransform)
            return hitPos
        }
        return nil
    }
    
    private func positionFromTransform(_ transform: matrix_float4x4) -> SCNVector3 {
        return SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }
    
    private func createNewNode(at position: SCNVector3) -> SCNNode {
        let sphere = SCNSphere(radius: 0.005)
        sphere.firstMaterial?.diffuse.contents = UIColor.green
        
        let node = SCNNode(geometry: sphere)
        node.position = position
        
        return node
    }
    
    private func getLineNode(from vector1: SCNVector3, to vector2: SCNVector3) -> SCNNode {
        let lineToDraw = getLineGeometry(from: vector1, to: vector2)
        lineToDraw.firstMaterial?.diffuse.contents = UIColor.red
        lineToDraw.firstMaterial?.lightingModel = SCNMaterial.LightingModel.constant
        let node = SCNNode(geometry: lineToDraw)
        return node
    }
    
    private func getLineGeometry(from vector1: SCNVector3, to vector2: SCNVector3) -> SCNGeometry {
        let indices : [Int32] = [0,1]
        let source = SCNGeometrySource(vertices: [vector1, vector2])
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        let lineGeometry = SCNGeometry(sources: [source], elements: [element])
        return lineGeometry
    }
    
    private func getDistance(from vector1: SCNVector3?, to vector2: SCNVector3?, unit: String) -> String {
        if vector1 == nil || vector2 == nil {
            return "0"
        }
        
        let distance = distanceBetweenPoints(pointA: vector1!, pointB: vector2!) // distance is in meters
        var distanceToDisplay = distance
        if unit == "inch" {
            distanceToDisplay = distance * 39.3701
        } else if unit == "feet" {
            distanceToDisplay = distance * 3.28084
        } else if unit == "cm" {
            distanceToDisplay = distance * 100.0
        }
        let meter = String(format: "%.1f %@", Float(distanceToDisplay), unit)
        return meter
    }
    
    private func distanceBetweenPoints(pointA: SCNVector3, pointB: SCNVector3) -> CGFloat {
        let l = sqrt(
            (pointA.x - pointB.x) * (pointA.x - pointB.x)
        +   (pointA.y - pointB.y) * (pointA.y - pointB.y)
        +   (pointA.z - pointB.z) * (pointA.z - pointB.z)
        )
        
        return CGFloat(l)
    }
    
    private func getCenterPoint(pointA: SCNVector3, pointB: SCNVector3) -> SCNVector3 {
        return SCNVector3Make((pointA.x + pointB.x)/2, (pointA.y + pointB.y)/2, (pointA.z + pointB.z)/2)
    }
 }