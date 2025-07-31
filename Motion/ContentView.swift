//
//  ContentView.swift
//  Motion
//
//  Created by Bernd Plontsch on 30.07.2025.
//

import SwiftUI
import Foundation

struct ContentView: View {
    @State private var promptText = "Create a short summary of the following content "
    @State private var sparkContent = ""
    @State private var responseText = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var ollamaURL = "http://127.0.0.1:11434"
    @State private var modelName = "llama3"
    @State private var fileCount = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // File count display
                HStack {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.blue)
                    Text("\(fileCount) Spark files loaded")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                // Prompt and Content text fields
                VStack(alignment: .leading, spacing: 16) {
                    // Prompt field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prompt")
                            .font(.headline)
                        
                        TextEditor(text: $promptText)
                            .frame(minHeight: 80)
                            .padding(8)
                            .background(Color(.gray))
                            .cornerRadius(8)
                    }
                    
                    // Content field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content")
                            .font(.headline)
                        
                        TextEditor(text: $sparkContent)
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(Color(.gray))
                            .cornerRadius(8)
                    }
                }
                
                // Summarize button
                Button(action: summarizeContent) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isProcessing ? "Processing..." : "Summarize")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isProcessing ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isProcessing || sparkContent.isEmpty)
                
                // Response text view
                VStack(alignment: .leading, spacing: 8) {
                    Text("Response")
                        .font(.headline)
                    
                    TextEditor(text: .constant(errorMessage ?? responseText))
                        .frame(minHeight: 150)
                        .padding(8)
                        .background(Color(.gray))
                        .cornerRadius(8)
                        .foregroundColor(errorMessage != nil ? .red : .primary)
                }
                
                // Ollama URL configuration
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ollama Server")
                        .font(.headline)
                    
                    TextField("Ollama URL", text: $ollamaURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disableAutocorrection(true)
                    
                    TextField("Model Name",
                              text: $modelName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disableAutocorrection(true)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Motion")
        }
        .onAppear {
            loadSparkContent()
        }
    }
    
    private func loadSparkContent() {
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.de.plontsch.journey.shared") else {
            errorMessage = "iCloud container not available"
            return
        }
        
        var allFiles: [URL] = []
        searchDirectory(url: containerURL, files: &allFiles, level: 0)
        
        var combinedContent = ""
        var loadedFiles = 0
        for file in allFiles {
            if let content = try? String(contentsOf: file, encoding: .utf8) {
                combinedContent += content + "\n\n"
                loadedFiles += 1
            }
        }
        
        sparkContent = combinedContent
        fileCount = loadedFiles
    }
    
    private func searchDirectory(url: URL, files: inout [URL], level: Int) {
        do {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    let contents = try FileManager.default.contentsOfDirectory(
                        at: url,
                        includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                        options: []
                    )
                    
                    for item in contents {
                        let resourceValues = try? item.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
                        let isFile = resourceValues?.isRegularFile == true
                        let isDir = resourceValues?.isDirectory == true
                        
                        if isFile {
                            files.append(item)
                        } else if isDir && level < 10 {
                            searchDirectory(url: item, files: &files, level: level + 1)
                        }
                    }
                }
            }
        } catch {
            // Silently ignore errors
        }
    }
    
    private func summarizeContent() {
        guard !sparkContent.isEmpty else { return }
        
        isProcessing = true
        responseText = ""
        errorMessage = nil
        
        Task {
            do {
                let combinedPrompt = promptText + sparkContent
                let response = try await callOllamaAPI(prompt: combinedPrompt)
                await MainActor.run {
                    responseText = response
                    errorMessage = nil
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    if let urlError = error as? URLError {
                        switch urlError.code {
                        case .cannotFindHost:
                            errorMessage = "❌ Cannot connect to Ollama server.\n\nMake sure:\n1. Ollama is running (run 'ollama serve')\n2. The URL is correct\n3. If using simulator, try your Mac's IP instead of localhost"
                        case .cannotConnectToHost:
                            errorMessage = "❌ Connection refused.\n\nOllama might not be running. Try:\n• ollama serve\n• Check the port (default: 11434)"
                        default:
                            errorMessage = "❌ Network error: \(urlError.localizedDescription)"
                        }
                    } else {
                        errorMessage = "❌ Error: \(error.localizedDescription)"
                    }
                    responseText = ""
                    isProcessing = false
                }
            }
        }
    }
    
    private func callOllamaAPI(prompt: String) async throws -> String {
        guard let url = URL(string: "\(ollamaURL)/api/generate") else {
            throw URLError(.badURL)
        }
        
        let requestBody: [String: Any] = [
            "model": modelName,
            "prompt": prompt,
            "stream": false
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check HTTP status code
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode != 200 {
                let responseString = String(data: data, encoding: .utf8) ?? "<no response>"
                throw NSError(domain: "OllamaError", code: httpResponse.statusCode, 
                             userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(responseString)"])
            }
        }
        
        // Try to parse JSON response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let responseString = String(data: data, encoding: .utf8) ?? "<invalid data>"
            throw NSError(domain: "OllamaError", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response: \(responseString)"])
        }
        
        // Check for error in response
        if let error = json["error"] as? String {
            throw NSError(domain: "OllamaError", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Ollama error: \(error)"])
        }
        
        // Get the response text
        guard let responseText = json["response"] as? String else {
            throw NSError(domain: "OllamaError", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "No 'response' field in JSON: \(json)"])
        }
        
        return responseText
    }
}

#Preview {
    ContentView()
}
