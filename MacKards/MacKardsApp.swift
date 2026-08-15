import SwiftUI

@main
struct MacKardsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene { SwiftUI.Settings { SettingsView() } }
}
