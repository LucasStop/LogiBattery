import Foundation
import UserNotifications

/// Entrega os avisos pela Central de Notificações; pede permissão no primeiro aviso.
struct UserNotificationNotifier: AlertNotifying {
    func notify(_ alert: BatteryAlert) {
        let content = UNMutableNotificationContent()
        content.title = "\(alert.deviceName): \(alert.percent)%"
        content.body = switch alert.severity {
        case .low: String(localized: "alert.low.body")
        case .critical: String(localized: "alert.critical.body")
        case .full: String(localized: "alert.full.body")
        }
        content.sound = .default
        let center = UNUserNotificationCenter.current()
        Task {
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            try? await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
}
