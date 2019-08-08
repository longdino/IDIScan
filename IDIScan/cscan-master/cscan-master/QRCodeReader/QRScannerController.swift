//
//  QRScannerController.swift
//  QRCodeReader
//
//  Created by Simon Ng on 13/10/2016.
//  Copyright © 2016 AppCoda. All rights reserved.
//

import UIKit
import AVFoundation

class QRScannerController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {

    @IBOutlet var messageLabel:UILabel!
    @IBOutlet var topbar: UIView!
    
    var captureSession = AVCaptureSession()
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var qrCodeFrameView: UIView?

    private let supportedCodeTypes = [AVMetadataObject.ObjectType.upce,
                                      AVMetadataObject.ObjectType.code39,
                                      AVMetadataObject.ObjectType.code39Mod43,
                                      AVMetadataObject.ObjectType.code93,
                                      AVMetadataObject.ObjectType.code128,
                                      AVMetadataObject.ObjectType.ean8,
                                      AVMetadataObject.ObjectType.ean13,
                                      AVMetadataObject.ObjectType.aztec,
                                      AVMetadataObject.ObjectType.pdf417,
                                      AVMetadataObject.ObjectType.itf14,
                                      AVMetadataObject.ObjectType.dataMatrix,
                                      AVMetadataObject.ObjectType.interleaved2of5,
                                      AVMetadataObject.ObjectType.qr]
   
    // QR Scanner variables
    let qrScanner = QRScanner()
    var codes: [Code] = []
    var code = ""
    
    // Picker View variables
    var pickerData: [String] = []
    var pickerView  = UIPickerView()
    var typeValue = String()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Get the back-facing camera for capturing videos
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera], mediaType: AVMediaType.video, position: .back)
        
        guard let captureDevice = deviceDiscoverySession.devices.first else {
            print("Failed to get the camera device")
            return
        }
        
        do {
            // Get an instance of the AVCaptureDeviceInput class using the previous device object.
            let input = try AVCaptureDeviceInput(device: captureDevice)
            
            // Set the input device on the capture session.
            captureSession.addInput(input)
            
            // Initialize a AVCaptureMetadataOutput object and set it as the output device to the capture session.
            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession.addOutput(captureMetadataOutput)
            
            // Set delegate and use the default dispatch queue to execute the call back
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = supportedCodeTypes
//            captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
            
        } catch {
            // If any error occurs, simply print it out and don't continue any more.
            print(error)
            return
        }
        
        // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer?.frame = view.layer.bounds
        view.layer.addSublayer(videoPreviewLayer!)
        
        // Start video capture.
        captureSession.startRunning()
        
        // Move the message label and top bar to the front
        view.bringSubviewToFront(messageLabel)
        view.bringSubviewToFront(topbar)
        
        // Initialize QR Code Frame to highlight the QR code
        qrCodeFrameView = UIView()
        
        if let qrCodeFrameView = qrCodeFrameView {
            qrCodeFrameView.layer.borderColor = UIColor.green.cgColor
            qrCodeFrameView.layer.borderWidth = 2
            view.addSubview(qrCodeFrameView)
            view.bringSubviewToFront(qrCodeFrameView)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Helper methods

    // PickerView setup
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerData.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return pickerData[row]
    }
    
    var valueSelected: String?
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        valueSelected = pickerData[row] as String
        //print(valueSelected!)
    }
    
    // When the app reads a barcode or QR Code
    func launchApp(decodedURL: String) {
        
        if presentedViewController != nil {
            return
        }
        print("launched")
        
        qrScanner.delegate = self
        // Empty the picker view data
        self.pickerData = []
        
        // Menu pop up
        let alertPrompt = UIAlertController(title: "Open App", message: "You're going to open \(decodedURL)", preferredStyle: .actionSheet)
        // Confirm button
        let confirmAction = UIAlertAction(title: "Confirm", style: UIAlertAction.Style.default, handler: { (action) -> Void in
            
            if let url = URL(string: decodedURL) {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: nil)
                }
            }
        })
        // Send button
        let sendAction = UIAlertAction(title: "Send", style: UIAlertAction.Style.default, handler: { (action) -> Void in
            if let url = URL(string: decodedURL) {
                // Receive the location options to be displayed in picker view
                self.qrScanner.setupNetworkCommunication()
                self.qrScanner.joinServer(code: decodedURL)
                let request = "Location Request"
                self.qrScanner.send(code: request)
                //print("about to receive")
                let list = self.qrScanner.receive()
                self.qrScanner.stopServer()
                
                var location_option = [String]()
                //print(list!)
                if list!.count > 0 {
                    location_option = self.qrScanner.splitMessage(input: list!)!
                }
                //print(location_option)
                //print("options received!")
                
                // Insert new list of location into picker view data
                for i in 0 ..< location_option.count {
                    self.pickerData.insert(location_option[i], at: i)
                }
                
                // Ask location to update in picker view and text field
                let locationAlert = UIAlertController(title: "Choose Location", message: "\n\n\n\n", preferredStyle: .alert)
                locationAlert.isModalInPopover = true
                
                locationAlert.addTextField(configurationHandler: {textField in textField.placeholder = "ex: Room 1"})
                
                let pickerFrame = UIPickerView(frame: CGRect(x: 5, y: 20, width: 250, height: 120))
                
                locationAlert.view.addSubview(pickerFrame)
                pickerFrame.dataSource = self
                pickerFrame.delegate = self

                // Cancel button
                locationAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                
                // Send serial id (QR Code) and location to the server and database
                locationAlert.addAction(UIAlertAction(title: "Send", style: .default, handler: {
                    action in
                    var location = locationAlert.textFields?.first?.text
                    var message = ""
                    // If the user typed location in textfield
                    if location!.count > 0 {
                        print("text field mode")
                        print("URL: \(url)")
                        print("Location: \(String(describing: location))")
                        self.qrScanner.setupNetworkCommunication()
                        self.qrScanner.joinServer(code: decodedURL)
                        //print("sending")
                        self.qrScanner.send(code: decodedURL + "|" + location!)
                        //print("sent")
                        message = self.qrScanner.receive()!
                        self.qrScanner.stopServer()
                        print(message)
                    }
                    
                    // If the user picked location from picker view
                    else {
                        // when the user just clicks send without selecting anything
                        if self.valueSelected == nil {
                            if self.pickerData.count > 0 {
                                self.valueSelected = self.pickerData[0] as String
                            }
                            else {
                                let warningAlert = UIAlertController(title: "Warning!", message: "Nothing is selected!", preferredStyle: .alert)
                                warningAlert.addAction(UIAlertAction(title: "Okay", style: .default, handler: nil))
                                self.present(warningAlert, animated: true, completion: nil)
                                return
                            }
                        }
                        location = String(describing: self.valueSelected)
                        location = location!.replacingOccurrences(of: "Optional(\"", with: "")
                        location = location!.replacingOccurrences(of:"\")", with: "")
                        location = location!.replacingOccurrences(of:"\\", with: "")
                        print("picker view mode")
                        print("URL: \(url)")
                        print("Location: \(location!)")
                        
                        self.qrScanner.setupNetworkCommunication()
                        self.qrScanner.joinServer(code: decodedURL)
                        self.qrScanner.send(code: decodedURL + "|" + location!)
                        message = self.qrScanner.receive()!
                        self.qrScanner.stopServer()
                        print(message)
                    }
                    
                    // Display the prompt showing the information of the device added.
                    let updateAlert = UIAlertController(title: "Device Information", message: message, preferredStyle: .alert)
                    //updateAlert.preferredContentSize = CGSize(width: 300, height: 300)
                    updateAlert.addAction(UIAlertAction(title: "Okay", style: .default, handler: nil))
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.alignment = NSTextAlignment.left
                    
                    let messageText = NSMutableAttributedString(
                        string: message,
                        attributes: [
                            NSAttributedString.Key.paragraphStyle: paragraphStyle,
                        ]
                    )
                    
                    updateAlert.setValue(messageText, forKey: "attributedMessage")
                    self.present(updateAlert, animated: true, completion: nil)
                }))
                self.present(locationAlert, animated: true, completion: nil)
            }
        })
        
        // Cancel button
        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: nil)
        
        alertPrompt.addAction(confirmAction)
        alertPrompt.addAction(sendAction)
        alertPrompt.addAction(cancelAction)
        
        present(alertPrompt, animated: true, completion: nil)
    }
}

extension QRScannerController: AVCaptureMetadataOutputObjectsDelegate {
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Check if the metadataObjects array is not nil and it contains at least one object.
        if metadataObjects.count == 0 {
            qrCodeFrameView?.frame = CGRect.zero
            messageLabel.text = "No QR code is detected"
            return
        }
        
        // Get the metadata object.
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        
        if supportedCodeTypes.contains(metadataObj.type) {
            // If the found metadata is equal to the QR code metadata (or barcode) then update the status label's text and set the bounds
            let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj)
            qrCodeFrameView?.frame = barCodeObject!.bounds
            
            if metadataObj.stringValue != nil {
                launchApp(decodedURL: metadataObj.stringValue!)
                messageLabel.text = metadataObj.stringValue
            }
        }
    }
    
}

//extension QRScannerController: CodeInputDelegate {
//    func sendWasTapped(code: String) {
//        qrScanner.send(code: code)
//    }
//}
//
//extension QRScannerController: QRScannerDelegate {
//    func received(code: Code) {
//        print(code)
//    }
//}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)})
}
