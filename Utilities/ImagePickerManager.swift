//
//  String.swift
//  ProjectMagick
//
//  Created by Kishan on 31/05/20.
//  Copyright © 2020 Kishan. All rights reserved.
//

import UIKit
import Photos
import PhotosUI
import TOCropViewController
import ProjectMagick


@objc public protocol ImageDidReceivedDelegate {
    func imagePickUpFinish(image: UIImage, imageView : ImagePickerManagerX)
    @objc optional func pickerDidCancel()
    
    @available(iOS 14, *)
    func imagePickupDidFinish(images : [UIImage], imageView : ImagePickerManagerX)
    
}

open class ImagePickerManagerX: UIImageView {
    
    lazy var imagePicker : UIImagePickerController = {
        return UIImagePickerController()
    }()
    public weak var delegate : ImageDidReceivedDelegate?
    public var isEditMode : Bool = true
    public var selectionLimit = 1
    public var autoApplyImage = true
    public var isCropcontrollerEnabled = true
    public var projectName = AppInfo.appName
    public var cameraPermissionDeniedTitle = ""
    public var galleryPermissionDeniedTitle = ""
    
    

    public override func awakeFromNib() {
        super.awakeFromNib()
        initialize()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    //MARK:- Private functions
    private func setImage(image : UIImage?) {
        self.image = image
    }
    
    
    
    @available(iOS 14, *)
    private func pickerViewController() -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = selectionLimit
        config.preferredAssetRepresentationMode = .current
        let vc = PHPickerViewController(configuration: config)
        vc.delegate = self
        return vc
    }
    
    private func checkPermissionForCamera(vc : UIViewController) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async {
                self.imagePicker.sourceType = .camera
                vc.present(self.imagePicker, animated: true)
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { (response) in
                if response == (AVCaptureDevice.authorizationStatus(for: .video) == .authorized) {
                    DispatchQueue.main.async {
                        self.imagePicker.sourceType = .camera
                        vc.present(self.imagePicker, animated: true)
                    }
                }
            }
        case .restricted :
            return
        case .denied:
            
            ShowAlert(title: projectName, message: cameraPermissionDeniedTitle.isEmpty ? AlertMessages.cameraPermission : cameraPermissionDeniedTitle, buttonTitles: [SmallTitles.cancel,SmallTitles.settings], highlightedButtonIndex: 1) { (buttonNumber) in
                if buttonNumber == 1 {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:])
                }
            }
             
            break
        default:
            break
        }
        
    }
    
    private func checkPermissionForGallery(vc : UIViewController) {
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized, .limited:
            DispatchQueue.main.async {
                self.imagePicker.sourceType = .photoLibrary
                if #available(iOS 14, *) {
                    vc.present(self.pickerViewController(), animated: true)
                } else {
                    vc.present(self.imagePicker, animated: true)
                }
            }
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { (status) in
                if status == PHAuthorizationStatus.authorized {
                    DispatchQueue.main.async {
                        if #available(iOS 14, *) {
                            vc.present(self.pickerViewController(), animated: true)
                        } else {
                            self.imagePicker.sourceType = .photoLibrary
                            vc.present(self.imagePicker, animated: true)
                        }
                    }
                }
            }
        case .restricted:
            return
        case .denied:
            
            ShowAlert(title: projectName, message: galleryPermissionDeniedTitle.isEmpty ? AlertMessages.photoLibrary : galleryPermissionDeniedTitle, buttonTitles: [SmallTitles.cancel,SmallTitles.settings], highlightedButtonIndex: 1) { (buttonNumber) in
                if buttonNumber == 1 {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:])
                }
            }
        default:
            break
        }
    }
    
    private func openCropViewController(image : UIImage) {
        let cropVC = TOCropViewController(image: image)
        cropVC.delegate = self
        parentViewController?.present(cropVC, animated: false)
    }
    
}


//MARK:- ImagePickerController Delegate Method
extension ImagePickerManagerX : UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        imagePicker.dismiss(animated: true, completion: {
            self.delegate?.pickerDidCancel?()
        })
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        var finalImage = UIImage()
        if let image = info[.editedImage] as? UIImage {
            finalImage = image
        } else if let image = info[.originalImage] as? UIImage {
            finalImage = image
        }
        if isCropcontrollerEnabled {
            picker.dismiss(animated: false) { [weak self] in
                guard let self = self else { return }
                self.openCropViewController(image: finalImage)
            }
        } else {
            if autoApplyImage {
                setImage(image: finalImage)
            }
            delegate?.imagePickUpFinish(image: finalImage, imageView: self)
            picker.dismiss(animated: true)
        }
    }
    
}


public extension ImagePickerManagerX {
    
    
    //MARK:- ImageView Configure Method
    func initialize() {
        isUserInteractionEnabled = true
        clipsToBounds = true
        let gesture = UITapGestureRecognizer(target: self, action: #selector(openWithTap(_:)))
        addGestureRecognizer(gesture)
        imagePicker.delegate = self
        contentMode = .scaleAspectFill
    }
    
    //MARK:- ImageView TapGesture Handle Method
    @objc func openWithTap(_ sender: UITapGestureRecognizer) {
        if let vc = parentViewController {
            imgPickerOpen(this: vc, imagePicker: imagePicker, sourceControl: self)
        }
    }
    
    @IBAction func touchUpInside(_ sender: Any) {
        if let vc = parentViewController {
            imgPickerOpen(this: vc, imagePicker: imagePicker, sourceControl: self)
        }
    }

    
    //MARK:- ActionSheet Method
    private func imgPickerOpen(this: UIViewController, imagePicker: UIImagePickerController, sourceControl: UIView) {
        
        this.view.endEditing(true)
        
        imagePicker.allowsEditing = isEditMode
        
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: SmallTitles.camera.localized(), style: .default, handler: { (UIAlertAction) in
            
            if DeviceDetail.isSimulator {
                return
            }
            self.checkPermissionForCamera(vc: this)
        }))
        
        actionSheet.addAction(UIAlertAction(title: SmallTitles.gallery.localized(), style: .default, handler: { (UIAlertAction) in
            self.checkPermissionForGallery(vc: this)
        }))
        
        actionSheet.addAction(UIAlertAction(title: SmallTitles.cancel.localized(), style: .cancel))
        
        
        if !DeviceDetail.isIPhone {
            actionSheet.popoverPresentationController?.sourceView = sourceControl
            actionSheet.popoverPresentationController?.sourceRect = sourceControl.bounds
        }
        
        this.present(actionSheet, animated: true)
        
    }
    
}

extension ImagePickerManagerX : TOCropViewControllerDelegate {
    
    public func cropViewController(_ cropViewController: TOCropViewController, didCropTo image: UIImage, with cropRect: CGRect, angle: Int) {
        if autoApplyImage {
            setImage(image: image)
        }
        delegate?.imagePickUpFinish(image: image, imageView: self)
        parentViewController?.dismiss(animated: true)
    }
    
    public func cropViewController(_ cropViewController: TOCropViewController, didFinishCancelled cancelled: Bool) {
        parentViewController?.dismiss(animated: true, completion: nil)
    }
}


@available(iOS 14, *)
extension ImagePickerManagerX : PHPickerViewControllerDelegate {
    
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            if results.isEmpty {
                self.delegate?.pickerDidCancel?()
            } else {
                let dispatchGroup = DispatchGroup()
                var images = [UIImage]()
                for result in results {
                    dispatchGroup.enter()
                    result.itemProvider.loadObject(ofClass: UIImage.self, completionHandler: { (object, error) in
                        if let image = object as? UIImage {
                            DispatchQueue.main.async {
                                images.append(image)
                                dispatchGroup.leave()
                            }
                        }
                    })
                }
                dispatchGroup.notify(queue: DispatchQueue.main) {
                    if self.isCropcontrollerEnabled {
                        picker.dismiss(animated: false) { [weak self] in
                            guard let self = self else { return }
                            self.openCropViewController(image: images.first!)
                        }
                    } else {
                        if self.autoApplyImage, images.count == 1 {
                            self.setImage(image: images.first!)
                        }
                        self.delegate?.imagePickupDidFinish(images: images, imageView: self)
                    }
                }
            }
        }
    }
    
}
