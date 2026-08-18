//
//  RemoteImage.swift
//  Truedata
//

import SwiftUI

private nonisolated final class DecodedImageCache: @unchecked Sendable {

    private let storage = NSCache<NSURL, UIImage>()

    init(countLimit: Int) {
        storage.countLimit = countLimit
    }

    func image(for url: URL) -> UIImage? {
        storage.object(forKey: url as NSURL)
    }

    func insert(_ image: UIImage, for url: URL) {
        storage.setObject(image, forKey: url as NSURL)
    }
}

actor ImageLoader {

    static let shared = ImageLoader()

    private nonisolated let cache = DecodedImageCache(countLimit: 200)
    private var inFlight: [URL: Task<UIImage, Error>] = [:]

    private init() {}

    nonisolated func cached(_ url: URL) -> UIImage? {
        cache.image(for: url)
    }

    func image(for url: URL) async throws -> UIImage {
        if let hit = cache.image(for: url) {
            return hit
        }

        if let existing = inFlight[url] {
            return try await existing.value
        }

        let task = Task<UIImage, Error> {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard
                let http = response as? HTTPURLResponse,
                (200..<300).contains(http.statusCode),
                let image = UIImage(data: data)
            else {
                throw URLError(.cannotDecodeContentData)
            }
            return image
        }
        inFlight[url] = task

        let result = await task.result
        inFlight[url] = nil

        if case .success(let image) = result {
            cache.insert(image, for: url)
        }
        return try result.get()
    }
}

struct RemoteImage: View {

    let url: String?
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?

    private var resolvedURL: URL? {
        guard let url, !url.isEmptyString else { return nil }
        return URL(string: url.trim)
    }

    var body: some View {
        content
            .task(id: resolvedURL) {
                await load()
            }
    }

    @ViewBuilder
    private var content: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            imagePlaceholder
        }
    }

    private var imagePlaceholder: some View {
        ZStack {
            AppTheme.imageTile
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)
        }
    }

    private func load() async {
        guard let resolvedURL else {
            image = nil
            return
        }

        if let hit = ImageLoader.shared.cached(resolvedURL) {
            image = hit
            return
        }

        do {
            image = try await ImageLoader.shared.image(for: resolvedURL)
        } catch {
            if !Task.isCancelled {
                image = nil
            }
        }
    }
}
