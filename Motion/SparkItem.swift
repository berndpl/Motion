//
//  SparkItem.swift
//  Motion
//
//  Created by Assistant on 11.08.2025.
//

import Foundation

struct SparkItem: Identifiable, Hashable {
    let id: URL
    let title: String
    let category: String
    let createdDate: Date
    let tokenEstimate: Int
    let content: String
}
