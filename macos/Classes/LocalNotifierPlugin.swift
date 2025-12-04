import Cocoa
import FlutterMacOS
import UserNotifications

public class LocalNotifierPlugin: NSObject, FlutterPlugin, UNUserNotificationCenterDelegate {
    var registrar: FlutterPluginRegistrar!
    var channel: FlutterMethodChannel!
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private var notificationIdentifiers: Set<String> = []
    private var actionIdentifierMap: [String: [String: Int]] = [:]
    
    public override init() {
        super.init()
        notificationCenter.delegate = self
        requestNotificationAuthorization()
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "local_notifier", binaryMessenger: registrar.messenger)
        let instance = LocalNotifierPlugin()
        instance.registrar = registrar
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch (call.method) {
        case "notify":
            notify(call, result: result)
            break
        case "close":
            close(call, result: result)
            break
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    public func notify(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! Dictionary<String, Any>
        let identifier: String = args["identifier"] as! String
        let title: String? = args["title"] as? String
        let subtitle: String? = args["subtitle"] as? String
        let body: String? = args["body"] as? String
        let silent: Bool = args["silent"] as? Bool ?? false
        let actions: [NSDictionary]? = args["actions"] as? [NSDictionary]
        
        let content = UNMutableNotificationContent()
        content.title = title ?? ""
        if let subtitle = subtitle {
            content.subtitle = subtitle
        }
        if let body = body {
            content.body = body
        }
        content.sound = silent ? nil : UNNotificationSound.default
        
        if let actionItems = actions, !actionItems.isEmpty {
            configureActions(for: identifier, content: content, actionItems: actionItems)
        }
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        notificationIdentifiers.insert(identifier)
        notificationCenter.add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.notificationIdentifiers.remove(identifier)
                    result(FlutterError(code: "notification_error", message: error.localizedDescription, details: nil))
                    return
                }
                
                result(true)
                self.invokeMethod("onLocalNotificationShow", notificationId: identifier)
            }
        }
    }
    
    public func close(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! Dictionary<String, Any>
        let identifier: String = args["identifier"] as! String
        
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        
        if notificationIdentifiers.contains(identifier) {
            notificationIdentifiers.remove(identifier)
            actionIdentifierMap.removeValue(forKey: identifier)
            invokeMethod("onLocalNotificationClose", notificationId: identifier)
        }
        result(true)
    }
    
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .list, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }
    
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            invokeMethod("onLocalNotificationClick", notificationId: identifier)
        } else if let actionIndex = actionIdentifierMap[identifier]?[response.actionIdentifier] {
            invokeMethod(
                "onLocalNotificationClickAction",
                notificationId: identifier,
                extraArgs: ["actionIndex": actionIndex]
            )
        }
        
        actionIdentifierMap.removeValue(forKey: identifier)
        
        completionHandler()
    }
    
    private func configureActions(for identifier: String, content: UNMutableNotificationContent, actionItems: [NSDictionary]) {
        var notificationActions: [UNNotificationAction] = []
        var identifierMap: [String: Int] = [:]
        let categoryIdentifier = "local_notifier.category.\(identifier)"
        
        for (index, item) in actionItems.enumerated() {
            guard let actionDict = item as? [String: Any] else {
                continue
            }
            let actionText: String = actionDict["text"] as? String ?? "Action \(index + 1)"
            let actionIdentifier = "\(categoryIdentifier).action.\(index)"
            identifierMap[actionIdentifier] = index
            
            let action = UNNotificationAction(
                identifier: actionIdentifier,
                title: actionText,
                options: [.foreground]
            )
            notificationActions.append(action)
        }
        
        guard !notificationActions.isEmpty else {
            return
        }
        
        actionIdentifierMap[identifier] = identifierMap
        content.categoryIdentifier = categoryIdentifier
        
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: notificationActions,
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.getNotificationCategories { categories in
            var updatedCategories = categories
            updatedCategories.insert(category)
            self.notificationCenter.setNotificationCategories(updatedCategories)
        }
    }
    
    private func requestNotificationAuthorization() {
        notificationCenter.getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                self.notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
            }
        }
    }
    
    private func invokeMethod(_ methodName: String, notificationId: String, extraArgs: [String: Any]? = nil) {
        var args: [String: Any] = ["notificationId": notificationId]
        if let extra = extraArgs {
            for (key, value) in extra {
                args[key] = value
            }
        }
        DispatchQueue.main.async {
            self.channel.invokeMethod(methodName, arguments: args, result: nil)
        }
    }
}
