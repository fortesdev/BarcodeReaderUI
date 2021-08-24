# BarcodeReaderUI
Swift/iOS Code for presenting a barcode reader using the camera

<img width="400" alt="BarcodeReader UI as popover" src="https://github.com/fortesdev/BarcodeReaderUI/blob/main/barcodeReaderScreen.jpeg">

Usage:

#1 
Set in your info.plist a value for "Privacy - Camera Usage Description" (ie "This app uses the camera to scan barcodes"), otherwise it will not run.

#2 
Define your ViewController as BarcodeReaderVCDelegate. You'll receive the barcode value in the method below:

    extension ViewController: BarcodeReaderVCDelegate {
        func barcodeFound(_ barcode: String) {
            print("Barcode Found!! \(barcode)")
        }    
    }

#3 
Present the Barcode Reader UI from your ViewController setting its delegate from the provided storyboard and class, ie:

    let storyboard = UIStoryboard(name: "BarcodeReader", bundle: nil)
    if let vc = storyboard.instantiateViewController(withIdentifier: "BarcodeReaderVC") as? BarcodeReaderVC {
            vc.modalPresentationStyle = .popover
            vc.delegate = self
            self.present(vc, animated: true)
    }
