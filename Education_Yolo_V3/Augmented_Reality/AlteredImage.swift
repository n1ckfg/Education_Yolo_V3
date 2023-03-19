//
//  AlteredImage.swift
//  ML_AR
//
//  Created by Robert Le on 3/04/21.
//

import Foundation
import ARKit
import CoreML

/// - Tag: AlteredImage
class AlteredImage  {
    
    // MARK: - Initialisation
    /// A delegate to tell when image tracking fails.
    weak var delegate: AlteredImageDelegate?
    
    public var className: String = ""
    
    public var referenceImage: ARReferenceImage?
    
    /// A SceneKit node that animates images of varying style.
    private let visualizationNode: VisualizationNode
    
    /// A handle to the anchor ARKit assigned the tracked image.
    private(set) var anchor: ARImageAnchor?
    
    /// A timer start every second checking whether the imageReference still detectable or lost
    private var failedTrackingTimeout: Timer?
    
    private var timeout: TimeInterval = 0.03
    
    // MARK: - Methods
    init?(_ image: CIImage, referenceImage: ARReferenceImage, className: String) {
        self.className = className
        self.referenceImage = referenceImage
        
        anchor?.setValue(className, forKey: "className")
        
        
        
        visualizationNode = VisualizationNode(referenceImage.physicalSize, className: className)

        // Start the failed tracking timer right away. This ensures that the app starts
        //  looking for a different image to track if this one isn't trackable.
        resetImageTrackingTimeout()
        
        //createAugmentedInfo()
    }
    
    deinit {
        visualizationNode.removeAllAnimations()
        visualizationNode.removeFromParentNode()
    }
    
    /// Prevents the image tracking timeout from expiring.
    private func resetImageTrackingTimeout() {
        failedTrackingTimeout?.invalidate()
        failedTrackingTimeout = Timer.scheduledTimer(withTimeInterval: timeout, repeats: true) { [weak self] _ in
            if let strongSelf = self {
                self?.delegate?.alteredImageLostTracking(strongSelf)
            }
        }
    }
    
    
    func add(_ anchor: ARAnchor, node: SCNNode) {
        if let imageAnchor = anchor as? ARImageAnchor, imageAnchor.referenceImage == referenceImage {
            self.anchor = imageAnchor
            
            
            // Start the image tracking timeout.
            //resetImageTrackingTimeout()
            
            // Add the node that displays the altered image to the node graph.
            node.addChildNode(visualizationNode)

            
        }
    }
    
    func update(_ anchor: ARAnchor) {
       
        if let imageAnchor = anchor as? ARImageAnchor, self.anchor == anchor {
            self.anchor = imageAnchor
            // Reset the timeout if the app is still tracking an image.
            //print(imageAnchor.isTracked)
            if !imageAnchor.isTracked {
                resetImageTrackingTimeout()
            }

        }
    }
}

// MARK: - Protocol
/**
 Tells a delegate when image tracking failed.
  In this case, the delegate is the view controller.
 */
protocol AlteredImageDelegate: class {
    func alteredImageLostTracking(_ alteredImage: AlteredImage)
}
