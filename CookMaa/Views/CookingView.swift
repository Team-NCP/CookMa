//
//  CookingView.swift
//  CookMaa
//
//  Created by Sudhanva Acharya on 27/07/25.
//

import SwiftUI

struct CookingView: View {
    @State private var recipe: Recipe
    @StateObject private var voiceService = VoiceService()
    @State private var showingCamera = false
    
    init(recipe: Recipe) {
        self._recipe = State(initialValue: recipe)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            progressHeader
            
            Spacer()
            
            currentStepContent
            
            Spacer()
            
            controlsSection
        }
        .padding(.horizontal, 20)
        .navigationTitle("Cooking")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            voiceService.startListening()
        }
        .onDisappear {
            voiceService.stopListening()
        }
        .sheet(isPresented: $showingCamera) {
            CameraView()
        }
    }
    
    private var progressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Step \(recipe.currentStepIndex + 1) of \(recipe.steps.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let currentStep = recipe.currentStep,
                   let timeText = currentStep.displayTime {
                    Label(timeText, systemImage: "timer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            ProgressView(value: Double(recipe.currentStepIndex), total: Double(recipe.steps.count))
                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
        }
        .padding(.top, 8)
    }
    
    private var currentStepContent: some View {
        VStack(spacing: 24) {
            if let currentStep = recipe.currentStep {
                VStack(spacing: 16) {
                    Text(currentStep.instruction)
                        .font(.title2)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                    
                    if let technique = currentStep.technique {
                        Label(technique, systemImage: "hands.sparkles")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.1))
                            )
                    }
                    
                    if let temperature = currentStep.temperature {
                        Label(temperature, systemImage: "thermometer.medium")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.orange.opacity(0.1))
                            )
                    }
                }
            } else {
                completionView
            }
        }
    }
    
    private var completionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Recipe Complete!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Great job! Your \(recipe.title) is ready to serve.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var controlsSection: some View {
        VStack(spacing: 16) {
            voiceStatusIndicator
            
            HStack(spacing: 16) {
                Button(action: previousStep) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Previous")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                    )
                    .foregroundColor(.primary)
                }
                .disabled(recipe.currentStepIndex == 0)
                
                Button(action: nextStep) {
                    HStack {
                        Text(recipe.isCompleted ? "Finish" : "Next")
                        if !recipe.isCompleted {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor)
                    )
                    .foregroundColor(.white)
                }
            }
            
            voiceCommands
        }
        .padding(.bottom, 20)
    }
    
    private var voiceStatusIndicator: some View {
        HStack {
            Circle()
                .fill(voiceService.isListening ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            
            Text(voiceService.isListening ? "Say \"Hey Kukma\" to interact" : "Voice assistant paused")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var voiceCommands: some View {
        VStack(spacing: 8) {
            Text("Voice Commands:")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            VStack(spacing: 4) {
                Text("\"Hey Kukma, next step\" - Move to next step")
                Text("\"Hey Kukma, repeat\" - Repeat current instruction")
                Text("\"Hey Kukma, I have a question\" - Open camera for visual Q&A")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
    }
    
    private func previousStep() {
        if recipe.currentStepIndex > 0 {
            recipe.currentStepIndex -= 1
        }
    }
    
    private func nextStep() {
        if recipe.currentStepIndex < recipe.steps.count {
            recipe.currentStepIndex += 1
        }
    }
}

#Preview {
    NavigationView {
        CookingView(recipe: Recipe(
            title: "Butter Chicken",
            youtubeURL: "https://youtube.com/watch?v=example",
            description: "A creamy, flavorful Indian curry",
            cuisine: "Indian",
            difficulty: .medium,
            totalTime: 3600,
            servings: 4,
            ingredients: [],
            steps: [
                CookingStep(
                    stepNumber: 1,
                    instruction: "Heat oil in a large pan over medium heat",
                    detailedExplanation: "Heat about 2 tablespoons of oil in a large pan or skillet over medium heat. You'll know it's ready when the oil starts to shimmer but not smoke.",
                    estimatedTime: 120,
                    temperature: "medium heat",
                    technique: "heating"
                ),
                CookingStep(
                    stepNumber: 2,
                    instruction: "Add chicken and cook until golden brown",
                    detailedExplanation: "Add the marinated chicken pieces to the hot oil. Cook for about 6-8 minutes, turning occasionally, until all sides are golden brown and the chicken is cooked through.",
                    estimatedTime: 480,
                    temperature: "medium-high heat",
                    technique: "searing"
                )
            ],
            chefsWisdom: "The secret is in the marination and slow cooking process.",
            scalingNotes: "Recipe scaled from 4 to 4 servings",
            originalServings: 4
        ))
    }
}