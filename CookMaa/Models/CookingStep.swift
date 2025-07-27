//
//  CookingStep.swift
//  CookMaa
//
//  Created by Sudhanva Acharya on 27/07/25.
//

import Foundation

struct CookingStep: Identifiable, Codable {
    let id = UUID()
    let stepNumber: Int
    let instruction: String
    let detailedExplanation: String?
    let estimatedTime: TimeInterval?
    let temperature: String?
    let technique: String?
    var isCompleted: Bool = false
    
    var displayTime: String? {
        guard let time = estimatedTime else { return nil }
        let minutes = Int(time / 60)
        if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "\(Int(time)) sec"
        }
    }
}