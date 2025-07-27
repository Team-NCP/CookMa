//
//  VoiceService.swift
//  CookMaa
//
//  Created by Sudhanva Acharya on 27/07/25.
//

import Foundation
import Speech
import AVFoundation

@MainActor
class VoiceService: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var recognizedText = ""
    @Published var error: VoiceError?
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    override init() {
        super.init()
        setupSpeechRecognizer()
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.delegate = self
    }
    
    func requestPermissions() async -> Bool {
        let speechStatus = await requestSpeechPermission()
        let audioStatus = await requestAudioPermission()
        return speechStatus && audioStatus
    }
    
    private func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    private func requestAudioPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func startListening() {
        guard !audioEngine.isRunning else { return }
        
        Task {
            let hasPermissions = await requestPermissions()
            guard hasPermissions else {
                error = .permissionDenied
                return
            }
            
            try? startRecognition()
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }
    
    private func startRecognition() throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            error = .speechRecognizerUnavailable
            return
        }
        
        stopListening()
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            error = .recognitionRequestFailed
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let error = error {
                    self.error = .recognitionFailed(error.localizedDescription)
                    self.stopListening()
                    return
                }
                
                if let result = result {
                    self.recognizedText = result.bestTranscription.formattedString
                    self.processVoiceCommand(self.recognizedText)
                    
                    if result.isFinal {
                        self.stopListening()
                    }
                }
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        isListening = true
        recognizedText = ""
    }
    
    private func processVoiceCommand(_ text: String) {
        let lowercasedText = text.lowercased()
        
        if lowercasedText.contains("hey kukma") || lowercasedText.contains("hey cookma") {
            handleWakeWordDetected(text)
        }
    }
    
    private func handleWakeWordDetected(_ fullText: String) {
        let lowercasedText = fullText.lowercased()
        
        if lowercasedText.contains("next step") {
            handleNextStepCommand()
        } else if lowercasedText.contains("repeat") {
            handleRepeatCommand()
        } else if lowercasedText.contains("question") {
            handleQuestionCommand()
        } else if lowercasedText.contains("how long") {
            handleTimingCommand()
        }
        
        stopListening()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.startListening()
        }
    }
    
    private func handleNextStepCommand() {
        NotificationCenter.default.post(name: .voiceCommandReceived, object: VoiceCommand.nextStep)
    }
    
    private func handleRepeatCommand() {
        NotificationCenter.default.post(name: .voiceCommandReceived, object: VoiceCommand.repeat)
    }
    
    private func handleQuestionCommand() {
        NotificationCenter.default.post(name: .voiceCommandReceived, object: VoiceCommand.question)
    }
    
    private func handleTimingCommand() {
        NotificationCenter.default.post(name: .voiceCommandReceived, object: VoiceCommand.timing)
    }
}

extension VoiceService: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available {
            error = .speechRecognizerUnavailable
            stopListening()
        }
    }
}

enum VoiceCommand {
    case nextStep
    case `repeat`
    case question
    case timing
}

enum VoiceError: LocalizedError {
    case permissionDenied
    case speechRecognizerUnavailable
    case recognitionRequestFailed
    case recognitionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required for voice commands"
        case .speechRecognizerUnavailable:
            return "Speech recognition is not available"
        case .recognitionRequestFailed:
            return "Failed to create speech recognition request"
        case .recognitionFailed(let message):
            return "Speech recognition failed: \(message)"
        }
    }
}

extension Notification.Name {
    static let voiceCommandReceived = Notification.Name("voiceCommandReceived")
}
