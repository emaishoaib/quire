import SwiftUI

enum SettingKey {
    static let showsSelectedTabFullTitle = "showsSelectedTabFullTitle"
}

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Tabs") {
                SelectedTabTitleToggle()
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SelectedTabTitleToggle: View {
    @AppStorage(SettingKey.showsSelectedTabFullTitle) private var showsFullTitle = false

    var body: some View {
        Toggle("Always show the full name of the selected tab", isOn: $showsFullTitle)
    }
}
