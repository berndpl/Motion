//
//  FullPromptView.swift
//  Motion
//
//  Created by Assistant on 11.08.2025.
//

import SwiftUI

struct FullPromptView: View {
    @ObservedObject var promptModel: PromptModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $promptModel.compiledPrompt)
                .font(.system(.body, design: .monospaced))
                .scrollIndicators(.automatic)
                .textSelection(.enabled)
                .padding(8)
                .background(Color(.textBackgroundColor))
                .cornerRadius(8)
        }
        .padding()
        .frame(minWidth: 480, minHeight: 400)
    }
}
