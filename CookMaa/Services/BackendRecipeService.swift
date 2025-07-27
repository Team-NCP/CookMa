//
//  BackendRecipeService.swift
//  CookMaa
//
//  Created by Sudhanva Acharya on 27/07/25.
//

import Foundation

@MainActor
class BackendRecipeService: ObservableObject {
    @Published var isLoading = false
    @Published var error: RecipeError?
    
    private let backendURL = "https://cookmaa-backend-production.up.railway.app"
    private var baseRecipeCache: [String: Recipe] = [:] // Cache base recipes without scaling
    
    func generateRecipe(from youtubeURL: String, forServings targetServings: Int = 4) async throws -> Recipe {
        print("🎬 Starting recipe generation via Railway backend for URL: \(youtubeURL)")
        
        // Check if we have the base recipe cached
        if let baseRecipe = baseRecipeCache[youtubeURL] {
            print("🎯 Found cached base recipe, applying local scaling to \(targetServings) servings")
            return scaleRecipeLocally(baseRecipe, to: targetServings)
        }
        
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
            print("🏁 Recipe generation completed (loading = false)")
        }
        
        guard isValidYouTubeURL(youtubeURL) else {
            print("❌ Invalid YouTube URL provided")
            let error = RecipeError.invalidURL
            self.error = error
            throw error
        }
        
        print("✅ YouTube URL validation passed")
        
        do {
            // Call Railway backend instead of Gemini directly
            let recipe = try await callBackendAPI(youtubeURL: youtubeURL, targetServings: targetServings)
            
            // Cache the base recipe
            baseRecipeCache[youtubeURL] = recipe
            print("💾 Cached base recipe for future scaling")
            print("🎉 Recipe generation successful via Railway backend!")
            
            return recipe
        } catch {
            print("❌ Recipe generation failed: \(error)")
            let recipeError = error as? RecipeError ?? RecipeError.analysisFailure(error.localizedDescription)
            self.error = recipeError
            throw recipeError
        }
    }
    
    private func isValidYouTubeURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        let host = url.host?.lowercased()
        return host == "youtube.com" || host == "www.youtube.com" || host == "youtu.be" || host == "m.youtube.com"
    }
    
    private func callBackendAPI(youtubeURL: String, targetServings: Int) async throws -> Recipe {
        print("🔄 Calling Railway backend API for recipe generation")
        
        guard let url = URL(string: "\(backendURL)/generate-recipe") else {
            throw RecipeError.networkError("Invalid backend URL")
        }
        
        let requestBody = [
            "youtube_url": youtubeURL,
            "target_servings": targetServings
        ] as [String : Any]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300 // 5 minutes for video analysis
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("📦 Request body serialized successfully")
        } catch {
            print("❌ Failed to serialize request body: \(error)")
            throw RecipeError.networkError("Failed to serialize request: \(error.localizedDescription)")
        }
        
        print("🚀 Sending request to Railway backend...")
        print("⏳ Video analysis may take 1-3 minutes...")
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
            print("📨 Received response from Railway backend")
        } catch {
            if let urlError = error as? URLError, urlError.code == .timedOut {
                print("⏰ Request timed out - video analysis took too long")
                throw RecipeError.networkError("Video analysis timed out. Please try with a shorter video or try again later.")
            } else {
                print("❌ Network error: \(error)")
                throw RecipeError.networkError("Network error: \(error.localizedDescription)")
            }
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Failed to cast response to HTTPURLResponse")
            throw RecipeError.networkError("Invalid response type")
        }
        
        print("📊 HTTP Status Code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("❌ API request failed with status \(httpResponse.statusCode)")
            print("❌ Response body: \(responseString)")
            throw RecipeError.networkError("API request failed with status \(httpResponse.statusCode): \(responseString)")
        }
        
        print("✅ Backend API request successful")
        
        // Parse the backend response
        let backendResponse: BackendRecipeResponse
        do {
            backendResponse = try JSONDecoder().decode(BackendRecipeResponse.self, from: data)
            print("✅ Successfully decoded backend response")
        } catch let decodingError {
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("❌ Failed to decode backend response: \(decodingError)")
            print("📄 Raw response: \(responseString)")
            throw RecipeError.analysisFailure("Failed to decode response: \(decodingError.localizedDescription)")
        }
        
        // Convert backend response to iOS Recipe model
        return Recipe(
            title: backendResponse.title,
            youtubeURL: youtubeURL,
            description: backendResponse.description,
            cuisine: backendResponse.cuisine,
            difficulty: DifficultyLevel(rawValue: backendResponse.difficulty) ?? .medium,
            totalTime: TimeInterval(backendResponse.total_time),
            servings: backendResponse.servings,
            ingredients: backendResponse.ingredients.map { ingredientData -> Ingredient in
                Ingredient(
                    name: ingredientData.name,
                    amount: ingredientData.amount,
                    unit: ingredientData.unit,
                    notes: ingredientData.notes
                )
            },
            steps: backendResponse.steps.enumerated().map { (index, stepData) -> CookingStep in
                CookingStep(
                    stepNumber: index + 1,
                    instruction: stepData.instruction,
                    detailedExplanation: stepData.instruction,
                    estimatedTime: stepData.estimated_time.map(TimeInterval.init),
                    temperature: nil,
                    technique: nil
                )
            },
            chefsWisdom: backendResponse.chefs_wisdom,
            scalingNotes: backendResponse.scaling_notes,
            originalServings: backendResponse.original_servings
        )
    }
    
    private func scaleRecipeLocally(_ baseRecipe: Recipe, to targetServings: Int) -> Recipe {
        print("🔢 Scaling recipe locally from \(baseRecipe.servings) to \(targetServings) servings")
        
        let scalingFactor = Double(targetServings) / Double(baseRecipe.servings)
        
        let scaledIngredients = baseRecipe.ingredients.map { ingredient in
            scaleIngredient(ingredient, by: scalingFactor)
        }
        
        return Recipe(
            title: baseRecipe.title,
            youtubeURL: baseRecipe.youtubeURL,
            description: baseRecipe.description,
            cuisine: baseRecipe.cuisine,
            difficulty: baseRecipe.difficulty,
            totalTime: baseRecipe.totalTime,
            servings: targetServings,
            ingredients: scaledIngredients,
            steps: baseRecipe.steps, // Steps remain the same
            chefsWisdom: baseRecipe.chefsWisdom,
            scalingNotes: baseRecipe.scalingNotes,
            originalServings: baseRecipe.originalServings
        )
    }
    
    private func scaleIngredient(_ ingredient: Ingredient, by factor: Double) -> Ingredient {
        // Simple scaling for now - can be enhanced with cooking knowledge later
        let scaledAmount = scaleAmountString(ingredient.amount, by: factor)
        
        return Ingredient(
            name: ingredient.name,
            amount: scaledAmount,
            unit: ingredient.unit,
            notes: ingredient.notes,
            isAvailable: ingredient.isAvailable
        )
    }
    
    private func scaleAmountString(_ amount: String, by factor: Double) -> String {
        // Extract numeric value and scale it
        guard let numericAmount = extractNumericAmount(from: amount) else {
            return amount // If we can't parse, return original
        }
        
        let scaledAmount = numericAmount * factor
        return formatPracticalAmount(scaledAmount)
    }
    
    private func extractNumericAmount(from amount: String) -> Double? {
        let cleanAmount = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle fractions like "1/2"
        if cleanAmount.contains("/") {
            let parts = cleanAmount.components(separatedBy: "/")
            if parts.count == 2,
               let numerator = Double(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)),
               let denominator = Double(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) {
                return numerator / denominator
            }
        }
        
        // Handle regular numbers
        return Double(cleanAmount.components(separatedBy: CharacterSet.letters.union(.whitespaces)).first ?? "")
    }
    
    private func formatPracticalAmount(_ amount: Double) -> String {
        // Round to practical cooking measurements
        if amount < 0.125 {
            return "pinch"
        } else if amount < 0.25 {
            return "1/8"
        } else if amount < 0.375 {
            return "1/4"
        } else if amount < 0.625 {
            return "1/2"
        } else if amount < 0.875 {
            return "3/4"
        } else if amount < 1.5 {
            return "1"
        } else {
            return String(format: "%.1f", amount)
        }
    }
}

// Backend response models
private struct BackendRecipeResponse: Codable {
    let title: String
    let description: String?
    let cuisine: String?
    let difficulty: String
    let total_time: Int
    let servings: Int
    let ingredients: [BackendIngredient]
    let steps: [BackendStep]
    let chefs_wisdom: String?
    let scaling_notes: String?
    let original_servings: Int?
}

private struct BackendIngredient: Codable {
    let name: String
    let amount: String
    let unit: String?
    let notes: String?
}

private struct BackendStep: Codable {
    let instruction: String
    let estimated_time: Int?
}
