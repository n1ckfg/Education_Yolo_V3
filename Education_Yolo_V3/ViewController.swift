//
//  ViewController.swift
//  Education_Yolo_V3
//
//  Created by Robert Le on 26/04/21.
//

import UIKit
import SceneKit
import ARKit
import AVFoundation


class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, YoloDelegate, AlteredImageDelegate{
    
    // MARK: - Initialisation

    @IBOutlet var sceneView: ARSCNView!
    
    static var instance: ViewController?
    
    var isCurrentlyPredicting: Bool = false
    
    var currentExaminedClass: AlteredImage?
    
    var currentClassName: String = ""
    
    let yolo = Yolo()
    
    var currentScreenTransform: CGAffineTransform?
    
    var imageOrientation: CGImagePropertyOrientation?
    
    var screenBounds : CGRect?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        yolo.delegate = self
        
        // Set the view's delegate
        sceneView.preferredFramesPerSecond = 60
        
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        
        let soundSession = AVAudioSession.sharedInstance()
        try? soundSession.setActive(false)
        try! soundSession.setCategory(.playAndRecord, options: [.defaultToSpeaker,
                                                           .allowBluetooth,
                                                           .allowAirPlay])
        try! soundSession.setActive(true)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        ViewController.instance = self
        
        let configuartion = ARWorldTrackingConfiguration()
        configuartion.environmentTexturing = .automatic
        
        sceneView.session.run(configuartion)
        resetImageTrack()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    /// This method used when the program first started or when the system couldn't track any detected images
    func resetImageTrack(){
        currentExaminedClass?.delegate = nil
        currentExaminedClass = nil
        currentClassName = ""
        /// Restart the session and remove any image anchors that may have been detected previously.
        runImageTrackingSession(with: [], runOptions: [.removeExistingAnchors, .resetTracking])
    }
    
    /// Reset the image reference tracking if current image lost
    private func runImageTrackingSession(with trackingImages: Set<ARReferenceImage>, runOptions: ARSession.RunOptions = [.removeExistingAnchors]){
        let configuration = ARImageTrackingConfiguration()
        configuration.trackingImages = trackingImages
        configuration.maximumNumberOfTrackedImages = 1
        
        sceneView.session.run(configuration, options: runOptions)
        
    }
    
    // MARK: - Methods
    
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        screenBounds = self.sceneView.bounds
        self.currentScreenTransform = frame.displayTransformCorrected(
            for: interfaceOrientation,
            viewportSize: screenBounds!.size
        )
        
        imageOrientation = .up
    }


    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {

        currentExaminedClass?.add(anchor, node: node)
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        currentExaminedClass?.update(anchor)
    }
    

    
    func getIntersectRect(perspectiveImageList: [CIImage], observation: Yolo.Prediction, rectangleList: [VNRectangleObservation]) {
        
        /// get iou value of yolo bounding boxes and the rectangles
        let iouIndexList: [Int] = calculateIOU(observation: observation, rectangleList: rectangleList, currentScreenTransform: self.currentScreenTransform!, screenSize: screenBounds!)
        
        DispatchQueue.main.async { [self] in
            for iouIndex in iouIndexList{
                
                /// Ignore when the iou index is -1 --> means that the iou value is too small to be considered as a match.
                if iouIndex > -1{
                    guard self.currentExaminedClass == nil else {
                        return
                    }
                    
                    guard let referenceImagePixelBuffer = perspectiveImageList[iouIndex].toPixelBuffer(pixelFormat: kCVPixelFormatType_32BGRA) else {
                        print("Error: Could not convert rectangle content into an ARReferenceImage.")
                        return
                    }
                    
                    /*
                     Set a default physical width of 50 centimeters for the new reference image.
                     While this estimate is likely incorrect, that's fine for the purpose of the
                     app. The content will still appear in the correct location and at the correct
                     scale relative to the image that's being tracked.
                     */
                    
                    let possibleReferenceImage = ARReferenceImage(referenceImagePixelBuffer, orientation: .up, physicalWidth: CGFloat(0.07))
                    possibleReferenceImage.validate { [self] (error) in
                        if let error = error {
                            print("Reference image validation failed: \(error.localizedDescription)")
                            return
                        }
                        
                        
                        guard let newAlteredImage = AlteredImage(perspectiveImageList[iouIndex], referenceImage: possibleReferenceImage, className: labels[observation.classIndex]) else {
                            return
                        }
                        
                        newAlteredImage.delegate = self
                        self.currentExaminedClass = newAlteredImage
                        currentClassName = self.currentExaminedClass!.className
//                        print("Observation ", labels[observation.classIndex])

                        self.runImageTrackingSession(with: [newAlteredImage.referenceImage!])
                    }
                    
                }
            }
        }
    }
    
    func alteredImageLostTracking(_ alteredImage: AlteredImage) {
        resetImageTrack()
    }
}
