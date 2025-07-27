//
//  CameraService.swift
//  CookMaa
//
//  Created by Sudhanva Acharya on 27/07/25.
//

import Foundation
import AVFoundation
import UIKit

@MainActor
class CameraService: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var session = AVCaptureSession()
    
    private var photoOutput = AVCapturePhotoOutput()
    private var currentPhotoCompletion: ((UIImage?) -> Void)?
    
    override init() {
        super.init()
        checkAuthorization()
        setupSession()
    }
    
    private func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            break
        case .denied, .restricted:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }
    
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            Task { @MainActor in
                self?.isAuthorized = granted
                if granted {
                    self?.setupSession()
                }
            }
        }
    }
    
    private func setupSession() {
        guard isAuthorized else { return }
        
        session.beginConfiguration()
        
        session.sessionPreset = .photo
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        session.commitConfiguration()
        
        Task {
            session.startRunning()
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        currentPhotoCompletion = completion
        
        let settings: AVCapturePhotoSettings
        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        } else {
            settings = AVCapturePhotoSettings()
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            currentPhotoCompletion?(nil)
            return
        }
        
        currentPhotoCompletion?(image)
        currentPhotoCompletion = nil
    }
}