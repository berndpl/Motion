//
//  OptionsSheetView.swift
//  Motion
//
//  Created by Assistant on 09.08.2025.
//

import SwiftUI

struct OptionsSheetView: View {
    @Binding var sparkContent: String
    @Binding var ollamaURL: String
    @Binding var modelName: String
    let fileCount: Int
    @Binding var notificationsEnabled: Bool
    let currentResponseText: String
    let onDone: () -> Void
    let onTestGenerateAndNotify: () -> Void
    let promptText: String

    @State private var showFullPrompt: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text("Options")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Done") { onDone() }
                    .buttonStyle(.borderedProminent)
            }

            // Content field
            VStack(alignment: .leading, spacing: 8) {
                Text("Sparks")
                    .font(.headline)

                TextEditor(text: $sparkContent)
                    .frame(minHeight: 150)
                    .padding(8)
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
                    .scrollIndicators(.automatic)

                HStack {
                    Button("Show Full Prompt") { showFullPrompt = true }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                }
            }
            // File count display
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.blue)
                    Text("\(fileCount) files loaded")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
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

            // Notifications
            VStack(alignment: .leading, spacing: 8) {
                Text("Notifications")
                    .font(.headline)
                Toggle("Hourly notification with latest response", isOn: $notificationsEnabled)
                HStack(spacing: 12) {
                    Button("Send Test Notification") {
                        onTestGenerateAndNotify()
                    }
                }
            }
        }
        .padding()
        .sheet(isPresented: $showFullPrompt) {
            let fullPrompt = promptText + sparkContent
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Full Prompt")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Spacer()
                    Button("Done") { showFullPrompt = false }
                        .buttonStyle(.borderedProminent)
                }
                Text("Estimated tokens: \(estimateTokenCount(for: fullPrompt))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                ScrollView {
                    Text(fullPrompt)
                        .textSelection(.enabled)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color(.textBackgroundColor))
                        .cornerRadius(6)
                }
                Spacer(minLength: 0)
            }
            .padding()
            .frame(minWidth: 500, minHeight: 400)
        }
    }

    private func estimateTokenCount(for text: String) -> Int {
        let characterCount = text.unicodeScalars.count
        return max(1, Int(ceil(Double(characterCount) / 4.0)))
    }
}

#Preview {
    OptionsSheetView(
        sparkContent: .constant("Sample spark 1\nSample spark 2"),
        ollamaURL: .constant("http://127.0.0.1:11434"),
        modelName: .constant("llama3"),
        fileCount: 2,
        notificationsEnabled: .constant(true),
        currentResponseText: "Here is a preview response.",
        onDone: {},
        onTestGenerateAndNotify: {},
        promptText: "Create a short summary of the following content "
    )
    .frame(width: 420, height: 500)
}
