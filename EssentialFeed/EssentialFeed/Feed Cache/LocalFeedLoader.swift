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
    public typealias LoadResult = LoadFeedResult?
    
    let maxCachedDays = 7
    let gregorianCalender = Calendar(identifier: .gregorian)
    
    public init(store: FeedStore, timestamp: @escaping () -> Date) {
        self.store = store
        self.timestamp = timestamp
    }
    
    public func save(feed: [FeedImage], completion: @escaping ((SaveResult) -> Void) = {_ in }) {
        store.deleteCacheFeed { [weak self] error in
            if let self = self {
                if let error = error {
                    completion(error)
                } else {
                    self.cache(feed, with: completion)
                }
            }
        }
    }
    
    public func load(completion: @escaping (LoadResult?) -> Void) {
        store.retrieve { [unowned self] result in
            switch result {
            case let .failure(error: error):
                completion(.failure(error))
            case let .found(feed, timestamp):
                if timestamp > gregorianCalender.date(byAdding: .day, value: -self.maxCachedDays, to: self.timestamp())! {
                    completion(.success(feed.toModel()))
                } else {
                    completion(.success([]))
                }
            case .empty:
                completion(.success([]))
            }
        }
    }
    
    private func cache(_ feed: [FeedImage], with completion: @escaping (SaveResult) -> Void) {
        store.insertCache(feed: feed.toLocal(), timestamp: timestamp()) { [weak self] error in
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

private extension Array where Element == LocalFeedImage {
    func toModel() -> [FeedImage] {
        return map { FeedImage(id: $0.id,
                                   description: $0.description,
                                   location: $0.location,
                                   url: $0.url) }
    }
}
