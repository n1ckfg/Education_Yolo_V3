//
//  Yolo.swift
//  ML_AR
//
//  Created by Robert Le on 3/04/21.
//

import Foundation
import UIKit
import CoreML
import Vision
import UIKit

class Yolo{
    
    // MARK: - Initialisation
    // Perform the prediction each interval of time
    private var updateTimer: Timer?
    private var updateInterval: TimeInterval = 0.03
    
    private var educationModel: VNCoreMLModel?
    
    weak var delegate: YoloDelegate?
    
    private var currentCameraImage: CVPixelBuffer!
    
    let gridHeight = [13, 26, 52]
    let gridWidth = [13, 26, 52]
    let blockSize: Float = 32
    let boxesPerCell = 3
    let numClasses = 22
    
    
    public static let maxBoundingBoxes = 10
    let confidenceThreshold: Float = 0.3
    let iouThreshold: Float = 0.1
    
    struct Prediction {
      let classIndex: Int
      let score: Float
      let rect: CGRect
    }
    
    // MARK: - Methods
    public init() {
        educationModel = {
                let modelConfig = MLModelConfiguration()
            modelConfig.computeUnits = .all
            let model = try? VNCoreMLModel(for: Education_416(configuration: modelConfig).model)
        //    let model = try? VNCoreMLModel(for: Education_V3_Tiny(configuration: modelConfig).model)
            return model
        }()
        
        self.updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            if let capturedImage = ViewController.instance?.sceneView.session.currentFrame?.capturedImage {
                self?.predict(imagePixel: capturedImage)
            }
        }
    }
    
    public func predict(imagePixel: CVPixelBuffer) {
        
       
        // If the system is currently searching for the rectangles --> STOP
        guard !(ViewController.instance!.isCurrentlyPredicting)  else {
            return
        }
        
        guard ViewController.instance!.currentClassName == ""  else {
            return
        }
        
        ViewController.instance!.isCurrentlyPredicting = true
        
        currentCameraImage = imagePixel
        
        
            
        
        
        let request = VNCoreMLRequest(model: educationModel!, completionHandler: { (request, error) in
            
            
            guard let observations = request.results as? [VNCoreMLFeatureValueObservation] else{
                ViewController.instance!.isCurrentlyPredicting = false
                ViewController.instance!.currentClassName = ""
                return
            }
            
            
            let predictions = self.getBoundingBoxes(features: [ observations[2].featureValue.multiArrayValue!, observations[1].featureValue.multiArrayValue!, observations[0].featureValue.multiArrayValue!])
 //           let predictions = self.getBoundingBoxes(features: [ observations[1].featureValue.multiArrayValue!, observations[0].featureValue.multiArrayValue!])
            if predictions.count > 0{
                let observation = predictions[0]
                
                
                
                self.searchForRectangle(observation: observation)
            }else{
                ViewController.instance!.isCurrentlyPredicting = false
                ViewController.instance!.currentClassName = ""
                return
            }
            
        })
        
        request.imageCropAndScaleOption = .scaleFill
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: currentCameraImage,
                                                        orientation: (ViewController.instance?.imageOrientation)!,
                                                    options: [:])
        
        // Perform request on background thread
        DispatchQueue.global(qos: .background).async {

            do {
                
                    try imageRequestHandler.perform([request])
                } catch {
                    print("Error: Vision request failed ")
                    ViewController.instance!.isCurrentlyPredicting = false
                    ViewController.instance!.currentClassName = ""
                }
        }
        
    }
    
    public func getBoundingBoxes(features: [MLMultiArray]) -> [Prediction] {
        
        
        assert(features[0].count == (numClasses+5)*3*13*13)
        assert(features[1].count == (numClasses+5)*3*26*26)
        //assert(features[2].count == (numClasses+5)*3*52*52)
        
        var predictions = [Prediction]()

        var featurePointer = UnsafeMutablePointer<Float32>(OpaquePointer(features[0].dataPointer))
        var channelStride = features[0].strides[0].intValue
        var yStride = features[0].strides[1].intValue
        var xStride = features[0].strides[2].intValue
        
        func offset(_ channel: Int, _ x: Int, _ y: Int) -> Int {
          return channel*channelStride + y*yStride + x*xStride
        }
        
        for i in 0..<2 {
            featurePointer = UnsafeMutablePointer<Float32>(OpaquePointer(features[i].dataPointer))
            channelStride = features[i].strides[0].intValue
            yStride = features[i].strides[1].intValue
            xStride = features[i].strides[2].intValue
            
            for cy in 0..<gridHeight[i] {
                for cx in 0..<gridWidth[i] {
                    for b in 0..<boxesPerCell {
                        let channel = b*(numClasses + 5)
                        
                        // The fast way:
                        let tx = Float(featurePointer[offset(channel    , cx, cy)])
                        let ty = Float(featurePointer[offset(channel + 1, cx, cy)])
                        let tw = Float(featurePointer[offset(channel + 2, cx, cy)])
                        let th = Float(featurePointer[offset(channel + 3, cx, cy)])
                        let tc = Float(featurePointer[offset(channel + 4, cx, cy)])



                        let scale = powf(2.0,Float(i)) // scale pos by 2^i where i is the scale pyramid level
                        let x = (Float(cx) * blockSize + sigmoid(tx))/scale
                        let y = (Float(cy) * blockSize + sigmoid(ty))/scale

                        let w = exp(tw) * anchors[i][2*b    ]
                        let h = exp(th) * anchors[i][2*b + 1]

                        let confidence = sigmoid(tc)

                        var classes = [Float](repeating: 0, count: numClasses)
                        for c in 0..<numClasses {

                            // The fast way:
                            classes[c] = Float(featurePointer[offset(channel + 5 + c, cx, cy)])
                        }
                        classes = softmax(classes)
                        let (detectedClass, bestClassScore) = classes.argmax()

                        let confidenceInClass = bestClassScore * confidence

                        
                        
                        if confidenceInClass > confidenceThreshold {
                            let rect = CGRect(x: CGFloat(x - w/2), y: CGFloat(y - h/2),
                                              width: CGFloat(w), height: CGFloat(h))

                            let prediction = Prediction(classIndex: detectedClass,
                                                        score: confidenceInClass,
                                                        rect: rect)
                            
                            predictions.append(prediction)
                        }
                        
                    }
                }
            }
            
        }
        return nonMaxSuppression(boxes: predictions, limit: Yolo.maxBoundingBoxes, threshold: iouThreshold)
    }
    
    
    public func searchForRectangle(observation : Prediction) {
        
        // Note that the pixel buffer's orientation doesn't change even when the device rotates.
        let handler = VNImageRequestHandler(cvPixelBuffer: currentCameraImage, orientation: .up)
        
        // Create a Vision rectangle detection request for running on the GPU.
        let request = VNDetectRectanglesRequest { request, error in
            self.completedVisionRequest(request, error: error, observation: observation)
        }
        
        // Look only for one rectangle at a time.
        request.maximumObservations = 5
        
        // Require rectangles to be reasonably large.
        request.minimumSize = 0.2
        
        // Require high confidence for detection results.
//        request.minimumConfidence = 0.9
        request.minimumConfidence = 0.0
        
        // Ignore rectangles with a too uneven aspect ratio.
        request.minimumAspectRatio = 0.3
        
        // Ignore rectangles that are skewed too much.
        //request.quadratureTolerance = 20
        
        // You leverage the `usesCPUOnly` flag of `VNRequest` to decide whether your Vision requests are processed on the CPU or GPU.
        // This sample disables `usesCPUOnly` because rectangle detection isn't very taxing on the GPU. You may benefit by enabling
        // `usesCPUOnly` if your app does a lot of rendering, or runs a complicated neural network.
        request.usesCPUOnly = true
        
        try? handler.perform([request])
    }
    
    private func completedVisionRequest(_ request: VNRequest?, error: Error?, observation :Prediction) {
        defer {
            ViewController.instance!.isCurrentlyPredicting = false
            self.currentCameraImage = nil
        }
        do{
            guard let rectangles = request?.results as? [VNRectangleObservation] else {
                guard let error = error else { return }
                print("Error: Rectangle detection failed - Vision request returned an error. \(error.localizedDescription)")
                ViewController.instance!.isCurrentlyPredicting = false
                ViewController.instance!.currentClassName = ""
                return
            }
            
            guard let filter = CIFilter(name: "CIPerspectiveCorrection") else {
                print("Error: Rectangle detection failed - Could not create perspective correction filter.")
                ViewController.instance!.isCurrentlyPredicting = false
                ViewController.instance!.currentClassName = ""
                return
            }
            
            //Only determine the rectangles corrdinates if the total is at least 1
            if rectangles.count > 0 {

                var perspectiveImageList: [CIImage] = []
                var rectangleList: [VNRectangleObservation] = []

                for rectangle in rectangles{
                    let width = CGFloat(CVPixelBufferGetWidth(currentCameraImage))
                    let height = CGFloat(CVPixelBufferGetHeight(currentCameraImage))
                    let topLeft = CGPoint(x: rectangle.topLeft.x * width, y: rectangle.topLeft.y * height)
                    let topRight = CGPoint(x: rectangle.topRight.x * width, y: rectangle.topRight.y * height)
                    let bottomLeft = CGPoint(x: rectangle.bottomLeft.x * width, y: rectangle.bottomLeft.y * height)
                    let bottomRight = CGPoint(x: rectangle.bottomRight.x * width, y: rectangle.bottomRight.y * height)

                    filter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
                    filter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
                    filter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
                    filter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")

//                    let ciImage = CIImage(cvPixelBuffer: currentCameraImage).oriented((ViewController.instance?.imageOrientation)!)
                    let ciImage = CIImage(cvPixelBuffer: currentCameraImage).oriented(.up)
                    filter.setValue(ciImage, forKey: kCIInputImageKey)

                    guard let perspectiveImage: CIImage = filter.value(forKey: kCIOutputImageKey) as? CIImage else {
                        print("Error: Rectangle detection failed - perspective correction filter has no output image.")
                        ViewController.instance!.isCurrentlyPredicting = false
                        ViewController.instance!.currentClassName = ""
                        return
                    }

                    rectangleList.append(rectangle)
                    perspectiveImageList.append(perspectiveImage)
                }

                delegate?.getIntersectRect(perspectiveImageList: perspectiveImageList, observation: observation, rectangleList: rectangleList)

            }else{
                ViewController.instance!.isCurrentlyPredicting = false
                ViewController.instance!.currentClassName = ""
                return
            }
        }
    }
}


// MARK: - Protocol
protocol YoloDelegate: class {
    func getIntersectRect(perspectiveImageList: [CIImage], observation : Yolo.Prediction, rectangleList: [VNRectangleObservation])
}
