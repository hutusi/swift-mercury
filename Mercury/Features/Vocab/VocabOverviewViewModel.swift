import Foundation
import Observation

@Observable
final class VocabOverviewViewModel {
    enum State {
        case loading
        case loaded(VocabOverview)
        case failed(String)
    }

    private(set) var state: State = .loading
    private let api: any MercuryAPI

    init(api: any MercuryAPI) {
        self.api = api
    }

    /// Words grouped by topic in first-seen order (server returns them sorted).
    var topicGroups: [(topic: String, words: [OverviewWord])] {
        guard case .loaded(let overview) = state else { return [] }
        var order: [String] = []
        var groups: [String: [OverviewWord]] = [:]
        for word in overview.words {
            if groups[word.word.topic] == nil {
                order.append(word.word.topic)
            }
            groups[word.word.topic, default: []].append(word)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }

    func load() async {
        do {
            state = .loaded(try await api.vocabOverview())
        } catch {
            if case .loaded = state { return }
            state = .failed(error.localizedDescription)
        }
    }

    func reload() async {
        state = .loading
        await load()
    }
}
