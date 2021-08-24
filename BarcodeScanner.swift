//
//  BarcodeScanner
//  NFC Manager
//
//  Created by Francisco Fortes on 06/04/2020.
//  Copyright © 2020 Francisco Fortes. All rights reserved.
//

import UIKit
import AVFoundation

@objc open class BarcodeScannerConstants: NSObject {
    @objc public static let scanCameraMode: String = "scanCameraMode"
    @objc public static let kDelayForNextBarcodeReading: Double = 2.5
}

@objc public protocol BarcodeScannerCompatible: NSObjectProtocol {
    var centralHoleImageView: UIImageView! { get }
}

@objc public protocol BarcodeScannerDelegate: NSObjectProtocol {
    @objc optional func finishedBarcodeScan(barcodeData: String?, type: String) -> Void
}

@objc open class BarcodeScanner: UIView {
    
    // MARK: - Properties
    
    @objc public weak var delegate: BarcodeScannerDelegate?
    @objc public var inDelegateWait: Bool = false
    @objc public var cameraPosition: AVCaptureDevice.Position {
        get {
            if let rawValue = UserDefaults.standard.value(forKey: BarcodeScannerConstants.scanCameraMode) as? Int {
                if let position = AVCaptureDevice.Position(rawValue: rawValue), position != .unspecified {
                    return position
                }
            }
            return .back
        }
        set (newPosition) {
            UserDefaults.standard.set(newPosition.rawValue, forKey: BarcodeScannerConstants.scanCameraMode)
            if self.session.isRunning {
                self.stopCapture()
                self.detectionString = nil
                self.barCodeType = nil
                self.inDelegateWait = false
                self.device = BarcodeScanner.cameraWith(position: newPosition)
                self.startCapture()
                self.updateOrientation()
            } else {
                self.device = BarcodeScanner.cameraWith(position: newPosition)
            }
        }
    }
    // parentVC (optional) needs to implement BarcodeScannerCompatible protocol to work with this component
    @objc public weak var parentVC: (UIViewController & BarcodeScannerCompatible)?
    
    fileprivate var session: AVCaptureSession = AVCaptureSession()
    fileprivate var device: AVCaptureDevice?
    fileprivate var input: AVCaptureDeviceInput?
    fileprivate var metadataOutput: AVCaptureMetadataOutput = AVCaptureMetadataOutput()
    fileprivate var previewLayer: AVCaptureVideoPreviewLayer?
    fileprivate var detectionString: String?
    fileprivate var barCodeType: AVMetadataObject.ObjectType?
    fileprivate var inWaitDelay: Bool = false
    
    // MARK: - Init & Setup
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    @objc public init(with viewController: UIViewController & BarcodeScannerCompatible) {
        super.init(frame: viewController.view.bounds)
        
        self.setStyle()
        
        self.parentVC = viewController
        viewController.view.addSubview(self)
        
        NotificationCenter.default.addObserver(self, selector: #selector(orientationDidChange(notification:)), name: UIDevice.orientationDidChangeNotification, object: nil)
        
        UIView.animate(withDuration: 0.25, animations: {
            self.layer.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.8).cgColor
        }) { finished in
            DispatchQueue.main.async {
                self.startCapture()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Capture mgmt
    
    @objc public func startCapture() -> Void {
        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
            return
        } 
        
        if let parentVC = self.parentVC {
            self.setInterestRect(for: parentVC.centralHoleImageView)
        }
        self.session.sessionPreset = AVCaptureSession.Preset.photo
        
        self.device = BarcodeScanner.cameraWith(position: self.cameraPosition)
        
        if let device = self.device {
            do {
                self.input = try AVCaptureDeviceInput(device: device)
            } catch {
                print(error.localizedDescription)
            }
        }
        
        if let input = self.input {
            for inputToRemove in self.session.inputs {
                self.session.removeInput(inputToRemove)
            }
            self.session.addInput(input)
        }
        
        // live video output
        self.metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        for outputToRemove in self.session.outputs {
            self.session.removeOutput(outputToRemove)
        }
        self.session.addOutput(self.metadataOutput)
        self.metadataOutput.metadataObjectTypes = self.metadataOutput.availableMetadataObjectTypes
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
        
        if let previewLayer = self.previewLayer {
            previewLayer.frame = self.frame
            previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
            if let previewLayerConnection = previewLayer.connection {
                previewLayerConnection.videoOrientation = BarcodeScanner.videoOrientationFromCurrentDeviceOrientation()
            }
            self.layer.addSublayer(previewLayer)
        }
        
        self.session.startRunning()
    }
    
    @objc public func stopCapture() -> Void {
        self.previewLayer?.removeFromSuperlayer()
        self.previewLayer = nil
        self.input = nil
        self.device = nil
        self.session.stopRunning()
        self.metadataOutput.setMetadataObjectsDelegate(nil, queue: DispatchQueue.main)
    }
    
    @objc public func cancelBarcodeScanning() -> Void {
        self.stopCapture()
        self.detectionString = nil
    }
    
    // MARK: - Rect of the interest (real scanning area)
    
    @objc public func setInterestRect(for imageView: UIImageView) -> Void {
        //MPOS-8611 Visual recognition have problems on iPhones screens detecting the limits of the barcode, so rectOfInterest differs between tablet or phone as below to achieve good user experience
//        if UIDevice.current.userInterfaceIdiom == .pad {
//            let holeFrame: CGRect! = imageView.frame
//            self.metadataOutput.rectOfInterest = CGRect(
//                x: holeFrame.origin.x / self.frame.size.width,
//                y: holeFrame.origin.y / self.frame.size.height,
//                width: holeFrame.size.width / self.frame.size.width,
//                height: holeFrame.size.height / self.frame.size.height
//            )
//        } else {
//            let orientation = UIApplication.shared.statusBarOrientation
//            if orientation == .landscapeLeft || orientation == .landscapeRight {
//                self.metadataOutput.rectOfInterest = CGRect(x: 0.2, y: 0.2, width: 0.8, height: 0.6)
//            } else {
//                self.metadataOutput.rectOfInterest = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.8)
//            }
//        }
    }
    
    // MARK: - Camera mode mgmt
    
    @objc public func changeCameraMode() -> Void {
        self.cameraPosition = self.cameraPosition == AVCaptureDevice.Position.back ? AVCaptureDevice.Position.front : AVCaptureDevice.Position.back
    }
    
    // MARK: - Torch mgmt
    
    @objc public func isTorchAvailable() -> Bool {
        return BarcodeScanner.isTorchAvailableForCamera(on: self.cameraPosition)
    }
    
    @objc public static func isTorchAvailableForCamera(on position: AVCaptureDevice.Position) -> Bool {
        if let camera = BarcodeScanner.cameraWith(position: position) {
            return self.isTorchAvaiableFor(camera)
        }
        
        return false
    }
    
    @objc public static func isTorchAvaiableFor(_ camera: AVCaptureDevice) -> Bool {
        return camera.hasTorch && camera.isTorchAvailable && camera.isTorchModeSupported(.on)
    }
    
    @objc public func toggleTorch() -> Void {
        guard let device = self.device, BarcodeScanner.isTorchAvaiableFor(device) else {
            print("Cannot toggle torch: no torch device avaiable.")
            return
        }
        
        do {
            try device.lockForConfiguration()
            if device.torchMode == .on {
                device.torchMode = .off
            } else {
                do {
                    try device.setTorchModeOn(level: 1.0)
                } catch {
                    print("Cannot toggle torch: \(error.localizedDescription)")
                }
            }
            device.unlockForConfiguration()
        } catch {
            print("Cannot toggle torch: \(error.localizedDescription)")
        }
    }
    
    @objc public func isTorchActive() -> Bool {
        if let device = self.device {
            return self.isTorchAvailable() && device.torchMode == .on
        }
        return false
    }
    
    @objc public func isTorchMatching(uiState uiEnabled: Bool) -> Bool {
        if let device = self.device, device.torchMode == (uiEnabled ? AVCaptureDevice.TorchMode.off : AVCaptureDevice.TorchMode.on) {
            return true
        }
        
        return false
    }
    
    // MARK: - Observers
    
    @objc public func orientationDidChange(notification: NSNotification) -> Void {
        self.updateOrientation()
        if let parentVC = self.parentVC {
            self.setInterestRect(for: parentVC.centralHoleImageView)
        }
    }
    
    // MARK: - Private helpers
    
    private func updateOrientation() -> Void {
        if let parentBounds = self.parentVC?.view.bounds {
            self.previewLayer?.frame = parentBounds
        }
        if self.previewLayer?.connection?.isVideoOrientationSupported ?? false {
            self.previewLayer?.connection?.videoOrientation = BarcodeScanner.videoOrientationFromCurrentDeviceOrientation()
        }
    }
    
    private static func cameraWith(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if #available(iOS 10.0, *) {
            return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
        } else {
            // Fallback on earlier versions
            let devices: [AVCaptureDevice] = AVCaptureDevice.devices(for: AVMediaType.video)
            
            return devices.filter { (device) -> Bool in
                return device.position == position
            }.first
        }
    }
    
    private func setStyle() -> Void {
        self.layer.backgroundColor = UIColor.clear.cgColor
    }
    
    private static func videoOrientationFromCurrentDeviceOrientation() -> AVCaptureVideoOrientation {
        switch UIApplication.shared.statusBarOrientation {
        case .portrait:
            return .portrait
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .unknown:
            fallthrough
        @unknown default:
            return .portrait
        }
    }
    
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
@objc extension BarcodeScanner: AVCaptureMetadataOutputObjectsDelegate {
    
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        let barCodeTypes: [AVMetadataObject.ObjectType] = [
            .upce, .code39, .code39Mod43, .ean13, .ean8, .code93, .code128, .pdf417, .qr, .aztec, .itf14, .dataMatrix
        ]
        
        for case let metadata as AVMetadataMachineReadableCodeObject in metadataObjects {
            for type in barCodeTypes {
                if metadata.type == type {
                    self.detectionString = metadata.stringValue
                    self.barCodeType = type
                    break
                }
            }
            break
        }
        
        // We will allow only one scanning per 2 seconds.
        if !self.inWaitDelay && !self.inDelegateWait {
            self.inWaitDelay = true
            if let barCodeString = self.detectionString, let barCodeType = self.barCodeType {
                self.delegate?.finishedBarcodeScan?(barcodeData: barCodeString, type: barCodeType.rawValue)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + BarcodeScannerConstants.kDelayForNextBarcodeReading, execute: {
                self.inWaitDelay = false
            })
            
            self.detectionString = nil
            self.barCodeType = nil
        }
    }
    
}
