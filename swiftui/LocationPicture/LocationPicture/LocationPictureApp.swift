// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI

@main
struct LocationPictureApp: App {
    @State private var store = PictureStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                #if os(macOS)
                .frame(minWidth: 720, minHeight: 560)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 980, height: 760)
        #endif
    }
}
