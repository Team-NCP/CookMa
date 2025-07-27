//
//  IngredientReviewView.swift
//  CookMaa
//
//  Created by Sudhanva Acharya on 27/07/25.
//

import SwiftUI

struct IngredientReviewView: View {
    @State private var recipe: Recipe
    @State private var showingCookingView = false
    
    init(recipe: Recipe) {
        self._recipe = State(initialValue: recipe)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            recipeHeader
            
            List {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.element.id) { index, ingredient in
                    IngredientRow(
                        ingredient: ingredient,
                        isAvailable: Binding(
                            get: { recipe.ingredients[index].isAvailable },
                            set: { recipe.ingredients[index].isAvailable = $0 }
                        )
                    )
                }
            }
            .listStyle(.plain)
            
            startCookingButton
        }
        .navigationTitle("Ingredients")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingCookingView) {
            NavigationView {
                CookingView(recipe: recipe)
            }
        }
    }
    
    private var recipeHeader: some View {
        VStack(spacing: 12) {
            Text(recipe.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 20) {
                Label(recipe.totalTimeFormatted, systemImage: "clock")
                Label("\(recipe.servings)", systemImage: "person.2")
                Label(recipe.difficulty.rawValue, systemImage: "chart.bar")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            if let description = recipe.description {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }
    
    private var startCookingButton: some View {
        VStack(spacing: 8) {
            if missingIngredients.count > 0 {
                Text("Missing \(missingIngredients.count) ingredient(s)")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            Button(action: startCooking) {
                HStack {
                    Image(systemName: "flame")
                        .font(.title3)
                    
                    Text("Start Cooking")
                        .font(.headline)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private var missingIngredients: [Ingredient] {
        recipe.ingredients.filter { !$0.isAvailable }
    }
    
    private func startCooking() {
        showingCookingView = true
    }
}

struct IngredientRow: View {
    let ingredient: Ingredient
    @Binding var isAvailable: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: { isAvailable.toggle() }) {
                Image(systemName: isAvailable ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isAvailable ? .green : .gray)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(ingredient.displayText)
                    .font(.body)
                    .strikethrough(isAvailable)
                    .foregroundColor(isAvailable ? .secondary : .primary)
                
                if let notes = ingredient.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isAvailable.toggle()
        }
    }
}

#Preview {
    NavigationView {
        IngredientReviewView(recipe: Recipe(
            title: "Butter Chicken",
            youtubeURL: "https://youtube.com/watch?v=example",
            description: "A creamy, flavorful Indian curry that's perfect for dinner",
            cuisine: "Indian",
            difficulty: .medium,
            totalTime: 3600,
            servings: 4,
            ingredients: [
                Ingredient(name: "Chicken breast", amount: "2", unit: "lbs", notes: "cut into cubes"),
                Ingredient(name: "Tomato sauce", amount: "1", unit: "cup", notes: nil),
                Ingredient(name: "Heavy cream", amount: "1/2", unit: "cup", notes: nil)
            ],
            steps: [],
            chefsWisdom: "This recipe has been passed down through generations. The key is to not rush the cooking process.",
            scalingNotes: "Original recipe serves 4, scaled proportionally",
            originalServings: 4
        ))
    }
}