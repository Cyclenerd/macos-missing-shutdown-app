import SwiftUI
import AppKit
import Foundation


/// Service to shut down, restart, or put the computer to sleep. Also log out the user.
///
/// ### Resources
/// - [Blog post](https://www.woodys-findings.com/posts/programmatically-logout-user)
/// - [Apple doc](https://developer.apple.com/library/archive/qa/qa1134/_index.html)
/// - Already in use in [SplashBuddy](https://github.com/macadmins/SplashBuddy/blob/main/SplashBuddy/Tools/LoginWindow.swift)
enum EventService {}

// MARK: - Logic
extension EventService {
    static func send(event eventType: AppleEventType) throws {
        // target the login window process for the event
        var loginWindowSerialNumber = ProcessSerialNumber(
            highLongOfPSN: 0,
            lowLongOfPSN: UInt32(kSystemProcess)
        )
        
        var targetDesc = AEAddressDesc()
        var error = OSErr()
        
        error = AECreateDesc(
            keyProcessSerialNumber,
            &loginWindowSerialNumber,
            MemoryLayout<ProcessSerialNumber>.size,
            &targetDesc
        )
        
        if error != noErr {
            throw EventError(
                errorDescription: "Unable to create the description of the app. Status: \(error)"
            )
        }
        
        // create the Apple event
        var event = AppleEvent()
        error = AECreateAppleEvent(
            kCoreEventClass,
            eventType.eventId,
            &targetDesc,
            AEReturnID(kAutoGenerateReturnID),
            AETransactionID(kAnyTransactionID),
            &event
        )
        
        AEDisposeDesc(&targetDesc)
        
        if error != noErr {
            throw EventError(
                errorDescription: "Unable to create an Apple Event for the app description. Status: \(error)"
            )
        }
        
        // send the event
        var reply = AppleEvent()
        let status = AESendMessage(
            &event,
            &reply,
            AESendMode(kAENoReply),
            1000
        )
        
        if status != noErr {
            throw EventError(
                errorDescription: "Error while sending the event \(eventType). Status: \(status)"
            )
        }
        
        AEDisposeDesc(&event)
        AEDisposeDesc(&reply)
    }
}

// MARK: - Models
extension EventService {
    enum AppleEventType: String {
        case shutdownComputer = "Shut down the computer"
        case restartComputer = "Restart the computer"
        case sleepComputer = "Put the computer to sleep"
        case logoutUser = "Logout the user"
        
        var eventId: OSType {
            switch self {
            case .shutdownComputer: return kAEShutDown
            case .restartComputer: return kAERestart
            case .sleepComputer: return kAESleep
            case .logoutUser: return kAEReallyLogOut
            }
        }
        
        var displayName: String {
            switch self {
            case .shutdownComputer: return "Shut Down"
            case .restartComputer: return "Restart"
            case .sleepComputer: return "Sleep"
            case .logoutUser: return "Log Out"
            }
        }
        
        var iconName: String {
            switch self {
            case .shutdownComputer: return "power"
            case .restartComputer: return "arrow.clockwise"
            case .sleepComputer: return "moon.fill"
            case .logoutUser: return "person.crop.circle.badge.xmark"
            }
        }
        
        var color: Color {
            switch self {
            case .shutdownComputer: return .red
            case .restartComputer: return .orange
            case .sleepComputer: return .blue
            case .logoutUser: return .purple
            }
        }
        
        var shortcut: String {
            switch self {
            case .shutdownComputer: return "s"
            case .restartComputer: return "r"
            case .sleepComputer: return "z"
            case .logoutUser: return "l"
            }
        }
        
        var tabOrder: Int {
            switch self {
            case .sleepComputer: return 0    // Sleep first (default)
            case .restartComputer: return 1
            case .shutdownComputer: return 2
            case .logoutUser: return 3
            }
        }
    }
}

extension EventService.AppleEventType: CaseIterable, Identifiable {
    var id: String { rawValue }
}

extension EventService {
    struct EventError: LocalizedError {
        var errorDescription: String?
    }
}

// MARK: - Main App
@main
struct SystemControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
        
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 400, height: 500)
                .fixedSize(horizontal: true, vertical: true) // Enforce fixed size
        }
        .windowStyle(HiddenTitleBarWindowStyle())
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Application did finish launching")

        // Request necessary permissions if needed
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            print("Accessibility permissions are required for this app to function properly.")
        }
        
        // Set the app to terminate when the last window closes
        NSApp.setActivationPolicy(.regular)
        
        // Set fixed window size
        if let window = NSApplication.shared.windows.first {
            window.setContentSize(NSSize(width: 400, height: 500))
            window.styleMask.remove(.resizable)
            window.center()
        }
    }
    func applicationWillTerminate(_ notification: Notification) {
        print("Application will terminate")
    }
}

// MARK: - Helper for closing window
extension NSApplication {
    static func closeCurrentWindowAndTerminate() {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                window.close()
            }
            NSApplication.shared.terminate(nil)
        }
    }
}
