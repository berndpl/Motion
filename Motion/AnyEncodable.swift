//
//  AnyEncodable.swift
//  Motion
//
//  Created by Assistant on 11.08.2025.
//

import Foundation

struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init<T: Encodable>(_ wrapped: T) {
        _encode = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
