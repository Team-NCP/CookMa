//
//  Ingredient.swift
//  CookMaa
//
//  Created by Sudhanva Acharya on 27/07/25.
//

import Foundation

struct Ingredient: Identifiable, Codable {
    let id = UUID()
    let name: String
    let amount: String
    let unit: String?
    let notes: String?
    var isAvailable: Bool = true
    
    var displayText: String {
        var text = amount
        if let unit = unit, !unit.isEmpty {
            text += " \(unit)"
        }
        text += " \(name)"
        if let notes = notes, !notes.isEmpty {
            text += " (\(notes))"
        }
        return text
    }
}