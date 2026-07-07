import SwiftUI

struct MainTabView: View {
    let session: SessionModel
    let api: any MercuryAPI

    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "square.grid.2x2") {
                DashboardView(api: api)
            }
            Tab("Vocabulary", systemImage: "character.book.closed") {
                VocabOverviewView(api: api)
            }
            Tab("Profile", systemImage: "person.crop.circle") {
                ProfileView(session: session)
            }
        }
    }
}
