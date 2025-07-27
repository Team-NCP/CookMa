//
//  Recipe.swift
//  CookMaa
//
//  Created by Sudhanva Acharya on 27/07/25.
//

import Foundation

struct Recipe: Identifiable, Codable {
    let id = UUID()
    let title: String
    let youtubeURL: String
    let description: String?
    let cuisine: String?
    let difficulty: DifficultyLevel
    let totalTime: TimeInterval
    let servings: Int
    var ingredients: [Ingredient]
    let steps: [CookingStep]
    var currentStepIndex: Int = 0
    let dateCreated: Date = Date()
    
    // Rich context for voice assistant (not shown in main UI)
    let chefsWisdom: String?
    let scalingNotes: String?
    let originalServings: Int?
    
    var currentStep: CookingStep? {
        guard currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }
    
    var isCompleted: Bool {
        currentStepIndex >= steps.count
    }
    
    var totalTimeFormatted: String {
        let hours = Int(totalTime / 3600)
        let minutes = Int((totalTime.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

enum DifficultyLevel: String, CaseIterable, Codable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    case expert = "Expert"
}