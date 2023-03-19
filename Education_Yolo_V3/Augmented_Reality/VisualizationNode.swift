//
//  VisualizationNode.swift
//  Education_YoloV2
//
//  Created by Robert Le on 29/03/21.
//

import Foundation
import SceneKit
import ARKit

class VisualizationNode: SCNNode {
    
    // MARK: - Initialisation
    public let currentImage: SCNNode
    
    public let className: String?
    weak var delegate: VisualizationNodeDelegate?
    
    // MARK: - Methods
    public init(_ size: CGSize, className: String) {
        
        var path = ""
        var songPath = ""
        var scale : Float = 0
        if className == "tangela"{
            path = "art.scnassets/BreakDance_Mouse.dae"
            scale = 0.0005
            songPath = "art.scnassets/Numb-LinkinPark.mp3"
        }
        else if className == "chocolate" || className == "bread" || className == "milkshake"{
            path = "art.scnassets/HipHopDancing.dae"
            scale = 0.0004
            songPath = "art.scnassets/How You Like That.mp3"
        }
        else{
            path = "art.scnassets/SalsaDance_Mouse.dae"
            scale = 0.0005
            songPath = "art.scnassets/Numb-LinkinPark.mp3"
        }
        
        currentImage = createPlaneNode(size: size, rotation: -.pi / 2, contents: UIColor.clear, objectPath: path, scale: scale, songPath: songPath)
        self.className = className
        
        super.init()
        addChildNode(currentImage)
        //addChildNode(previousImage)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func display(){
        
    }
    
}

// MARK: - Protocol
/// Tells a delegate when the fade animation is done.
/// In this case, the delegate is an AlteredImage object.
protocol VisualizationNodeDelegate: class {
    //func visualizationNodeDidFinishFade(_ visualizationNode: VisualizationNode)
}
