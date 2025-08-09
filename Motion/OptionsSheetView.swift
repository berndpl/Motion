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
        onTestGenerateAndNotify: {}
    )
    .frame(width: 420, height: 500)
}
