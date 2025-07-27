//
//  VoiceService.swift
//  CookMaa
//
//  Created by Sudhanva Acharya on 27/07/25.
//

import Foundation
import Speech
import AVFoundation
// import PipecatClientIOS - Uncomment when SPM dependencies are added

@MainActor
class VoiceService: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var recognizedText = ""
    @Published var error: VoiceError?
    @Published var isConnectedToPipecat = false
    @Published var botResponse = ""
    
    // Native iOS Speech Recognition (fallback)
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Pipecat Integration
    // private var pipecatClient: RTVIClient? - Uncomment when dependencies added
    private var usePipecat = false // Toggle between native and Pipecat
    
    // Current recipe context for voice interactions
    private var currentRecipe: Recipe?
    private var currentStepIndex: Int = 0
    
    override init() {
        super.init()
        setupSpeechRecognizer()
        // setupPipecatClient() - Uncomment when dependencies added
    }
    
    // MARK: - Recipe Context Management
    func setCurrentRecipe(_ recipe: Recipe, stepIndex: Int = 0) {
        currentRecipe = recipe
        currentStepIndex = stepIndex
        print("🎯 Voice context set: \(recipe.title), step \(stepIndex + 1)")
    }
    
    func getCurrentStep() -> CookingStep? {
        guard let recipe = currentRecipe,
              currentStepIndex < recipe.steps.count else { return nil }
        return recipe.steps[currentStepIndex]
    }
    
    func moveToNextStep() -> CookingStep? {
        guard let recipe = currentRecipe else { return nil }
        currentStepIndex = min(currentStepIndex + 1, recipe.steps.count - 1)
        return getCurrentStep()
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.delegate = self
    }
    
    // MARK: - Pipecat Integration (Future Implementation)
    private func setupPipecatClient() {
        // TODO: Implement when Pipecat dependencies are added
        /*
        let clientConfig = [
            ServiceConfig(
                service: "llm",
                options: [
                    Option(name: "model", value: .string("gemini-1.5-flash")),
                    Option(name: "messages", value: .array([
                        .object([
                            "role": .string("system"),
                            "content": .string(buildCookingSystemPrompt())
                        ])
                    ]))
                ]
            ),
            ServiceConfig(
                service: "tts",
                options: [
                    Option(name: "voice", value: .string("multilingual-cooking-assistant"))
                ]
            )
        ]
        
        let options = RTVIClientOptions(
            enableMic: true,
            params: RTVIClientParams(
                baseUrl: Bundle.main.infoDictionary?["PIPECAT_API_URL"] as? String ?? "",
                config: clientConfig
            )
        )
        
        pipecatClient = RTVIClient(
            transport: DailyTransport(options: options),
            options: options
        )
        */
    }
    
    private func buildCookingSystemPrompt() -> String {
        guard let recipe = currentRecipe else {
            return "You are Kukma, a helpful cooking assistant. Respond naturally and provide cooking guidance."
        }
        
        let currentStep = getCurrentStep()
        let stepInfo = currentStep != nil ? "Current step: \(currentStep!.instruction)" : "No current step"
        
        return """
        You are Kukma, an expert cooking assistant helping with the recipe: \(recipe.title).
        
        \(stepInfo)
        
        Recipe context:
        - Cuisine: \(recipe.cuisine ?? "Unknown")
        - Servings: \(recipe.servings)
        - Difficulty: \(recipe.difficulty.rawValue)
        - Total time: \(recipe.totalTimeFormatted)
        
        Chef's wisdom: \(recipe.chefsWisdom ?? "No additional notes")
        
        Respond conversationally and naturally. For step instructions, be detailed and encouraging. 
        Always consider the current cooking context and step when responding.
        
        Handle these voice commands naturally:
        - "Hey Kukma, next step" - Move to next step and explain
        - "Hey Kukma, repeat that" - Repeat current step
        - "Hey Kukma, I have a question" - Ready for cooking questions
        - "Hey Kukma, how long should this take?" - Provide timing info
        """
    }
    
    func connectToPipecat() async {
        // TODO: Implement when Pipecat dependencies are added
        /*
        do {
            try await pipecatClient?.start()
            isConnectedToPipecat = true
            usePipecat = true
            print("🎤 Connected to Pipecat voice pipeline")
        } catch {
            print("❌ Failed to connect to Pipecat: \(error)")
            error = VoiceError.pipecatConnectionFailed(error.localizedDescription)
            usePipecat = false
        }
        */
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
        guard let nextStep = moveToNextStep() else {
            speakResponse("You've completed all the steps! Your dish is ready to serve.")
            return
        }
        
        let response = generateStepResponse(nextStep)
        speakResponse(response)
        NotificationCenter.default.post(name: .voiceCommandReceived, object: VoiceCommand.nextStep)
    }
    
    private func handleRepeatCommand() {
        guard let currentStep = getCurrentStep() else {
            speakResponse("No current step to repeat. Say 'Hey Kukma, next step' to continue.")
            return
        }
        
        let response = generateStepResponse(currentStep, isRepeat: true)
        speakResponse(response)
        NotificationCenter.default.post(name: .voiceCommandReceived, object: VoiceCommand.repeat)
    }
    
    private func handleQuestionCommand() {
        speakResponse("I'm here to help! What's your cooking question? I can see what you're working on.")
        NotificationCenter.default.post(name: .voiceCommandReceived, object: VoiceCommand.question)
    }
    
    private func handleTimingCommand() {
        guard let currentStep = getCurrentStep() else {
            speakResponse("No active cooking step right now.")
            return
        }
        
        let timingResponse = generateTimingResponse(currentStep)
        speakResponse(timingResponse)
        NotificationCenter.default.post(name: .voiceCommandReceived, object: VoiceCommand.timing)
    }
    
    // MARK: - Response Generation
    private func generateStepResponse(_ step: CookingStep, isRepeat: Bool = false) -> String {
        let prefix = isRepeat ? "Let me repeat that step. " : "Next, "
        var response = "\(prefix)\(step.instruction)"
        
        if let time = step.displayTime {
            response += " This should take about \(time)."
        }
        
        if let technique = step.technique {
            response += " Remember to use the \(technique) technique."
        }
        
        if let temperature = step.temperature {
            response += " Keep the heat at \(temperature)."
        }
        
        return response
    }
    
    private func generateTimingResponse(_ step: CookingStep) -> String {
        if let time = step.displayTime {
            return "This step should take about \(time). \(step.instruction)"
        } else {
            return "No specific timing for this step. Just go by the visual cues I mentioned."
        }
    }
    
    // MARK: - Text-to-Speech
    private func speakResponse(_ text: String) {
        DispatchQueue.main.async {
            self.botResponse = text
        }
        
        if usePipecat {
            // TODO: Use Pipecat TTS when available
            // pipecatClient?.speak(text)
        } else {
            speakWithNativeTTS(text)
        }
    }
    
    private func speakWithNativeTTS(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5 // Slower for cooking instructions
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.8
        
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
        
        print("🔊 Speaking: \(text)")
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
    case pipecatConnectionFailed(String)
    case pipecatNotConfigured
    
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
        case .pipecatConnectionFailed(let message):
            return "Failed to connect to Pipecat voice service: \(message)"
        case .pipecatNotConfigured:
            return "Pipecat voice service is not configured. Add PIPECAT_API_URL to Info.plist"
        }
    }
}

extension Notification.Name {
    static let voiceCommandReceived = Notification.Name("voiceCommandReceived")
}
