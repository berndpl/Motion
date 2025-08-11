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
    // New: spark items and selection binding
    var sparkItems: [SparkItem] = []
    @Binding var selectedSparkURLs: Set<URL>
    @Binding var formatAsJSON: Bool

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

            // Spark list and content preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Sparks")
                    .font(.headline)

                if !sparkItems.isEmpty {
                    HStack(spacing: 8) {
                        Button("Select All") {
                            selectedSparkURLs = Set(sparkItems.map { $0.id })
                        }
                        Button("Select None") {
                            selectedSparkURLs.removeAll()
                        }
                        Spacer()
                        Text("Selected: \(selectedSparkURLs.count)/\(sparkItems.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    List(sparkItems) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Toggle("", isOn: Binding(
                                get: { selectedSparkURLs.contains(item.id) },
                                set: { isOn in
                                    if isOn { selectedSparkURLs.insert(item.id) } else { selectedSparkURLs.remove(item.id) }
                                }
                            ))
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title.isEmpty ? item.id.lastPathComponent : item.title)
                                    .font(.headline)
                                HStack(spacing: 8) {
                                    Text(item.category)
                                    Text(item.createdDate, style: .date)
                                    Text("~\(item.tokenEstimate) tok")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(minHeight: 160, maxHeight: 240)
                } else {
                    Text("No sparks found.")
                        .foregroundColor(.secondary)
                }

                HStack {
                HStack {
                    Text("Included Spark Content")
                    Spacer()
                    Toggle("Format as JSON", isOn: $formatAsJSON)
                        .toggleStyle(.switch)
                }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("≈ \(estimateTokenCount(for: sparkContent)) tokens")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                TextEditor(text: $sparkContent)
                    .frame(minHeight: 120)
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
        promptText: "Create a short summary of the following content ",
        sparkItems: [
            SparkItem(id: URL(fileURLWithPath: "/tmp/a.md"), title: "A title", category: "text", createdDate: Date(), tokenEstimate: 120, content: "---\ntitle: A title\n---\nBody"),
            SparkItem(id: URL(fileURLWithPath: "/tmp/b.md"), title: "B title", category: "website", createdDate: Date(), tokenEstimate: 95, content: "---\ntitle: B title\n---\nBody")
        ],
        selectedSparkURLs: .constant([]),
        formatAsJSON: .constant(false)
    )
    .frame(width: 420, height: 500)
}
