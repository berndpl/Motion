//
//  NotificationsService.swift
//  Motion
//
//  Created by Assistant on 09.08.2025.
//

import Foundation
import UserNotifications

final class NotificationsService {
    static let shared = NotificationsService()
    
    private let center = UNUserNotificationCenter.current()
    private let hourlyNotificationIdentifier = "motion.hourly.response.notification"
    
    private init() {}
    
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }
    
    func ensureAuthorizedAndSchedule(with text: String) async {
        let granted = await requestAuthorization()
        guard granted else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        scheduleHourly(with: trimmed)
    }
    
    func scheduleHourly(with text: String) {
        center.removePendingNotificationRequests(withIdentifiers: [hourlyNotificationIdentifier])
        
        let content = UNMutableNotificationContent()
        content.title = "Motion"
        content.body = text
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: true)
        let request = UNNotificationRequest(
            identifier: hourlyNotificationIdentifier,
            content: content,
            trigger: trigger
        )
        center.add(request, withCompletionHandler: nil)
    }
    
    func cancelHourly() {
        center.removePendingNotificationRequests(withIdentifiers: [hourlyNotificationIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [hourlyNotificationIdentifier])
    }
    
    func sendTest(with text: String) {
        let content = UNMutableNotificationContent()
        content.title = "Motion (Test)"
        content.body = text
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "motion.test.notification", content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    func sendNow(with text: String, title: String = "Motion") {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = text
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }
}
