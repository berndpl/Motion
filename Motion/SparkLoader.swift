//
//  SparkLoader.swift
//  Motion
//
//  Created by Assistant on 11.08.2025.
//

import Foundation
import Combine
#if canImport(SparkKit)
import SparkKit
#endif

@MainActor
final class SparkLoader: ObservableObject {
    @Published private(set) var combinedContent: String = ""
    @Published private(set) var fileCount: Int = 0
    @Published private(set) var items: [SparkItem] = []

    private let containerIdentifier: String
    private var isStarted: Bool = false
#if canImport(SparkKit)
    private var sparkDataManager: SparkDataManager?
    private var sparkCreatedObserver: NSObjectProtocol?
#else
    private let query = NSMetadataQuery()
#endif

    init(containerIdentifier: String) {
        self.containerIdentifier = containerIdentifier
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        
        #if canImport(SparkKit)
        // Initialize SparkKit data manager which handles iCloud and file monitoring
        do {
            let manager = try SparkDataManager()
            self.sparkDataManager = manager
            manager.startMonitoring()
        } catch {
            print("❌ SparkLoader failed to start SparkDataManager: \(error)")
        }
        
        // Observe SparkKit change notifications
        sparkCreatedObserver = NotificationCenter.default.addObserver(
            forName: .sparkCreated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildFromSparkKit()
        }
        
        // Initial build
        rebuildFromSparkKit()
        #else
        // Fallback: observe iCloud container directly with NSMetadataQuery
        let fm = FileManager.default
        if let containerURL = fm.url(forUbiquityContainerIdentifier: containerIdentifier) {
            let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
            query.predicate = NSPredicate(format: "%K LIKE '*.md'", NSMetadataItemFSNameKey)
            query.searchScopes = [documentsURL]
        } else {
            // As a fallback, search ubiquitous documents scope
            query.predicate = NSPredicate(format: "%K LIKE '*.md'", NSMetadataItemFSNameKey)
            query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        }
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleInitialGathering(_:)),
                                               name: NSNotification.Name.NSMetadataQueryDidFinishGathering,
                                               object: query)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleUpdates(_:)),
                                               name: NSNotification.Name.NSMetadataQueryDidUpdate,
                                               object: query)
        
        query.enableUpdates()
        _ = query.start()
        #endif
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        
        #if canImport(SparkKit)
        if let observer = sparkCreatedObserver {
            NotificationCenter.default.removeObserver(observer)
            sparkCreatedObserver = nil
        }
        sparkDataManager?.stopMonitoring()
        sparkDataManager = nil
        #else
        query.disableUpdates()
        query.stop()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: query)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSMetadataQueryDidUpdate, object: query)
        #endif
    }

#if canImport(SparkKit)
    private func rebuildFromSparkKit() {
        Task.detached(priority: .utility) {
            do {
                // Use SparkStorage for a consistent file listing (sorted newest-first by filename timestamp)
                let urls = try SparkStorage.listSparks()
                var contentBuilder = String(); contentBuilder.reserveCapacity(4096)
                var builtItems: [SparkItem] = []
                builtItems.reserveCapacity(urls.count)
                for url in urls {
                    guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                    let meta = SparkLoader.extractFrontmatter(from: text)
                    let tokenEstimate = SparkLoader.estimateTokens(for: text)
                    let item = SparkItem(
                        id: url,
                        title: meta.title,
                        category: meta.category,
                        createdDate: meta.date,
                        tokenEstimate: tokenEstimate,
                        content: text
                    )
                    builtItems.append(item)
                    contentBuilder.append(text)
                    contentBuilder.append("\n\n")
                }
                let finalContent = contentBuilder
                await MainActor.run {
                    self.combinedContent = finalContent
                    self.fileCount = builtItems.count
                    self.items = builtItems
                }
            } catch {
                await MainActor.run {
                    self.combinedContent = ""
                    self.fileCount = 0
                    self.items = []
                }
            }
        }
    }
#else
    @objc private func handleInitialGathering(_ notification: Notification) {
        query.disableUpdates()
        rebuildFromQueryResults()
        query.enableUpdates()
    }

    @objc private func handleUpdates(_ notification: Notification) {
        rebuildFromQueryResults()
    }

    private func rebuildFromQueryResults() {
        let items = (0..<query.resultCount).compactMap { index -> NSMetadataItem? in
            return query.result(at: index) as? NSMetadataItem
        }
        
        Task.detached(priority: .utility) {
            struct FileEntry { let url: URL; let creationDate: Date }
            var entries: [FileEntry] = []
            entries.reserveCapacity(items.count)
            for item in items {
                guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { continue }
                let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .creationDateKey, .contentModificationDateKey])
                if resourceValues?.isDirectory == true { continue }
                guard resourceValues?.isRegularFile == true else { continue }
                let created = resourceValues?.creationDate ?? resourceValues?.contentModificationDate ?? Date.distantPast
                entries.append(FileEntry(url: url, creationDate: created))
            }
            entries.sort { $0.creationDate > $1.creationDate }
            var contentBuilder = String(); var builtItems: [SparkItem] = []
            for entry in entries {
                guard let fileText = try? String(contentsOf: entry.url, encoding: .utf8) else { continue }
                let meta = SparkLoader.extractFrontmatter(from: fileText)
                let tokenEstimate = SparkLoader.estimateTokens(for: fileText)
                builtItems.append(
                    SparkItem(
                        id: entry.url,
                        title: meta.title,
                        category: meta.category,
                        createdDate: meta.date,
                        tokenEstimate: tokenEstimate,
                        content: fileText
                    )
                )
                contentBuilder.append(fileText)
                contentBuilder.append("\n\n")
            }
            let finalContent = contentBuilder
            let finalItems = builtItems
            await MainActor.run {
                self.combinedContent = finalContent
                self.fileCount = finalItems.count
                self.items = finalItems
            }
        }
    }
#endif
}

// MARK: - Helpers
extension SparkLoader {
    nonisolated static func estimateTokens(for text: String) -> Int {
        let count = text.unicodeScalars.count
        return max(1, Int(ceil(Double(count) / 4.0)))
    }
    
    nonisolated static func extractFrontmatter(from content: String) -> (title: String, category: String, date: Date) {
        let lines = content.components(separatedBy: .newlines)
        var inFrontmatter = false
        var title = ""
        var category = "unknown"
        var date = Date()
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" { inFrontmatter.toggle(); continue }
            if inFrontmatter {
                if trimmed.hasPrefix("title: ") {
                    title = String(trimmed.dropFirst(7))
                } else if trimmed.hasPrefix("category: ") {
                    category = String(trimmed.dropFirst(10))
                } else if trimmed.hasPrefix("date: ") {
                    let ds = String(trimmed.dropFirst(6))
                    date = df.date(from: ds) ?? date
                }
            }
        }
        return (title, category, date)
    }

    nonisolated static func extractBody(from content: String) -> String {
        var lines = content.components(separatedBy: .newlines)
        // Remove YAML frontmatter if present
        if let first = lines.first, first.trimmingCharacters(in: .whitespaces) == "---" {
            // find matching end marker
            var endIndex: Int? = nil
            for (idx, line) in lines.enumerated().dropFirst() {
                if line.trimmingCharacters(in: .whitespaces) == "---" { endIndex = idx; break }
            }
            if let end = endIndex, end + 1 < lines.count {
                lines = Array(lines.suffix(from: end + 1))
            }
        }
        // Trim leading blank lines
        while lines.first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { _ = lines.removeFirst() }
        return lines.joined(separator: "\n")
    }

    nonisolated static func extractTags(from content: String) -> [String] {
        let lines = content.components(separatedBy: .newlines)
        var inFrontmatter = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" {
                if inFrontmatter { break }
                inFrontmatter = true
                continue
            }
            if inFrontmatter && trimmed.hasPrefix("tags: ") {
                let tagsString = String(trimmed.dropFirst(6))
                return tagsString
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        }
        return []
    }
}
