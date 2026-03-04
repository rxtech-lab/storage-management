import SwiftTUI

@main
struct RxStorageCli {
    static func main() {
        AppLogger.bootstrap()
        Application(rootView: HomeView()).start()
    }
}
