//
//  LocalFeedLoader.swift
//  EssentialFeed
//
//  Created by Musa Almatri on 30/10/2022.
//  Copyright © 2022 Essential Developer. All rights reserved.
//

import Foundation

public final class LocalFeedLoader {
    let store: FeedStore
    let timestamp: () -> Date
    
    public typealias SaveResult = Error?
    
    public init(store: FeedStore, timestamp: @escaping () -> Date) {
        self.store = store
        self.timestamp = timestamp
    }
    
    public func save(items: [FeedImage], completion: @escaping ((SaveResult) -> Void) = {_ in }) {
        store.deleteCacheFeed { [weak self] error in
            if let self = self {
                if let error = error {
                    completion(error)
                } else {
                    self.cache(items, with: completion)
                }
            }
        }
    }
    
    private func cache(_ items: [FeedImage], with completion: @escaping (SaveResult) -> Void) {
        store.insertCache(items: items.toLocal(), timestamp: timestamp()) { [weak self] error in
            guard self != nil else { return }
            completion(error)
        }
    }
}

private extension Array where Element == FeedImage {
    func toLocal() -> [LocalFeedImage] {
        return map { LocalFeedImage(id: $0.id,
                                   description: $0.description,
                                   location: $0.location,
                                   url: $0.url) }
    }
}
