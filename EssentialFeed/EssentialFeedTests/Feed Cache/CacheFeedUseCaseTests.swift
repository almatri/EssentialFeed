//
//  CacheFeedUseCaseTests.swift
//  EssentialFeedTests
//
//  Created by Musa Almatri on 26/10/2022.
//  Copyright © 2022 Essential Developer. All rights reserved.
//

import XCTest
@testable import EssentialFeed

class FeedStoreSpy: FeedStore {
    enum ReceivedMessage: Equatable {
        case deleteCacheFeed
        case insertCache([LocalFeedItem], Date)
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
    
    func insertCache(items: [LocalFeedItem], timestamp: Date, completion: @escaping InsertionCompletion) {
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
        
        sut.save(items: uniqueItems().models)
        
        XCTAssertEqual(store.receivedMessages, [.deleteCacheFeed])
    }
    
    func test_save_doesNotInsertCacheOnDeletionError() {
        let (sut, store) = makeSUT()
        
        sut.save(items: uniqueItems().models)
        store.completeDeletion(with: anyNSError())
        
        XCTAssertEqual(store.receivedMessages, [.deleteCacheFeed])
    }

    func test_save_requestInsertionWithTimestampOnSuccessCacheDeletion() {
        let currentDate = Date()
        let (sut, store) = makeSUT(timestamp: { currentDate })
        let items = uniqueItems()
        sut.save(items: items.models)
        store.completeDeletionSuccessfully()
        
        XCTAssertEqual(store.receivedMessages, [.deleteCacheFeed, .insertCache(items.local, currentDate)])
    }
    
    func test_save_failsOnDeletionError() {
        let currentDate = Date()
        let (sut, store) = makeSUT(timestamp: { currentDate })
        
        expect(sut: sut, toCompleteWithError: anyNSError()) {
            store.completeDeletion(with: anyNSError())
        }
    }
    
    func test_save_failsOnInsertionError() {
        let currentDate = Date()
        let (sut, store) = makeSUT(timestamp: { currentDate })
        
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
    
    func test_save_doesNotCompleteDeletionAfterSUTDeallocation() {
        let store = FeedStoreSpy()
        var sut: LocalFeedLoader? = LocalFeedLoader(store: store, timestamp: {Date()})
        
        var receivedResult: [LocalFeedLoader.SaveResult] = []
        sut?.save(items: uniqueItems().models) { error in
            receivedResult.append(error)
        }
        sut = nil
        store.completeDeletion(with: anyNSError())
        
        XCTAssertTrue(receivedResult.isEmpty)
    }
    
    func test_save_doesNotCompleteInsertionAfterSUTDeallocation() {
        let store = FeedStoreSpy()
        var sut: LocalFeedLoader? = LocalFeedLoader(store: store, timestamp: {Date()})
        
        var receivedResult: [LocalFeedLoader.SaveResult] = []
        sut?.save(items: uniqueItems().models) { error in
            receivedResult.append(error)
        }
        store.completeDeletionSuccessfully()
        sut = nil
        store.completeInsertion(with: anyNSError())
        
        XCTAssertTrue(receivedResult.isEmpty)
    }
    
    func expect(sut: LocalFeedLoader, toCompleteWithError expectedError: NSError?, file: StaticString = #file, line: UInt = #line, when action: @escaping(() -> Void)) {
        var receivedError: NSError?
        let exp = expectation(description: "wait for completion")
        sut.save(items: uniqueItems().models) { error in
            receivedError = error as? NSError
            exp.fulfill()
        }
        action()
        
        wait(for: [exp], timeout: 1)
        
        XCTAssertEqual(expectedError?.code, receivedError?.code)
        XCTAssertEqual(expectedError?.domain, receivedError?.domain)
    }
    
    func uniqueItems() -> (models: [FeedItem], local: [LocalFeedItem]) {
        let items = [uniqueItem(),uniqueItem(),uniqueItem()]
        let localItems = items.map { LocalFeedItem(id: $0.id,
                                                   description: $0.description,
                                                   location: $0.location,
                                                   image: $0.url) }
        return (items, localItems)
    }
    
    func makeSUT(timestamp: @escaping () -> Date = Date.init, file: StaticString = #file, line: UInt = #line) -> (sut: LocalFeedLoader, store: FeedStoreSpy) {
        let store = FeedStoreSpy()
        let sut = LocalFeedLoader(store: store, timestamp: timestamp)
        trackForMemoryLeaks(store, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, store)
    }
    
    func uniqueItem() -> FeedItem {
        FeedItem(id: UUID(), description: "any", location: "any", imageURL: anyURL())
    }
}
