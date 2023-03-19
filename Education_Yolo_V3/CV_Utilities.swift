//
//  CV_Utilities.swift
//  Education_Yolo_V3
//
//  Created by Robert Le on 26/04/21.
//

import Foundation
import ARKit
import UIKit
import CoreML
import VideoToolbox

extension ARFrame {
    // The `displayTransform` method doesn't do what's advertised. This corrects for it
    func displayTransformCorrected(for interfaceOrientation: UIInterfaceOrientation,
                                 viewportSize: CGSize) -> CGAffineTransform {
        let flipYAxis: Bool
        let flipXAxis: Bool
        var imageResolution = camera.imageResolution
        switch interfaceOrientation {
        case .landscapeLeft,
             .landscapeRight:
          flipYAxis = false
          flipXAxis = true
        default:
            imageResolution = CGSize(width: imageResolution.height, height: imageResolution.width)
          flipYAxis = true
          flipXAxis = false
        }

        // Assume width cut off
        var height, width, translateX, translateY: CGFloat
        if imageResolution.width / imageResolution.height > viewportSize.width / viewportSize.height {
          height = viewportSize.height
          width = imageResolution.width / imageResolution.height * viewportSize.height
          translateX = (viewportSize.width - width)/2
          translateY = 0
        } else {
          width = viewportSize.width
          height = imageResolution.height / imageResolution.width * viewportSize.width
          translateX = 0
          translateY = (viewportSize.height - height)/2
        }

        if flipYAxis {
            translateY += height
            height = -height
        }
        if flipXAxis {
          translateX += width
          width = -width
        }
        
        return CGAffineTransform(scaleX: width, y:height)
          .concatenating(CGAffineTransform(translationX: translateX, y: translateY))
    }
}

extension CIImage {
    
    /// Returns a pixel buffer of the image's current contents.
    func toPixelBuffer(pixelFormat: OSType) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let options = [
            kCVPixelBufferCGImageCompatibilityKey as String: NSNumber(value: true),
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: NSNumber(value: true)
        ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(extent.size.width),
                                         Int(extent.size.height),
                                         pixelFormat,
                                         options as CFDictionary, &buffer)
        
        if status == kCVReturnSuccess, let device = MTLCreateSystemDefaultDevice(), let pixelBuffer = buffer {
            let ciContext = CIContext(mtlDevice: device)
            ciContext.render(self, to: pixelBuffer)
        } else {
            print("Error: Converting CIImage to CVPixelBuffer failed.")
        }
        return buffer
    }
    
    /// Returns a copy of this image scaled to the argument size.
    func resize(to size: CGSize) -> CIImage? {
        return self.transformed(by: CGAffineTransform(scaleX: size.width / extent.size.width,
                                                      y: size.height / extent.size.height))
    }
}

func calculateIOU(observation : Yolo.Prediction, rectangleList: [VNRectangleObservation], currentScreenTransform: CGAffineTransform, screenSize: CGRect) -> [Int] {
    
    var iouList: [Int] = []
    
    let width = screenSize.width
    let height = width * 4 / 3
    let scaleX = width / CGFloat(416)
    let scaleY = height / CGFloat(416)
    let top = ((screenSize.height) - height) / 2
    
    // Translate and scale the rectangle to our own coordinate system.
    var observationRect = observation.rect
    observationRect.origin.x *= scaleX
    observationRect.origin.y *= scaleY
    observationRect.origin.y += top
    observationRect.size.width *= scaleX
    observationRect.size.height *= scaleY
    
    var iou: CGFloat = 0
    var iouIndex = -1
    
    for (index, rectangle) in rectangleList.enumerated() {
        let rectangleRect: CGRect = CGRect(x: rectangle.boundingBox.applying(currentScreenTransform).minX,
                                           y: rectangle.boundingBox.applying(currentScreenTransform).minY,
                                           width: rectangle.boundingBox.applying(currentScreenTransform).width,
                                           height: rectangle.boundingBox.applying(currentScreenTransform).height)
        
        let intersectRect: CGRect = rectangleRect.intersection(observationRect)
        let unionRect: CGRect = observationRect.union(rectangleRect)
        let iouTemp = (intersectRect.width * intersectRect.height) / (unionRect.width * unionRect.height)
        
        /// Only consider the iou value of over 0.5
        if iouTemp > 0.5{
            if iouTemp > iou{
                iou = iouTemp
                iouIndex = index
            }
        }
    }
    
    iouList.append(iouIndex)
    
    return iouList
}

/// Creates a SceneKit node with plane geometry, to the argument size, rotation, and material contents.
func createPlaneNode(size: CGSize, rotation: Float, contents: Any?, objectPath: String, scale: Float, songPath: String) -> SCNNode {
    
    let virtualScene = SCNScene(named: objectPath)
    let nodeArray = virtualScene!.rootNode.childNodes
    let virtualNode = SCNNode()
    for childNode in nodeArray {
        virtualNode.addChildNode(childNode as SCNNode)
    }
    virtualNode.position = SCNVector3(0, 0, 0)
    //virtualNode.position = SCNVector3(0.05, 0, 0)
    //orientation of the model
//    virtualNode.eulerAngles.x = .pi / 2
    virtualNode.eulerAngles.y = .pi / 2
    virtualNode.eulerAngles.z = .pi / 2
    virtualNode.scale = SCNVector3(scale, scale, scale)
    
    
    //sound effect
    let audioSource = SCNAudioSource(fileNamed: songPath)!
    let audioNode = SCNNode()
    audioNode.addAudioPlayer(SCNAudioPlayer(source: audioSource))
    let play = SCNAction.playAudio(audioSource, waitForCompletion: true)
    audioNode.runAction(play)
    virtualNode.addChildNode(audioNode)
    
    
    return virtualNode
}
