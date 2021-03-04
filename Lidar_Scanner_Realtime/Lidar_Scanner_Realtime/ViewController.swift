//
//  ViewController.swift
//  Lidar_Scanner_Realtime
//
//  Created by Gwan-Gyu Lee(fred.music.9808@icloud.com) on 2021/02/11.
//
//  This application contains copyrighted software under MIT License version 1.3.
//  Copyright (c) 2017 Devin Roth (devin@devinrothmusic.com)

import UIKit
import RealityKit
import ARKit
import MetalKit
import SwiftOSC

// MARK: - Extension

extension simd_float4x4 {
    var position: SIMD3<Float> {
        return SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}

extension ARMeshGeometry {
    func vertex(at index: UInt32) -> (Float, Float, Float) {
        assert(vertices.format == MTLVertexFormat.float3, "Expected three floats (twelve bytes) per vertex.")
        let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + (vertices.stride * Int(index)))
        let vertex = vertexPointer.assumingMemoryBound(to: (Float, Float, Float).self).pointee
        return vertex
    }
}

extension Transform {
    static func * (left: Transform, right: Transform) -> Transform {
        return Transform(matrix: simd_mul(left.matrix, right.matrix))
    }
}

//MARK: - Class

class ViewController: UIViewController, ARSessionDelegate {
    
    let pickerViewColumn = 1
    let maxArrayNum = 4
    var ipAddress = "192.168.0.4"
    var port = 7700
    var formatName = ["x: 1.2, y: 3.4, z: 5.6", "r: 1.2, g: 3.4, b: 5.6", "1.2 3.4 5.6", "1.2, 3.4, 5.6"]
    var vertexArray: [String] = []
    var vertexString = ""
    var vertex: (Float, Float, Float) = (0.0, 0.0, 0.0)
    var timer: Timer?
    var realTime = false
    var frameRate = 1.0
    
    
    
    //MARK: - Outlet
    
    @IBOutlet var txtIPAddress: UITextField!
    @IBOutlet var txtPort: UITextField!
    @IBOutlet var btnSet: UIButton!
    @IBOutlet var arView: ARView!
    @IBOutlet var viewConstraint: NSLayoutConstraint!
    @IBOutlet var blurView: UIVisualEffectView!
    @IBOutlet var sideView: UIView!
    @IBOutlet var txtFrameRate: UITextField!
    
    // MARK: - Override
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        // MARK: - ARView
        
        arView.session.delegate = self
        
        // Display a debug visualization of the mesh.
        arView.debugOptions.insert(.showSceneUnderstanding)

        // For performance, disable render options that are not required for this app.
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]
        
        // Manually configure what kind of AR session to run
        arView.automaticallyConfigureSession = false
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .mesh

        configuration.environmentTexturing = .automatic
        arView.session.run(configuration)
        
        //MARK: - Side Menu
              
        blurView.layer.cornerRadius = 10
        btnSet.layer.cornerRadius = 10
        
        txtIPAddress.layer.cornerRadius = 10
        txtIPAddress.clipsToBounds = true
        txtPort.layer.cornerRadius = 10
        txtPort.clipsToBounds = true
        
        txtFrameRate.layer.cornerRadius = 10
        txtFrameRate.clipsToBounds = true
        
        //sideView.layer.shadowColor = UIColor.black.cgColor
        //sideView.layer.shadowOpacity = 0.8
        //sideView.layer.shadowOffset = CGSize(width: 5, height: 0)
        
        viewConstraint.constant = -240
        
                
        let tap = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)

        // Realtime
        timer =  Timer.scheduledTimer(withTimeInterval: 1.0 / frameRate, repeats: true) { [self] (timer) in
            
            guard let frame = arView.session.currentFrame else {
                fatalError("Couldn't get the current ARFrame")
            }
            
            // Fetch the default MTLDevice to initialize a MetalKit buffer allocator with
            guard let device = MTLCreateSystemDefaultDevice() else {
                fatalError("Failed to get the system's default Metal device!")
            }
            
            // Using the Model I/O framework to export the scan, so we're initialising an MDLAsset object,
            // which we can export to a file later, with a buffer allocator
            let allocator = MTKMeshBufferAllocator(device: device)
            let asset = MDLAsset(bufferAllocator: allocator)
            
            // Fetch all ARMeshAncors
            let meshAnchors = frame.anchors.compactMap({ $0 as? ARMeshAnchor })
                         
            for meshAncor in meshAnchors {
                
                // Some short handles, otherwise stuff will get pretty long in a few lines
                let geometry = meshAncor.geometry
                let vertices = geometry.vertices
                let faces = geometry.faces
                let verticesPointer = vertices.buffer.contents()
                let facesPointer = faces.buffer.contents()
                                       
                // Converting each vertex of the geometry from the local space of their ARMeshAnchor to world space
                for vertexIndex in 0..<vertices.count {
                    
                    // Extracting the current vertex with an extension method provided by Apple in Extensions.swift
                    vertex = geometry.vertex(at: UInt32(vertexIndex))
                    
                    // Building a transform matrix with only the vertex position
                    // and apply the mesh anchors transform to convert into world space
                    var vertexLocalTransform = matrix_identity_float4x4
                    vertexLocalTransform.columns.3 = SIMD4<Float>(x: vertex.0, y: vertex.1, z: vertex.2, w: 1)
                    let vertexWorldPosition = (meshAncor.transform * vertexLocalTransform).position
                    
                    // Writing the world space vertex back into it's position in the vertex buffer
                    let vertexOffset = vertices.offset + vertices.stride * vertexIndex
                    let componentStride = vertices.stride / 3
                    verticesPointer.storeBytes(of: vertexWorldPosition.x, toByteOffset: vertexOffset, as: Float.self)
                    verticesPointer.storeBytes(of: vertexWorldPosition.y, toByteOffset: vertexOffset + componentStride, as: Float.self)
                    verticesPointer.storeBytes(of: vertexWorldPosition.z, toByteOffset: vertexOffset + (2 * componentStride), as: Float.self)
                    
                    // Get the bool of realtime switch
                    if realTime {
                    oscSend(vertexFunc(vertex))
                    }
//                    vertexFunc(vertex)
                    
                }
                
            }
            
//            vertexString = vertexArray.joined()
//            print(vertexString)
//            oscSend(vertexString)
            
        }

    }
    
    // MARK: - Function
    
    @objc func dismissKeyboard() {
        //Causes the view (or one of its embedded text fields) to resign the first responder status.
        view.endEditing(true)
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        DispatchQueue.main.async {
            // Present an alert informing about the error that has occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.btnReset(self)
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func oscSend(_ oscMessage: String) {
        let client = OSCClient(address: ipAddress, port: port)
        let message = OSCMessage(OSCAddressPattern(""), oscMessage)
        //let bundle = OSCBundle(Timetag(secondsSinceNow: 5.0), message)
        client.send(message)
    }
    
    func vertexFunc(_ vertex: (Float, Float, Float)) -> String {
        let vertex = vertex
        let x = vertex.0
        let y = vertex.1
        let z = vertex.2
        let vertexValue: String = "\(x) \(y) \(z)"
        vertexArray.append(vertexValue)
        
        return vertexValue
        
//        print(vertexArray)
                        
    }
    
    // MARK: - IBAction
    

    @IBAction func btnReset(_ sender: Any) {
        if let configuration = arView.session.configuration {
            arView.session.run(configuration, options: .resetSceneReconstruction)
        }
    }
    
    @IBAction func btnSetIPAddressAndPort(_ sender: UIButton) {
        ipAddress = txtIPAddress.text!
        port = Int(txtPort.text!) ?? 0
        oscSend("IP Address : \(ipAddress)")
        oscSend("Port : \(port)")
        oscSend("")
    }
    
    @IBAction func btnSetFrameRate(_ sender: UIButton) {
        frameRate = Double(txtFrameRate.text!) ?? 0
    }
    
    @IBAction func switchRealTime(_ sender: UISwitch) {
        if sender.isOn {
            realTime = true
        } else {
            realTime = false
        }
        
    }
    
    @IBAction func switchStatistics(_ sender: UISwitch) {
        if sender.isOn {
            arView.debugOptions.insert(.showStatistics)
        } else {
            arView.debugOptions.remove(.showStatistics)
        }
        
    }
    
    @IBAction func panGestureRecognizer(_ sender: UIPanGestureRecognizer) {
        
        if sender.state == .began || sender.state == .changed {
            let translation = sender.translation(in: self.view).x
            if translation > 0 {        // swipe right
                if viewConstraint.constant < 20 {
                    UIView.animate(withDuration: 0.2, animations: {
                        self.viewConstraint.constant += translation / 10
                        self.view.layoutIfNeeded()
                    })
                    //print(translation)
                }
            } else {                    // swipe left
                if viewConstraint.constant > -240 {
                    UIView.animate(withDuration: 0.2, animations: {
                        self.viewConstraint.constant += translation / 10
                        self.view.layoutIfNeeded()
                    })
                }
            }
        } else if sender.state == .ended {
            if viewConstraint.constant < -100 {
                UIView.animate(withDuration: 0.2, animations: {
                    self.viewConstraint.constant = -240
                    self.view.layoutIfNeeded()
                })
            } else {
                UIView.animate(withDuration: 0.2, animations: {
                    self.viewConstraint.constant = 10
                    self.view.layoutIfNeeded()
                })
            }
        }
    }
    
    @IBAction func btnSaveObj(_ sender: UIButton) {
        
        guard let frame = arView.session.currentFrame else {
            fatalError("Couldn't get the current ARFrame")
        }
        
        // Fetch the default MTLDevice to initialize a MetalKit buffer allocator with
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Failed to get the system's default Metal device!")
        }
        
        // Using the Model I/O framework to export the scan, so we're initialising an MDLAsset object,
        // which we can export to a file later, with a buffer allocator
        let allocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(bufferAllocator: allocator)
        
        // Fetch all ARMeshAncors
        let meshAnchors = frame.anchors.compactMap({ $0 as? ARMeshAnchor })
        
        // Convert the geometry of each ARMeshAnchor into a MDLMesh and add it to the MDLAsset
        for meshAncor in meshAnchors {
            
            // Some short handles, otherwise stuff will get pretty long in a few lines
            let geometry = meshAncor.geometry
            let vertices = geometry.vertices
            let faces = geometry.faces
            let verticesPointer = vertices.buffer.contents()
            let facesPointer = faces.buffer.contents()
            
            // Converting each vertex of the geometry from the local space of their ARMeshAnchor to world space
            for vertexIndex in 0..<vertices.count {
                
                // Extracting the current vertex with an extension method provided by Apple in Extensions.swift
                let vertex = geometry.vertex(at: UInt32(vertexIndex))
                
                // Building a transform matrix with only the vertex position
                // and apply the mesh anchors transform to convert into world space
                var vertexLocalTransform = matrix_identity_float4x4
                vertexLocalTransform.columns.3 = SIMD4<Float>(x: vertex.0, y: vertex.1, z: vertex.2, w: 1)
                let vertexWorldPosition = (meshAncor.transform * vertexLocalTransform).position
                
                // Writing the world space vertex back into it's position in the vertex buffer
                let vertexOffset = vertices.offset + vertices.stride * vertexIndex
                let componentStride = vertices.stride / 3
                verticesPointer.storeBytes(of: vertexWorldPosition.x, toByteOffset: vertexOffset, as: Float.self)
                verticesPointer.storeBytes(of: vertexWorldPosition.y, toByteOffset: vertexOffset + componentStride, as: Float.self)
                verticesPointer.storeBytes(of: vertexWorldPosition.z, toByteOffset: vertexOffset + (2 * componentStride), as: Float.self)
                
                            }
            
            // Initializing MDLMeshBuffers with the content of the vertex and face MTLBuffers
            let byteCountVertices = vertices.count * vertices.stride
            let byteCountFaces = faces.count * faces.indexCountPerPrimitive * faces.bytesPerIndex
            let vertexBuffer = allocator.newBuffer(with: Data(bytesNoCopy: verticesPointer, count: byteCountVertices, deallocator: .none), type: .vertex)
            let indexBuffer = allocator.newBuffer(with: Data(bytesNoCopy: facesPointer, count: byteCountFaces, deallocator: .none), type: .index)
            
            // Creating a MDLSubMesh with the index buffer and a generic material
            let indexCount = faces.count * faces.indexCountPerPrimitive
            let material = MDLMaterial(name: "mat1", scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
            let submesh = MDLSubmesh(indexBuffer: indexBuffer, indexCount: indexCount, indexType: .uInt32, geometryType: .triangles, material: material)
            
            // Creating a MDLVertexDescriptor to describe the memory layout of the mesh
            let vertexFormat = MTKModelIOVertexFormatFromMetal(vertices.format)
            let vertexDescriptor = MDLVertexDescriptor()
            vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition, format: vertexFormat, offset: 0, bufferIndex: 0)
            vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: meshAncor.geometry.vertices.stride)
            
            // Finally creating the MDLMesh and adding it to the MDLAsset
            let mesh = MDLMesh(vertexBuffer: vertexBuffer, vertexCount: meshAncor.geometry.vertices.count, descriptor: vertexDescriptor, submeshes: [submesh])
            asset.add(mesh)
            
        }
        
        // Setting the path to export the OBJ file to
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let urlOBJ = documentsPath.appendingPathComponent("scan.obj")

        // Exporting the OBJ file
        if MDLAsset.canExportFileExtension("obj") {
            do {
                try asset.export(to: urlOBJ)
                
                // Sharing the OBJ file
                let activityController = UIActivityViewController(activityItems: [urlOBJ], applicationActivities: nil)
                activityController.popoverPresentationController?.sourceView = sender
                self.present(activityController, animated: true, completion: nil)
            } catch let error {
                fatalError(error.localizedDescription)
            }
        } else {
            fatalError("Can't export OBJ")
        }
 
    }

    
    
    @IBAction func btnTest(_ sender: UIButton) {
        
//        oscSend("oscSend")
        
        guard let frame = arView.session.currentFrame else {
            fatalError("Couldn't get the current ARFrame")
        }
        
        // Fetch the default MTLDevice to initialize a MetalKit buffer allocator with
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Failed to get the system's default Metal device!")
        }
        
        // Using the Model I/O framework to export the scan, so we're initialising an MDLAsset object,
        // which we can export to a file later, with a buffer allocator
        let allocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(bufferAllocator: allocator)
        
        // Fetch all ARMeshAncors
        let meshAnchors = frame.anchors.compactMap({ $0 as? ARMeshAnchor })
                     
        for meshAncor in meshAnchors {
            
            // Some short handles, otherwise stuff will get pretty long in a few lines
            let geometry = meshAncor.geometry
            let vertices = geometry.vertices
            let faces = geometry.faces
            let verticesPointer = vertices.buffer.contents()
            let facesPointer = faces.buffer.contents()
                                   
            // Converting each vertex of the geometry from the local space of their ARMeshAnchor to world space
            for vertexIndex in 0..<vertices.count {
                
                // Extracting the current vertex with an extension method provided by Apple in Extensions.swift
                vertex = geometry.vertex(at: UInt32(vertexIndex))
                
                // Building a transform matrix with only the vertex position
                // and apply the mesh anchors transform to convert into world space
                var vertexLocalTransform = matrix_identity_float4x4
                vertexLocalTransform.columns.3 = SIMD4<Float>(x: vertex.0, y: vertex.1, z: vertex.2, w: 1)
                let vertexWorldPosition = (meshAncor.transform * vertexLocalTransform).position
                
                // Writing the world space vertex back into it's position in the vertex buffer
                let vertexOffset = vertices.offset + vertices.stride * vertexIndex
                let componentStride = vertices.stride / 3
                verticesPointer.storeBytes(of: vertexWorldPosition.x, toByteOffset: vertexOffset, as: Float.self)
                verticesPointer.storeBytes(of: vertexWorldPosition.y, toByteOffset: vertexOffset + componentStride, as: Float.self)
                verticesPointer.storeBytes(of: vertexWorldPosition.z, toByteOffset: vertexOffset + (2 * componentStride), as: Float.self)
                               
                oscSend(vertexFunc(vertex))
//                vertexArray.append((vertex.0, vertex.1, vertex.2))
//                print(vertex)
//                print(vertexFunc(vertex))

            }
            
        }
        
    }
    
}

