//
//  BarcodeReaderVC.swift
//  NFC Manager
//
//  Created by Francisco Fortes on 06/04/2020.
//  Copyright © 2020 Francisco Fortes. All rights reserved.
//

import UIKit
import AVFoundation

protocol BarcodeReaderVCDelegate {
    func barcodeFound(_ barcode: String)
}

public class BarcodeReaderVC: UIViewController, BarcodeScannerCompatible {
    
    var delegate:BarcodeReaderVCDelegate?    
    @IBOutlet public weak var centralHoleImageView: UIImageView!
    @IBOutlet private weak var lblTitle: UILabel!
    @IBOutlet private weak var lblError: UILabel!
    @IBOutlet weak var closeBtn: UIButton!
    @IBOutlet private weak var centralView: UIView!
    @IBOutlet private weak var strokesImageView: UIImageView!
    @IBOutlet private weak var btnCancel: UIButton!
    
    @IBOutlet private weak var tfManualEntryCode: UITextField!
    @IBOutlet private weak var btnAddManualCode: UIButton!
    
    private var _barcodeScanner: BarcodeScanner?
    private var errorMsgTimer: Timer?
    
    private var _keyboardHeight: CGFloat = 0
    
    override public func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        //centralHoleImageView.tintColor = .init(red: 0/255, green: 0/255, blue: 0/255, alpha: 0.8)
        strokesImageView.tintColor = .white
        btnCancel.tintColor = .red
        
        // Will set compact size class to be displayed correctly in popup
        parent?.setOverrideTraitCollection(UITraitCollection(horizontalSizeClass: .compact), forChild: self)
        
        // If view controller is used inside of the WDBasePopup we need to configure basePopupVC
        self.lblError.isHidden = false
        
        btnAddManualCode.titleLabel?.text = "Use".localized
        lblTitle.text = "Barcode and QR Reader".localized
        lblError.text = "Scan Code for a few seconds".localized
        
        tfManualEntryCode.placeholder = "Enter code".localized
        tfManualEntryCode.delegate = self
        closeBtn.setTitle("Close".localized, for: .normal)
        
        btnAddManualCode.isEnabled = false
        
        NotificationCenter.default.addObserver(self,
            selector: #selector(keyboardWillShow(notification:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(self,
            selector: #selector(keyboardWillHide(notification:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(self,
            selector: #selector(appWillResingActive(notification:)),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func appWillResingActive(notification: NSNotification) {
        view.endEditing(true)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            _keyboardHeight = keyboardSize.height
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanner()
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanner()
        errorMsgTimer?.invalidate()
        errorMsgTimer = nil
    }
    
    // MARK: - BarCodeScanner
    
    @objc fileprivate func startScanner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            self._barcodeScanner = BarcodeScanner(with: self)
            self._barcodeScanner?.tag = 2322
            self._barcodeScanner?.delegate = self
    
            self.view.bringSubviewToFront(self.strokesImageView)
            self.view.bringSubviewToFront(self.centralView)
            self.view.bringSubviewToFront(self.btnCancel)
        }
    }
    
    fileprivate func stopScanner() {
        _barcodeScanner?.stopCapture()
    }
    
    // MARK: - IBActions
    
    @IBAction func onCancelTap(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func onTapBack(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func onToggleCameraBtnTap(_ sender: UIButton) {
        _barcodeScanner?.changeCameraMode()
    }
    
    @IBAction func onTapToggleTorch(_ sender: UIButton) {
        _barcodeScanner?.toggleTorch()
        let isTorchActive: Bool! = _barcodeScanner?.isTorchActive()
        setTorchBtn(to: isTorchActive)
    }
    
    @IBAction func onTapAddCode(_ sender: UIButton) {
        guard let barcode = tfManualEntryCode.text, barcode.count > 0 else {
            return
        }
        handleScanned(barcode)
    }
    
    // MARK: - Private helpers
    
    private func isSupportedBarcode(aValue : String) -> Bool
    {
        return true
    }
    
    private func handleScanned(_ barcode: String) {
        self.delegate?.barcodeFound(barcode)
    }
    
    private func setTorchBtn(to state: Bool) {
    //remove anything torch related
    }

}

extension BarcodeReaderVC: UITextFieldDelegate {
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let text = textField.text, text.isEmpty == false {
            handleScanned(text)
        }
        view.endEditing(true)
        return true
    }
    
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let text = textField.text,
           let textRange = Range(range, in: text) {
            let updatedText = text.replacingCharacters(in: textRange, with: string)
            btnAddManualCode.isEnabled = updatedText.count > 0
        }
        return true
    }
    
}

// MARK: - BarcodeScannerDelegate
extension BarcodeReaderVC: BarcodeScannerDelegate {
    
    public func finishedBarcodeScan(barcodeData: String?, type: String) {
        guard let barcode = barcodeData else {
            return
        }
        //if type.lowercased().contains("ean") {
            //only supported
            handleScanned(barcode)            
       // }
    }
    
}
