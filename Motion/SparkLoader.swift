//
//  SparkLoader.swift
//  Motion
//
//  Created by Assistant on 11.08.2025.
//

import Foundation
import Combine

@MainActor
final class SparkLoader: ObservableObject {
    @Published private(set) var combinedContent: String = ""
    @Published private(set) var fileCount: Int = 0

    private let containerIdentifier: String
    private let query = NSMetadataQuery()
    private var isStarted: Bool = false

    init(containerIdentifier: String) {
        self.containerIdentifier = containerIdentifier
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true

        // Configure query to watch the iCloud Documents directory of the specified container
        let fm = FileManager.default
        guard let containerURL = fm.url(forUbiquityContainerIdentifier: containerIdentifier) else {
            // No container available; clear any previous content
            self.combinedContent = ""
            self.fileCount = 0
            return
        }

        // Prefer the "Documents" directory inside the container
        let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)

        // Predicate to include all items
        query.predicate = NSPredicate(format: "%K LIKE '*'", NSMetadataItemFSNameKey)

        // Limit search to the container's Documents scope if available
        query.searchScopes = [documentsURL]
        query.sortDescriptors = [] // Sorting handled manually when building content

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleInitialGathering(_:)),
                                               name: NSNotification.Name.NSMetadataQueryDidFinishGathering,
                                               object: query)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleUpdates(_:)),
                                               name: NSNotification.Name.NSMetadataQueryDidUpdate,
                                               object: query)

        query.enableUpdates()
        query.start()
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        query.disableUpdates()
        query.stop()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: query)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSMetadataQueryDidUpdate, object: query)
    }

    @objc private func handleInitialGathering(_ notification: Notification) {
        query.disableUpdates()
        rebuildFromQueryResults()
        query.enableUpdates()
    }

    @objc private func handleUpdates(_ notification: Notification) {
        rebuildFromQueryResults()
    }

    private func rebuildFromQueryResults() {
        // Offload IO to a background queue, then marshal results back to main actor
        let items = (0..<query.resultCount).compactMap { index -> NSMetadataItem? in
            return query.result(at: index) as? NSMetadataItem
        }

        Task.detached(priority: .utility) {
            struct FileEntry {
                let url: URL
                let creationDate: Date
            }

            var entries: [FileEntry] = []
            entries.reserveCapacity(items.count)
            for item in items {
                guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { continue }

                // Skip directories
                let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .creationDateKey, .contentModificationDateKey])
                if resourceValues?.isDirectory == true { continue }
                guard resourceValues?.isRegularFile == true else { continue }

                // Prefer creation date; fallback to modification date
                let created = resourceValues?.creationDate ?? resourceValues?.contentModificationDate ?? Date.distantPast
                entries.append(FileEntry(url: url, creationDate: created))
            }

            // Sort newest first by creation date
            entries.sort { $0.creationDate > $1.creationDate }

            var contentBuilder = String()
            var countLoaded = 0
            for entry in entries {
                if let fileText = try? String(contentsOf: entry.url, encoding: .utf8) {
                    contentBuilder.append(fileText)
                    contentBuilder.append("\n\n")
                    countLoaded += 1
                }
            }

            let finalContent = contentBuilder
            let finalCount = countLoaded
            await MainActor.run {
                self.combinedContent = finalContent
                self.fileCount = finalCount
            }
        }
    }

}
