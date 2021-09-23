//
//  ViewController.swift
//  ARSample
//
//  Created by 奥田亮輔 on 2021/09/20.
//

import UIKit
import Metal
import MetalKit
import ARKit
import AudioToolbox
import VideoToolbox
import CoreVideo

extension MTKView : RenderDestinationProvider {
}

extension UIImage {     // for tranforming CVPixelBuffer to UIImage
    public convenience init?(pixelBuffer: CVPixelBuffer) {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)

        guard let cgImage = cgImage else {
            return nil
        }
        self.init(cgImage: cgImage)
    }
}

class ViewController: UIViewController, MTKViewDelegate, ARSessionDelegate {
    
    var session: ARSession!
    var renderer: Renderer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        print( "before ARSession() created" )
        session = ARSession()
        session.delegate = self
        
        // Set the view to use the default device
        if let view = self.view as? MTKView {
            print( "before MTLCreateSystemDefaultDevice()" )
            view.device = MTLCreateSystemDefaultDevice()
            view.backgroundColor = UIColor.clear
            view.delegate = self
            
            guard view.device != nil else {
                print("Metal is not supported on this device")
                return
            }
            
            // Configure the renderer to draw to the view
            print( "before Renderer() creation" )
            renderer = Renderer(session: session, metalDevice: view.device!, renderDestination: view)
            print( "after Renderer() creation" )

            renderer.drawRectResized(size: view.bounds.size)
        }
        /*
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ViewController.handleTap(gestureRecognize:)))
        view.addGestureRecognizer(tapGesture)
        */
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ViewController.checkTap(gestureRecognize:)))
        view.addGestureRecognizer(tapGesture)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Check LiDAR capability
        guard ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth, .smoothedSceneDepth]) else {
            print( "This device does not support LiDAR" )
            return
        }
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = [
                            .sceneDepth,            // raw output from LiDAR
                            .smoothedSceneDepth     // filtered output from LiDAR
                        ]

        // Run the view's session
        session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        session.pause()
    }
    
    @objc
    func checkTap(gestureRecognize: UITapGestureRecognizer) {
        AudioServicesPlaySystemSound(1108)      // camera shutter sound
        print( "Tapped" )
        if let currentFrame = session.currentFrame {
            
            // get time stamp and create file names
            let dt = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "jp_JP" )
            dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
            let timeStamp = dateFormatter.string(from: dt)
            
            let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let jpegFileName = documentPath.appendingPathComponent( timeStamp+".jpg" )
            let depthFileName = documentPath.appendingPathComponent( timeStamp+".dpt" )
            let confidenceFileName = documentPath.appendingPathComponent( timeStamp+".cnf" )
            print( jpegFileName )
            print( depthFileName )
            print( confidenceFileName )

            
            // save camera image to JPEG file
            let image = currentFrame.capturedImage
            // print( "Camera Image width:"+String(CVPixelBufferGetWidth(image))+" height:"+String(CVPixelBufferGetHeight(image))) // 1920 x 1440
            let uiimage = UIImage( pixelBuffer: image )
            var width = Int(uiimage!.size.width)
            var height = Int(uiimage!.size.height)
            // print( "UIImage width:"+String(width)+" height:"+String(height)) // 1920 x 1440
            let jpgImage = uiimage!.jpegData(compressionQuality:0.4)
            do {
                try jpgImage?.write( to: jpegFileName, options: .atomic)
            } catch {
                print( "cannot write jpeg data" )
                return
            }

            
            // save depth data to a file
            guard let depthMap = currentFrame.sceneDepth?.depthMap else { return }
            CVPixelBufferLockBaseAddress(depthMap,.readOnly) // enable CPU can read the CVPixelBuffer
            height = CVPixelBufferGetHeight( depthMap ) // 192 pixel
            // let bytesPerRow = CVPixelBufferGetBytesPerRow( depthMap ) // 1024 = 256 pixel X 4 bytes
            width = CVPixelBufferGetWidth( depthMap ) // 256 pixcel
            // let planes = CVPixelBufferGetPlaneCount( depthMap ) // 0
            // let dataSize = CVPixelBufferGetDataSize( depthMap ) // 196,608 = 256 pixel X 192 pixel X 4 bytes
            
            var base = CVPixelBufferGetBaseAddress( depthMap )
            var bindPtr = base?.bindMemory(to: Float32.self, capacity: width * height )
            var bufPtr = UnsafeBufferPointer(start:bindPtr, count: width * height)
            let depthArray = Array(bufPtr)
            //print( depthArray )
            do {
                try (depthArray as NSArray).write( to:depthFileName, atomically: false ) // written in xml text format
            } catch {
                print( "cannot write depth data" )
            }
            CVPixelBufferUnlockBaseAddress(depthMap,.readOnly) // Free buffer


            // save confidence data to a file
            guard let confidenceMap = currentFrame.sceneDepth?.confidenceMap else { return }
            CVPixelBufferLockBaseAddress(confidenceMap,.readOnly) // enable CPU can read the CVPixelBuffer
            height = CVPixelBufferGetHeight( confidenceMap ) // 192 pixel
            //let bytesPerRow = CVPixelBufferGetBytesPerRow( confidenceMap ) // 1024 = 256 pixel X 4 bytes
            width = CVPixelBufferGetWidth( confidenceMap ) // 256 pixcel
            //let planes = CVPixelBufferGetPlaneCount( confidenceMap ) // 0
            //let dataSize = CVPixelBufferGetDataSize( confidenceMap ) // 196,608 = 256 pixel X 192 pixel X 4 bytes

            base = CVPixelBufferGetBaseAddress( confidenceMap )
            bindPtr = base?.bindMemory(to: Float32.self, capacity: width * height )
            bufPtr = UnsafeBufferPointer(start:bindPtr, count: width * height)
            let confidenceArray = Array(bufPtr)
            //print( confidenceArray )
            do {
                try (confidenceArray as NSArray).write( to:confidenceFileName, atomically: false ) // written in xml text format
            } catch {
                print( "cannot write depth data" )
            }
            CVPixelBufferUnlockBaseAddress(confidenceMap,.readOnly) // Free buffer

        }
    }
    
    /*
    @objc
    func handleTap(gestureRecognize: UITapGestureRecognizer) {
        // Create anchor using the camera's current position
        if let currentFrame = session.currentFrame {
            
            // Create a transform with a translation of 0.2 meters in front of the camera
            var translation = matrix_identity_float4x4
            translation.columns.3.z = -0.2
            let transform = simd_mul(currentFrame.camera.transform, translation)
            
            // Add a new anchor to the session
            let anchor = ARAnchor(transform: transform)
            session.add(anchor: anchor)
        }
    }
    */
    
    // MARK: - MTKViewDelegate
    
    // Called whenever view changes orientation or layout is changed
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer.drawRectResized(size: size)
        //print("mtkView() called")
    }
    
    // Called whenever the view needs to render
    func draw(in view: MTKView) {
        renderer.update()
        //print( "draw() called" )
    }
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}
