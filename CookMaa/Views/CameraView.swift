//
//  CameraView.swift
//  CookMaa
//
//  Created by Sudhanva Acharya on 27/07/25.
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraService = CameraService()
    @State private var capturedImage: UIImage?
    @State private var showingImagePreview = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if cameraService.isAuthorized {
                    CameraPreview(session: cameraService.session)
                        .ignoresSafeArea()
                    
                    VStack {
                        Spacer()
                        
                        cameraControls
                    }
                } else {
                    permissionView
                }
            }
            .navigationTitle("Visual Q&A")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() }
            )
            .onAppear {
                cameraService.requestPermission()
            }
            .sheet(isPresented: $showingImagePreview) {
                if let image = capturedImage {
                    ImagePreviewView(image: image)
                }
            }
        }
    }
    
    private var cameraControls: some View {
        VStack(spacing: 20) {
            Text("Point camera at your food and ask a question")
                .font(.subheadline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.6))
                )
            
            HStack(spacing: 40) {
                Button(action: {}) {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 60, height: 60)
                }
                
                Button(action: capturePhoto) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 2)
                                .frame(width: 70, height: 70)
                        )
                }
                
                Button(action: {}) {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 60, height: 60)
                }
            }
        }
        .padding(.bottom, 40)
    }
    
    private var permissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Camera Access Required")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("CookMaa needs camera access to analyze your food and answer visual questions about your cooking progress.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Grant Permission") {
                cameraService.requestPermission()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private func capturePhoto() {
        cameraService.capturePhoto { image in
            if let image = image {
                capturedImage = image
                showingImagePreview = true
            }
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct ImagePreviewView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var question = ""
    @State private var isAnalyzing = false
    @State private var analysisResult = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                
                VStack(spacing: 12) {
                    Text("Ask about your cooking")
                        .font(.headline)
                    
                    TextField("What would you like to know about this?", text: $question)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(action: analyzeImage) {
                        HStack {
                            if isAnalyzing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isAnalyzing ? "Analyzing..." : "Get Answer")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(question.isEmpty || isAnalyzing)
                }
                .padding(.horizontal)
                
                if !analysisResult.isEmpty {
                    ScrollView {
                        Text(analysisResult)
                            .font(.body)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Visual Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Done") { dismiss() }
            )
        }
    }
    
    private func analyzeImage() {
        isAnalyzing = true
        
        // Placeholder for Moondream integration
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            analysisResult = "Based on the image, your dish appears to be cooking well. The color and texture suggest it's progressing nicely. Continue with the current step for the recommended time."
            isAnalyzing = false
        }
    }
}

#Preview {
    CameraView()
}