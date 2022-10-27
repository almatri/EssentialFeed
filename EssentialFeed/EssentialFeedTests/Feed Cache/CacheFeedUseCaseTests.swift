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
    
    func save(items: [FeedItem], completion: @escaping ((Error?) -> Void) = {_ in }) {
        store.deleteCacheFeed { [weak self] error in
            if let self = self {
                if error == nil {
                    self.store.insertCache(items: items, timestamp: self.timestamp(), completion: completion)
                } else {
                    completion(error)
                }
            }
        }
    }
}

protocol FeedStore {
    typealias DeletionCompletion = ((Error?) -> Void)
    typealias InsertionCompletion = ((Error?) -> Void)
    
    func deleteCacheFeed(completion: @escaping DeletionCompletion)
    func insertCache(items: [FeedItem], timestamp: Date, completion: @escaping InsertionCompletion)
}

class FeedStoreSpy: FeedStore {
    enum ReceivedMessage: Equatable {
        case deleteCacheFeed
        case insertCache([FeedItem], Date)
    }
   
    var deletionCompletions: [DeletionCompletion] = []
    var insertionCompletions: [InsertionCompletion] = []

    var receivedMessages: [ReceivedMessage] = []
    
    func deleteCacheFeed(completion: @escaping DeletionCompletion) {
        receivedMessages.append(.deleteCacheFeed)
        deletionCompletions.append(completion)
    }
    
    func completeDeletion(with error: Error, at index: Int = 0) {
        deletionCompletions[index](error)
    }
    
    func completeDeletionSuccessfully(at index: Int = 0) {
        deletionCompletions[index](nil)
    }
    
    func insertCache(items: [FeedItem], timestamp: Date, completion: @escaping InsertionCompletion) {
        receivedMessages.append(.insertCache(items, timestamp))
        insertionCompletions.append(completion)
    }
    
    func completeInsertionSuccessfully(at index: Int = 0) {
        insertionCompletions[index](nil)
    }
    
    func completeInsertion(with error: Error, at index: Int = 0) {
        insertionCompletions[index](error)
    }
}

class CacheFeedUseCaseTests: XCTestCase {
    
    func test_init_doesNotMessageStoreUponCreation() {
        let (_, store) = makeSUT()
        
        XCTAssertTrue(store.receivedMessages.isEmpty)
    }
    
    func test_save_requestDeleteCache() {
        let (sut, store) = makeSUT()
        
        sut.save(items: [uniqueItem(),uniqueItem(),uniqueItem()])
        
        XCTAssertEqual(store.receivedMessages, [.deleteCacheFeed])
    }
    
    func test_save_doesNotInsertCacheOnDeletionError() {
        let (sut, store) = makeSUT()
        
        sut.save(items: [uniqueItem(),uniqueItem(),uniqueItem()])
        store.completeDeletion(with: anyNSError())
        
        XCTAssertEqual(store.receivedMessages, [.deleteCacheFeed])
    }

    func test_save_requestInsertionWithTimestampOnSuccessCacheDeletion() {
        let currentDate = Date()
        let (sut, store) = makeSUT(timestamp: { currentDate })
        let items = [uniqueItem(),uniqueItem(),uniqueItem()]
        sut.save(items: items)
        store.completeDeletionSuccessfully()
        
        XCTAssertEqual(store.receivedMessages, [.deleteCacheFeed, .insertCache(items, currentDate)])
    }
    
    func test_save_failsOnDeletionError() {
        let currentDate = Date()
        let (sut, store) = makeSUT(timestamp: { currentDate })
        let items = [uniqueItem(),uniqueItem(),uniqueItem()]
        
        expect(sut: sut, toCompleteWithError: anyNSError()) {
            store.completeDeletion(with: anyNSError())
        }
    }
    
    func test_save_failsOnInsertionError() {
        let currentDate = Date()
        let (sut, store) = makeSUT(timestamp: { currentDate })
        let items = [uniqueItem(),uniqueItem(),uniqueItem()]
        
        let expectedError = anyNSError()
        expect(sut: sut, toCompleteWithError: expectedError) {
            store.completeDeletionSuccessfully()
            store.completeInsertion(with: expectedError)
        }
    }
    
    
    func test_save_succeedOnSuccessCacheInsertion() {
        let currentDate = Date()
        let (sut, store) = makeSUT(timestamp: { currentDate })
        
        expect(sut: sut, toCompleteWithError: nil) {
            store.completeDeletionSuccessfully()
            store.completeInsertionSuccessfully()
        }
    }
    
    func expect(sut: LocalFeedLoader, toCompleteWithError expectedError: NSError?, file: StaticString = #file, line: UInt = #line, when action: @escaping(() -> Void)) {
        var receivedError: NSError?
        let exp = expectation(description: "wait for completion")
        sut.save(items: [uniqueItem()]) { error in
            receivedError = error as? NSError
            exp.fulfill()
        }
        action()
        
        wait(for: [exp], timeout: 1)
        
        XCTAssertEqual(expectedError?.code, receivedError?.code)
        XCTAssertEqual(expectedError?.domain, receivedError?.domain)
    }
    
    func makeSUT(timestamp: @escaping () -> Date = Date.init, file: StaticString = #file, line: UInt = #line) -> (sut: LocalFeedLoader, store: FeedStoreSpy) {
        let store = FeedStoreSpy()
        let sut = LocalFeedLoader(store: store, timestamp: timestamp)
        trackForMemoryLeaks(store, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, store)
    }
    
    func uniqueItem() -> FeedItem {
        FeedItem(id: UUID(), description: "any", location: "any", image: anyURL())
    }
}
