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
    // Data
    var sparkItems: [SparkItem] = []
    @Binding var selectedSparkURLs: Set<URL>
    @Binding var formatAsJSON: Bool
    // Prompt options
    @Binding var instructionText: String
    @Binding var contextText: String
    let compiledPromptText: String
    var compiledPromptBinding: Binding<String>? = nil
    var onShowFullPromptInWindow: (() -> Void)? = nil

    // Removed in favor of separate window
    @State private var showInstructionSection: Bool = true
    @State private var showContextSection: Bool = true
    @State private var showDataSection: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Text("Options").font(.title2).fontWeight(.semibold)
                    Spacer()
                    #if os(macOS)
                    Button("Open Window") { onShowFullPromptInWindow?() }
                        .buttonStyle(.bordered)
                    #endif
                    Button("Done") { onDone() }
                        .buttonStyle(.borderedProminent)
                }

                // Instruction
                DisclosureGroup(isExpanded: $showInstructionSection) {
                    TextEditor(text: $instructionText)
                        .frame(minHeight: 80, maxHeight: 120)
                        .padding(8)
                        .background(Color(.textBackgroundColor))
                        .cornerRadius(8)
                } label: {
                    Text("Instruction").font(.headline)
                }

                // Context
                DisclosureGroup(isExpanded: $showContextSection) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $contextText)
                            .frame(minHeight: 80, maxHeight: 120)
                            .padding(8)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(8)
                        // Variable help
                        HStack(spacing: 12) {
                            Group {
                                Text("Available: ")
                                    .foregroundColor(.secondary)
                                Text("{{ date }}")
                                    .font(.caption)
                                    .padding(4)
                                    .background(Color(.textBackgroundColor))
                                    .cornerRadius(4)
                                Text("{{ time }}")
                                    .font(.caption)
                                    .padding(4)
                                    .background(Color(.textBackgroundColor))
                                    .cornerRadius(4)
                                Text("{{ day }}")
                                    .font(.caption)
                                    .padding(4)
                                    .background(Color(.textBackgroundColor))
                                    .cornerRadius(4)
                            }
                            Spacer()
                        }
                        HStack(spacing: 12) {
                            let region = Locale.current.region?.identifier ?? ""
                            Text("Right now it's \(Self.localTimeString())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if !region.isEmpty {
                                Text("Region: \(region)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                } label: {
                    Text("Context").font(.headline)
                }

                // Data (Sparks)
                DisclosureGroup(isExpanded: $showDataSection) {
                    VStack(alignment: .leading, spacing: 8) {
                        if !sparkItems.isEmpty {
                            HStack(spacing: 8) {
                                Button("Select All") { selectedSparkURLs = Set(sparkItems.map { $0.id }) }
                                Button("Select None") { selectedSparkURLs.removeAll() }
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
                            .frame(minHeight: 120, maxHeight: 240)
                        } else {
                            Text("No sparks found.").foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Included Spark Content")
                            Spacer()
                            Toggle("Format as JSON", isOn: $formatAsJSON).toggleStyle(.switch)
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                        HStack {
                            Text("≈ \(estimateTokenCount(for: sparkContent)) tokens").font(.caption).foregroundColor(.secondary)
                            Spacer()
                        }

                        TextEditor(text: $sparkContent)
                            .frame(minHeight: 100, maxHeight: 180)
                            .padding(8)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(8)
                            .scrollIndicators(.automatic)

                        // Controls moved to top header
                    }
                } label: {
                    Text("Data (Sparks)").font(.headline)
                }

                // File count
                HStack {
                    Image(systemName: "doc.on.doc").foregroundColor(.blue)
                    Text("\(fileCount) files loaded").font(.subheadline).foregroundColor(.secondary)
                    Spacer()
                }

                // Preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview").font(.headline)
                    if let binding = compiledPromptBinding {
                        TextEditor(text: binding)
                            .frame(minHeight: 120, maxHeight: 200)
                            .padding(8)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(8)
                            .scrollIndicators(.automatic)
                    } else {
                        TextEditor(text: .constant(compiledPromptText))
                            .frame(minHeight: 120, maxHeight: 200)
                            .padding(8)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(8)
                            .scrollIndicators(.automatic)
                    }
                }

                // More Options
                VStack(alignment: .leading, spacing: 8) {
                    Text("More Options").font(.headline)
                    TextField("Ollama URL", text: $ollamaURL).textFieldStyle(.roundedBorder).disableAutocorrection(true)
                    TextField("Model Name", text: $modelName).textFieldStyle(.roundedBorder).disableAutocorrection(true)
                    Toggle("Hourly notification with latest response", isOn: $notificationsEnabled)
                    HStack { Button("Send Test Notification") { onTestGenerateAndNotify() }; Spacer() }
                }
            }
            .padding()
        }
        // Full prompt is shown in a separate window on macOS
    }

    private func estimateTokenCount(for text: String) -> Int {
        let characterCount = text.unicodeScalars.count
        return max(1, Int(ceil(Double(characterCount) / 4.0)))
    }

    private static func localTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        return formatter.string(from: Date())
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
        formatAsJSON: .constant(false),
        instructionText: .constant(""),
        contextText: .constant(""),
        compiledPromptText: "Instruction: ...\n\nContext: ...\n\nData: ..."
    )
    .frame(width: 420, height: 500)
}
