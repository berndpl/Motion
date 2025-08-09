//
//  ContentView.swift
//  Motion
//
//  Created by Bernd Plontsch on 30.07.2025.
//

import SwiftUI
import Foundation

enum AppState {
    case initial
    case processing
    case response
}

struct ContentView: View {
    @AppStorage("promptText") private var promptText = "Create a short summary of the following content "
    @State private var sparkContent = ""
    @State private var responseText = ""
    @State private var errorMessage: String?
    @State private var ollamaURL = "http://127.0.0.1:11434"
    @State private var modelName = "llama3"
    @State private var fileCount = 0
    @State private var showMoreSection = false
    @State private var appState: AppState = .initial
    
    // MARK: - Preview-only initializer
    #if DEBUG
    init(
        previewAppState: AppState = .initial,
        promptText: String = "Create a short summary of the following content ",
        sparkContent: String = "",
        responseText: String = "",
        errorMessage: String? = nil,
        fileCount: Int = 0,
        ollamaURL: String = "http://127.0.0.1:11434",
        modelName: String = "llama3"
    ) {
        // Seed AppStorage for previews
        UserDefaults.standard.set(promptText, forKey: "promptText")
        self._sparkContent = State(initialValue: sparkContent)
        self._responseText = State(initialValue: responseText)
        self._errorMessage = State(initialValue: errorMessage)
        self._ollamaURL = State(initialValue: ollamaURL)
        self._modelName = State(initialValue: modelName)
        self._fileCount = State(initialValue: fileCount)
        self._showMoreSection = State(initialValue: false)
        self._appState = State(initialValue: previewAppState)
    }
    #endif
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Single text view that shows prompt or response based on state
                TextEditor(text: textBinding)
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
                    .disabled(appState == .processing)
                    .foregroundColor(errorMessage != nil ? .red : .primary)
                    .scrollIndicators(.hidden)
                
                // Button and spinner container
                HStack {
                    Button(action: buttonAction) {
                        if appState == .response {
                            Image(systemName: "arrow.counterclockwise")
                        } else {
                            Text(buttonText)
                        }
                    }
                    .disabled(appState == .processing || (appState == .initial && sparkContent.isEmpty))
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    // Small spinner next to button during processing
                    if appState == .processing {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 20, height: 20)
                    }
                    
                    Spacer()
                }
                
                // Options sheet content
                .sheet(isPresented: $showMoreSection) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        HStack {
                            Text("Options")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Spacer()
                            Button("Done") {
                                showMoreSection = false
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        // File count display
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Spark Files")
                                .font(.headline)
                            
                            HStack {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.blue)
                                Text("\(fileCount) files loaded")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                        
                        // Content field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("All Sparks as Text")
                                .font(.headline)
                            
                            TextEditor(text: $sparkContent)
                                .frame(minHeight: 150)
                                .padding(8)
                                .background(Color(.textBackgroundColor))
                                .cornerRadius(8)
                                .scrollIndicators(.hidden)
                        }
                        
                        // Ollama server info
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ollama Server Info")
                                .font(.headline)
                            
                            TextField("Ollama URL", text: $ollamaURL)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disableAutocorrection(true)
                            
                            TextField("Model Name", text: $modelName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disableAutocorrection(true)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .frame(minWidth: 400, minHeight: 500)
                }
            }
            .padding()
            .navigationTitle("\(fileCount) Sparks loaded")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showMoreSection.toggle()
                        }
                    }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .onAppear {
            loadSparkContent()
        }
    }
    
    // Computed properties for state-based UI
    private var textBinding: Binding<String> {
        switch appState {
        case .initial:
            return $promptText
        case .processing:
            return .constant(promptText)
        case .response:
            return .constant(errorMessage ?? responseText)
        }
    }
    
    private var buttonText: String {
        switch appState {
        case .initial:
            return "Generate"
        case .processing:
            return "Processing..."
        case .response:
            return "Reset"
        }
    }
    
    private func buttonAction() {
        switch appState {
        case .initial:
            generateContent()
        case .processing:
            break // Button is disabled during processing
        case .response:
            resetToInitial()
        }
    }
    
    private func generateContent() {
        guard !sparkContent.isEmpty else { return }
        
        appState = .processing
        responseText = ""
        errorMessage = nil
        
        Task {
            do {
                let combinedPrompt = promptText + sparkContent
                let response = try await callOllamaAPI(prompt: combinedPrompt)
                await MainActor.run {
                    responseText = response
                    errorMessage = nil
                    appState = .response
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
                    appState = .response
                }
            }
        }
    }
    
    private func resetToInitial() {
        appState = .initial
        responseText = ""
        errorMessage = nil
        // promptText is persisted via @AppStorage and remains unchanged
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

#Preview("Initial State") {
    let sampleSparks = "- Opened article about deep work\n- Saved location: Brighton Beach\n- Screenshot: meeting agenda notes\n"
    return ContentView(
        previewAppState: .initial,
        promptText: "Create a short summary of the following content ",
        sparkContent: sampleSparks,
        responseText: "",
        errorMessage: nil,
        fileCount: 3
    )
    .frame(width: 420, height: 360)
}

#Preview("Processing State") {
    let sampleSparks = String(repeating: "• Spark line example\n", count: 8)
    return ContentView(
        previewAppState: .processing,
        sparkContent: sampleSparks,
        fileCount: 8
    )
    .frame(width: 420, height: 360)
}

#Preview("Response State - Success") {
    let sampleResponse = "Here are the next steps based on your sparks:\n\n1. Block a 2-hour deep work session tomorrow morning.\n2. Add a reminder to visit Brighton Beach this weekend.\n3. Turn the meeting agenda notes into action items in Reminders."
    return ContentView(
        previewAppState: .response,
        responseText: sampleResponse,
        fileCount: 3
    )
    .frame(width: 420, height: 360)
}

#Preview("Response State - Error") {
    return ContentView(
        previewAppState: .response,
        responseText: "",
        errorMessage: "❌ Connection refused.\n\nOllama might not be running. Try:\n• ollama serve\n• Check the port (default: 11434)",
        fileCount: 3
    )
    .frame(width: 420, height: 360)
}
