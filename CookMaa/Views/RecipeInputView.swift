//
//  RecipeInputView.swift
//  CookMaa
//
//  Created by Sudhanva Acharya on 27/07/25.
//

import SwiftUI

struct RecipeInputView: View {
    @StateObject private var recipeService = RecipeService()
    @State private var youtubeURL = ""
    @State private var servingSize = 4
    @State private var showingIngredientReview = false
    @State private var generatedRecipe: Recipe?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                headerView
                
                Spacer()
                
                inputSection
                
                Spacer()
                
                generateButton
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationTitle("CookMaa")
            .navigationBarTitleDisplayMode(.large)
            .alert("Error", isPresented: .constant(recipeService.error != nil)) {
                Button("OK") {
                    recipeService.error = nil
                }
            } message: {
                Text(recipeService.error?.localizedDescription ?? "")
            }
        }
        .fullScreenCover(isPresented: $showingIngredientReview) {
            if let recipe = generatedRecipe {
                NavigationView {
                    IngredientReviewView(recipe: recipe)
                        .navigationBarItems(leading: Button("Cancel") {
                            showingIngredientReview = false
                        })
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            Text("AI-Powered Cooking Assistant")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text("Convert YouTube cooking videos into interactive, voice-guided recipes")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var inputSection: some View {
        VStack(spacing: 20) {
            // YouTube URL Input
            VStack(spacing: 16) {
                Text("Paste YouTube URL")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                TextField("https://www.youtube.com/watch?v=...", text: $youtubeURL)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                
                Text("Supports videos from YouTube, including youtube.com and youtu.be links")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Serving Size Input
            VStack(spacing: 12) {
                Text("How many people are you cooking for?")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 20) {
                    Button(action: { decreaseServing() }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(servingSize > 1 ? .accentColor : .gray)
                    }
                    .disabled(servingSize <= 1)
                    
                    VStack {
                        Text("\(servingSize)")
                            .font(.title)
                            .fontWeight(.bold)
                        Text(servingSize == 1 ? "person" : "people")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(minWidth: 80)
                    
                    Button(action: { increaseServing() }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(servingSize < 20 ? .accentColor : .gray)
                    }
                    .disabled(servingSize >= 20)
                }
                .frame(maxWidth: .infinity)
                
                Text("Recipe will be automatically scaled to your serving size")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var generateButton: some View {
        Button(action: generateRecipe) {
            HStack {
                if recipeService.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "wand.and.stars")
                        .font(.title3)
                }
                
                Text(recipeService.isLoading ? "Analyzing Video (1-3 min)..." : "Generate Recipe")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isButtonEnabled ? Color.accentColor : Color.gray)
            )
            .foregroundColor(.white)
        }
        .disabled(!isButtonEnabled || recipeService.isLoading)
        .animation(.easeInOut(duration: 0.2), value: recipeService.isLoading)
    }
    
    private var isButtonEnabled: Bool {
        !youtubeURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func increaseServing() {
        if servingSize < 20 {
            servingSize += 1
        }
    }
    
    private func decreaseServing() {
        if servingSize > 1 {
            servingSize -= 1
        }
    }
    
    private func generateRecipe() {
        Task {
            do {
                let recipe = try await recipeService.generateRecipe(
                    from: youtubeURL.trimmingCharacters(in: .whitespacesAndNewlines),
                    forServings: servingSize
                )
                generatedRecipe = recipe
                showingIngredientReview = true
            } catch {
                // Error is already handled by the service
            }
        }
    }
}

#Preview {
    RecipeInputView()
}