//
//  CacheFeedUseCaseTests.swift
//  EssentialFeedTests
//
//  Created by Musa Almatri on 26/10/2022.
//  Copyright © 2022 Essential Developer. All rights reserved.
//

import XCTest
@testable import EssentialFeed

class LocalFeedLoader {
    let store: FeedStore
    let timestamp: () -> Date
    
    init(store: FeedStore, timestamp: @escaping () -> Date) {
        self.store = store
        self.timestamp = timestamp
    }
    
    func save(items: [FeedItem]) {
        store.deleteCacheFeed { [weak self] error in
            if let self = self {
                if error == nil {
                    self.store.insertCache(items: items, timestamp: self.timestamp())
                }
            }
        }
    }
}

class FeedStore {
    typealias DeletionCompletion = ((Error?) -> Void)
    
    var deleteCacheFeedCallCount = 0
    
    var deletionCompletions: [DeletionCompletion] = []
    var insertions: [(items: [FeedItem], timestamp: Date)] = []
    
    func deleteCacheFeed(completion: @escaping DeletionCompletion) {
        deleteCacheFeedCallCount += 1
        deletionCompletions.append(completion)
    }
    
    func completeDeletion(with error: Error, at index: Int = 0) {
        deletionCompletions[index](error)
    }
    
    func completeDeletionSuccessfully(at index: Int = 0) {
        deletionCompletions[index](nil)
    }
    
    func insertCache(items: [FeedItem], timestamp: Date) {
        insertions.append((items: items, timestamp: timestamp))
    }
}

class CacheFeedUseCaseTests: XCTestCase {
    
    func test_init_doesNotDeleteCacheUponCreation() {
        let (_, store) = makeSUT()
        
        XCTAssertEqual(store.deleteCacheFeedCallCount, 0)
    }
    
    func test_save_requestDeleteCache() {
        let (sut, store) = makeSUT()
        
        sut.save(items: [uniqueItem(),uniqueItem(),uniqueItem()])
        
        XCTAssertEqual(store.deleteCacheFeedCallCount, 1)
    }
    
    func test_save_doesNotInsertCacheOnDeletionError() {
        let (sut, store) = makeSUT()
        
        sut.save(items: [uniqueItem(),uniqueItem(),uniqueItem()])
        store.completeDeletion(with: anyNSError())
        
        XCTAssertEqual(store.insertions.count, 0)
    }

    func test_save_requestInsertionWithTimestampOnSuccessCacheDeletion() {
        let currentDate = Date()
        let (sut, store) = makeSUT(timestamp: { currentDate })
        let items = [uniqueItem(),uniqueItem(),uniqueItem()]
        sut.save(items: items)
        store.completeDeletionSuccessfully()
        
        XCTAssertEqual(store.insertions.count, 1)
        XCTAssertEqual(store.insertions.first?.items, items)
        XCTAssertEqual(store.insertions.first?.timestamp, currentDate)
    }
    
    func makeSUT(timestamp: @escaping () -> Date = Date.init, file: StaticString = #file, line: UInt = #line) -> (sut: LocalFeedLoader, store: FeedStore) {
        let store = FeedStore()
        let sut = LocalFeedLoader(store: store, timestamp: timestamp)
        trackForMemoryLeaks(store, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, store)
    }
    
    func uniqueItem() -> FeedItem {
        FeedItem(id: UUID(), description: "any", location: "any", image: anyURL())
    }
}
