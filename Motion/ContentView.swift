//
//  ContentView.swift
//  Motion
//
//  Created by Bernd Plontsch on 30.07.2025.
//

import SwiftUI
import Foundation
import UserNotifications
#if canImport(SparkKit)
import SparkKit
#endif
#if os(macOS)
import AppKit
#endif

enum AppState {
    case initial
    case processing
    case response
}

struct ContentView: View {
    @StateObject private var sparkLoader = SparkLoader(containerIdentifier: "iCloud.de.plontsch.journey.shared")
    #if os(macOS)
    @StateObject private var promptModel = PromptModel()
    @State private var fullPromptWindowController: NSWindowController?
    #endif
    @AppStorage("promptText") private var savedPromptText = "Highlight one insight from my recent sparks Keep it short and concise. 140 characcters. "
    @AppStorage("instructionText") private var savedInstructionText: String = ""
    @AppStorage("contextText") private var savedContextText: String = ""
    @State private var promptDraftText = "Highlight one insight from my recent sparks Keep it short and concise. 140 characcters. "
    @State private var instructionText: String = ""
    @State private var contextText: String = ""
    @State private var sparkContent = ""
    @State private var sparkItems: [SparkItem] = []
    @State private var selectedSparkURLs: Set<URL> = []
    @State private var responseText = ""
    @State private var errorMessage: String?
    @State private var ollamaURL = "http://127.0.0.1:11434"
    @State private var modelName = "llama3"
    @State private var fileCount = 0
    @State private var showMoreSection = false
    @State private var appState: AppState = .initial
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("formatAsJSON") private var formatAsJSON = false
    private let notifications = NotificationsService.shared
    @State private var hourlyTimer: Timer?
    @FocusState private var promptFocused: Bool
    @State private var showSavedToast: Bool = false
    
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
        // Only seed values when running SwiftUI previews
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            UserDefaults.standard.set(promptText, forKey: "promptText")
            self._promptDraftText = State(initialValue: promptText)
            self._sparkContent = State(initialValue: sparkContent)
            self._responseText = State(initialValue: responseText)
            self._errorMessage = State(initialValue: errorMessage)
            self._ollamaURL = State(initialValue: ollamaURL)
            self._modelName = State(initialValue: modelName)
            self._fileCount = State(initialValue: fileCount)
            self._showMoreSection = State(initialValue: false)
            self._appState = State(initialValue: previewAppState)
        }
    }
    #endif
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Text editor shows prompt or response based on state
                TextEditor(text: textBinding)
                    .frame(minHeight: 200)
                    .padding(16)
                    .background(Color(.textBackgroundColor))
                    .disabled(appState == .processing)
                    .foregroundColor(errorMessage != nil ? .red : .primary)
                    .scrollIndicators(.automatic)
                    .focused($promptFocused)
                    .overlay(alignment: .bottomTrailing) {
                        if showSavedToast {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Saved")
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(.thinMaterial, in: Capsule())
                            .padding(6)
                            .transition(.opacity)
                        }
                    }
            }
            //.padding()
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showMoreSection.toggle()
                        }
                    }) {
                        Image(systemName: "gearshape")
                    }
                }
                //                #if os(macOS)
                                ToolbarItem(placement: .automatic) {
                                    Spacer()
                                }
                //                #endif
                if appState == .processing {
                    ToolbarItem(placement: .automatic) {
                        ProgressView()
                            .tint(.accentColor)
                            .scaleEffect(0.4)
                        //.frame(width: 20, height: 20)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: buttonAction) {
                        if appState == .response {
                            Image(systemName: "arrow.counterclockwise")
                        } else {
                            Text(buttonText)
                        }
                    }
                    .tint(.accentColor)
                    .disabled(appState == .processing || (appState == .initial && sparkContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && instructionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && contextText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                }
            }
#if os(macOS)
.toolbarBackground(.background, for: .windowToolbar)
.toolbarBackgroundVisibility(.visible, for: .windowToolbar)
#endif
        }
        .onAppear {
            sparkLoader.start()
            // Load saved prompt into editable draft
            promptDraftText = savedPromptText
            instructionText = savedInstructionText
            contextText = savedContextText
            if notificationsEnabled {
                Task { await notifications.ensureAuthorizedAndSchedule(with: (errorMessage ?? responseText)) }
                startHourlyGenerator()
            }
        }
        .onReceive(sparkLoader.$combinedContent) { newCombined in
            sparkContent = newCombined
        }
        .onReceive(sparkLoader.$items) { newItems in
            sparkItems = newItems
            // If nothing selected yet, select all by default
            if selectedSparkURLs.isEmpty {
                selectedSparkURLs = Set(newItems.map { $0.id })
            }
            recomputeSparkContentFromSelection()
            #if os(macOS)
            promptModel.compiledPrompt = buildCompiledPrompt()
            #endif
        }
        .onChange(of: selectedSparkURLs) { _, _ in
            recomputeSparkContentFromSelection()
            #if os(macOS)
            promptModel.compiledPrompt = buildCompiledPrompt()
            #endif
        }
        .onChange(of: formatAsJSON) { _, _ in
            recomputeSparkContentFromSelection()
            #if os(macOS)
            promptModel.compiledPrompt = buildCompiledPrompt()
            #endif
        }
        .onReceive(sparkLoader.$fileCount) { newCount in
            fileCount = newCount
        }
        .onChange(of: instructionText) { _, _ in
            #if os(macOS)
            promptModel.compiledPrompt = buildCompiledPrompt()
            #endif
        }
        .onChange(of: contextText) { old, newValue in
            // Expand liquid variables inline when typed in the Context field
            let expanded = expandContextVariables(newValue)
            if expanded != newValue {
                // Avoid recursive onChange: only assign if changed from user input
                contextText = expanded
                return
            }
            #if os(macOS)
            promptModel.compiledPrompt = buildCompiledPrompt()
            #endif
        }
        .onChange(of: promptDraftText) { _, _ in
            #if os(macOS)
            promptModel.compiledPrompt = buildCompiledPrompt()
            #endif
        }
        .onChange(of: notificationsEnabled) { _, newValue in
            if newValue {
                Task { await notifications.ensureAuthorizedAndSchedule(with: (errorMessage ?? responseText)) }
                startHourlyGenerator()
            } else {
                notifications.cancelHourly()
                stopHourlyGenerator()
            }
        }
        .onDisappear {
            sparkLoader.stop()
            stopHourlyGenerator()
        }
        // Intentionally no per-keystroke saving; saving occurs on Generate
        // Options sheet content
        .sheet(isPresented: $showMoreSection) {
            OptionsSheetView(
                sparkContent: $sparkContent,
                ollamaURL: $ollamaURL,
                modelName: $modelName,
                fileCount: fileCount,
                notificationsEnabled: $notificationsEnabled,
                currentResponseText: (errorMessage ?? responseText),
                onDone: { showMoreSection = false },
                    onTestGenerateAndNotify: { Task { await generateAndNotify() } },
                    promptText: promptDraftText,
                    sparkItems: sparkItems,
                    selectedSparkURLs: $selectedSparkURLs,
                    formatAsJSON: $formatAsJSON,
                    instructionText: $instructionText,
                    contextText: $contextText,
                compiledPromptText: buildCompiledPrompt(),
                compiledPromptBinding: Binding(
                    get: { buildCompiledPrompt() },
                    set: { _ in }
                ),
                onShowFullPromptInWindow: { openFullPromptWindow() }
            )
            .frame(minWidth: 400, minHeight: 500)
        }
    }
    
    // Computed properties for state-based UI
    private var textBinding: Binding<String> {
        switch appState {
        case .initial:
            return $promptDraftText
        case .processing:
            return .constant(promptDraftText)
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
            // Resign focus from prompt editor when starting generation
            promptFocused = false
            // Persist prompt only on generate
            savedPromptText = promptDraftText
            print("💾 Prompt saved (", savedPromptText.count, " chars)")
            withAnimation(.easeInOut(duration: 0.15)) { showSavedToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 0.25)) { showSavedToast = false }
            }
            generateContent()
        case .processing:
            break // Button is disabled during processing
        case .response:
            resetToInitial()
        }
    }
    
    private func generateContent() {
        guard !sparkContent.isEmpty || !instructionText.isEmpty || !contextText.isEmpty else { return }
        
        appState = .processing
        responseText = ""
        errorMessage = nil
        
        Task {
            do {
                let combinedPrompt = buildCompiledPrompt()
                let response = try await callOllamaAPI(prompt: combinedPrompt)
                await MainActor.run {
                    responseText = response
                    errorMessage = nil
                    appState = .response
                }
                if notificationsEnabled {
                    notifications.scheduleHourly(with: response)
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

    // Generate specifically for notification flow and send immediate notification
    private func generateAndNotify() async {
        guard !sparkContent.isEmpty || !instructionText.isEmpty || !contextText.isEmpty else { return }
        await MainActor.run {
            appState = .processing
            responseText = ""
            errorMessage = nil
        }
        do {
            let combinedPrompt = buildCompiledPrompt()
            let response = try await callOllamaAPI(prompt: combinedPrompt)
            await MainActor.run {
                responseText = response
                errorMessage = nil
                appState = .response
            }
            // Show as local notification immediately
            await NotificationsService.shared.ensureAuthorizedAndSchedule(with: response)
            NotificationsService.shared.sendNow(with: response)
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                responseText = ""
                appState = .response
            }
        }
    }
    
    // MARK: - Hourly trigger to re-generate and notify
    private func startHourlyGenerator() {
        stopHourlyGenerator()
        hourlyTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task { await generateAndNotify() }
        }
        RunLoop.main.add(hourlyTimer!, forMode: .common)
    }
    
    private func stopHourlyGenerator() {
        hourlyTimer?.invalidate()
        hourlyTimer = nil
    }
    
    private func resetToInitial() {
        appState = .initial
        responseText = ""
        errorMessage = nil
        // promptText is persisted via @AppStorage and remains unchanged
    }

    private func buildCompiledPrompt() -> String {
        var sections: [String] = []
        if !promptDraftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("Instruction:\n" + expandContextVariables(promptDraftText.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        if !instructionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("Additional Instructions:\n" + expandContextVariables(instructionText.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        // Compose context with dynamic info appended
        let region = Locale.current.region?.identifier ?? ""
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        let localTime = formatter.string(from: Date())
        var contextParts: [String] = []
        if !savedContextText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            contextParts.append(expandContextVariables(savedContextText.trimmingCharacters(in: .whitespacesAndNewlines)))
        } else if !contextText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            contextParts.append(expandContextVariables(contextText.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        contextParts.append("Right now it's \(localTime)")
        if !region.isEmpty { contextParts.append("My region is \(region)") }
        let contextCombined = contextParts.joined(separator: "\n")
        if !contextCombined.isEmpty { sections.append("Context:\n" + contextCombined) }
        if !sparkContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("Data:\n" + sparkContent)
        }
        let compiled = sections.joined(separator: "\n\n")
        // As a last step, expand any remaining liquid variables anywhere in the prompt
        return expandContextVariables(compiled)
    }

    private func expandContextVariables(_ text: String) -> String {
        var result = text
        // {{ date }} => e.g. August 3, 2034
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        let dateString = dateFormatter.string(from: Date())
        // {{ time }} => 16:39 (24h)
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let timeString = timeFormatter.string(from: Date())
        // {{ day }} => Thursday
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        let dayString = dayFormatter.string(from: Date())
        let replacements: [(pattern: String, value: String)] = [
            ("\\{\\{\\s*date\\s*\\}}", dateString),
            ("\\{\\{\\s*time\\s*\\}}", timeString),
            ("\\{\\{\\s*day\\s*\\}}", dayString)
        ]
        for (pattern, value) in replacements {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: (result as NSString).length)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: value)
            }
        }
        return result
    }

    // MARK: - Full prompt window (macOS)
    #if os(macOS)
    private func openFullPromptWindow() {
        promptModel.compiledPrompt = buildCompiledPrompt()
        if let controller = fullPromptWindowController, let window = controller.window {
            // Reuse existing window; bring to front and update content
            if let hosting = controller.contentViewController as? NSHostingController<FullPromptView> {
                hosting.rootView = FullPromptView(promptModel: promptModel)
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: FullPromptView(promptModel: promptModel))
        let controller = NSWindowController()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preview"
        window.isReleasedWhenClosed = false
        controller.window = window
        controller.contentViewController = hostingController
        window.center()
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Track controller to keep it alive; clear when closed
        self.fullPromptWindowController = controller
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
            // Clear retained controller on close to avoid stale references
            self.fullPromptWindowController = nil
        }
    }
    #endif

    private func recomputeSparkContentFromSelection() {
        // Build combined content from selected items, keeping newest-first (items already sorted)
        let selected = sparkItems.filter { selectedSparkURLs.contains($0.id) }
        if formatAsJSON {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            let payload: [[String: AnyEncodable]] = selected.map { item in
                #if canImport(SparkKit)
                // Use SparkKit's frontmatter parser when available
                if let parsed = Frontmatter.parse(from: item.content) {
                    let fm = parsed.frontmatter
                    let body = parsed.body.trimmingCharacters(in: .whitespacesAndNewlines)
                    var obj: [String: AnyEncodable] = [:]
                    if !fm.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        obj["title"] = AnyEncodable(fm.title)
                    }
                    let category = fm.category.rawValue
                    if !category.isEmpty {
                        obj["category"] = AnyEncodable(category)
                    }
                    let dateString = ISO8601DateFormatter().string(from: fm.date)
                    if !dateString.isEmpty {
                        obj["createdDate"] = AnyEncodable(dateString)
                    }
                    if let tags = fm.tags, !tags.isEmpty {
                        obj["tags"] = AnyEncodable(tags)
                    }
                    if !body.isEmpty {
                        obj["content"] = AnyEncodable(body)
                    }
                    return obj
                }
                #endif
                // Fallback parser
                let body = SparkLoader.extractBody(from: item.content).trimmingCharacters(in: .whitespacesAndNewlines)
                let tags = SparkLoader.extractTags(from: item.content)
                var obj: [String: AnyEncodable] = [:]
                if !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    obj["title"] = AnyEncodable(item.title)
                }
                if !item.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    obj["category"] = AnyEncodable(item.category)
                }
                let dateString = ISO8601DateFormatter().string(from: item.createdDate)
                if !dateString.isEmpty {
                    obj["createdDate"] = AnyEncodable(dateString)
                }
                if !tags.isEmpty {
                    obj["tags"] = AnyEncodable(tags)
                }
                if !body.isEmpty {
                    obj["content"] = AnyEncodable(body)
                }
                return obj
            }
            if let data = try? encoder.encode(payload), let jsonString = String(data: data, encoding: .utf8) {
                sparkContent = jsonString
            } else {
                sparkContent = "[]"
            }
        } else {
            let combined = selected.map { $0.content }.joined(separator: "\n\n")
            sparkContent = combined
        }
    }
    
    // Manual directory scanning removed; SparkLoader observes changes and sorts by creation date
    
    
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

    // Notifications helpers moved to NotificationsService
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
