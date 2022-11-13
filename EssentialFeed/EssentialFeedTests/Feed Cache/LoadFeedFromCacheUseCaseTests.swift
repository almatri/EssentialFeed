//
//  LoadFeedFromCacheUseCaseTests.swift
//  EssentialFeedTests
//
//  Created by Musa Almatri on 12/11/2022.
//  Copyright © 2022 Essential Developer. All rights reserved.
//

import XCTest
@testable import EssentialFeed

class LoadFeedFromCacheUseCaseTests: XCTestCase {
    
    func test_init_doesNotMessageStoreUponCreation() {
        let (_, store) = makeSUT()
        
        XCTAssertTrue(store.receivedMessages.isEmpty)
    }
    
    func test_load_requestCacheRetrival() {
        let (sut, store) = makeSUT()
        
        sut.load() { _ in }
        
        XCTAssertEqual(store.receivedMessages, [.retrive])
    }
    
    func test_load_failsOnRetrivalError() {
        let (sut, store) = makeSUT()
        let retrivalError = anyNSError()
        
        expect(sut, toCompleteWith: .failure(retrivalError)) {
            store.completeRetrival(with: retrivalError)
        }
    }
    
    func test_load_deliverNoImagesOnEmptyCache() {
        let (sut, store) = makeSUT()
        
        expect(sut, toCompleteWith: .success([])) {
            store.completeRetrivalWithEmptyCache()
        }
    }
    
    func test_load_deliverCachedImagesOnLessThanSevenDaysOldCache() {
        let feed = uniqueImageFeed()
        let fixedCurrentDate = Date()
        let lessThanSevenDaysTimeStamp = fixedCurrentDate.adding(days: -7).adding(seconds: 1)
        let (sut, store) = makeSUT(timestamp: {fixedCurrentDate})
        
        expect(sut, toCompleteWith: .success(feed.models)) {
            store.completeRetrival(with: feed.local, timestamp: lessThanSevenDaysTimeStamp)
        }
    }
    
    func test_load_deliverNoCacheImagesOnSevenDaysOldCache() {
        let feed = uniqueImageFeed()
        let fixedCurrentDate = Date()
        let sevenDaysTimeStamp = fixedCurrentDate.adding(days: -7)
        let (sut, store) = makeSUT(timestamp: {fixedCurrentDate})
        
        expect(sut, toCompleteWith: .success([])) {
            store.completeRetrival(with: feed.local, timestamp: sevenDaysTimeStamp)
        }
    }
    
    func test_load_deliverNoCacheImagesOnMoreThanSevenDaysOldCache() {
        let feed = uniqueImageFeed()
        let fixedCurrentDate = Date()
        let sevenDaysTimeStamp = fixedCurrentDate.adding(days: -7).adding(seconds: -1)
        let (sut, store) = makeSUT(timestamp: {fixedCurrentDate})
        
        expect(sut, toCompleteWith: .success([])) {
            store.completeRetrival(with: feed.local, timestamp: sevenDaysTimeStamp)
        }
    }
    
    func test_load_deleteCacheOnRetrivalError() {
        let (sut, store) = makeSUT()
        
        sut.load { _ in }
        store.completeRetrival(with: anyNSError())
        
        XCTAssertEqual(store.receivedMessages, [.retrive, .deleteCacheFeed])
    }
    
    func test_load_doesNotdeleteCacheOnEmptyCache() {
        let (sut, store) = makeSUT()
        
        sut.load { _ in }
        store.completeRetrivalWithEmptyCache()
        
        XCTAssertEqual(store.receivedMessages, [.retrive])
    }
    
    func test_load_deleteCacheOnOlderThanSevenDaysCache() {
        let feed = uniqueImageFeed()
        let fixedCurrentDate = Date()
        let sevenDaysTimeStamp = fixedCurrentDate.adding(days: -7).adding(seconds: -1)
        let (sut, store) = makeSUT(timestamp: {fixedCurrentDate})
        
        sut.load { _ in }
        store.completeRetrival(with: feed.local, timestamp: sevenDaysTimeStamp)
        
        XCTAssertEqual(store.receivedMessages, [.retrive, .deleteCacheFeed])
    }
    
    func test_load_doesNotDeleteCacheOnSevenDaysCache() {
        let feed = uniqueImageFeed()
        let fixedCurrentDate = Date()
        let sevenDaysTimeStamp = fixedCurrentDate.adding(days: -7)
        let (sut, store) = makeSUT(timestamp: {fixedCurrentDate})
        
        sut.load { _ in }
        store.completeRetrival(with: feed.local, timestamp: sevenDaysTimeStamp)
        
        XCTAssertEqual(store.receivedMessages, [.retrive, .deleteCacheFeed])
    }
    
    func test_load_doesNotDeleteCacheOnLessThanSevenDaysCache() {
        let feed = uniqueImageFeed()
        let fixedCurrentDate = Date()
        let sevenDaysTimeStamp = fixedCurrentDate.adding(days: -7).adding(seconds: 1)
        let (sut, store) = makeSUT(timestamp: {fixedCurrentDate})
        
        sut.load { _ in }
        store.completeRetrival(with: feed.local, timestamp: sevenDaysTimeStamp)
        
        XCTAssertEqual(store.receivedMessages, [.retrive])
    }
    
    func test_load_doesNotCompleteWhenSUTInstanceHasBeenDeallocated() {
        var (sut, store): (LocalFeedLoader?, FeedStoreSpy) = makeSUT()
        
        var recievedResult: LocalFeedLoader.LoadResult?
        sut?.load { result in
            recievedResult = result
        }
        sut = nil
        store.completeRetrival(with: anyNSError())
        
        XCTAssertNil(recievedResult)
    }
    
    func expect(_ sut: LocalFeedLoader, toCompleteWith expectedResult: LocalFeedLoader.LoadResult, file: StaticString = #file, line: UInt = #line , when action: () -> ()) {
        let exp = expectation(description: "wait for response")
        
        sut.load { receivedResult in
            switch (receivedResult, expectedResult) {
            case let (.success(receivedImages), .success(expectedImages)):
                XCTAssertEqual(receivedImages, expectedImages, file: file, line: line)
            case let (.failure(receivedError as NSError), .failure(expectedError as NSError)):
                XCTAssertEqual(receivedError.code, expectedError.code, file: file, line: line)
                XCTAssertEqual(receivedError.domain, expectedError.domain, file: file, line: line)
            default:
                XCTFail("Received unexpected response", file: file, line: line)
            }
            exp.fulfill()
        }
        action()
        
        wait(for: [exp], timeout: 1)
    }
    
    func makeSUT(timestamp: @escaping () -> Date = Date.init, file: StaticString = #file, line: UInt = #line) -> (sut: LocalFeedLoader, store: FeedStoreSpy) {
        let store = FeedStoreSpy()
        let sut = LocalFeedLoader(store: store, timestamp: timestamp)
        trackForMemoryLeaks(store, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, store)
    }
    
    func uniqueImage() -> FeedImage {
        FeedImage(id: UUID(), description: "any", location: "any", url: anyURL())
    }
    
    func uniqueImageFeed() -> (models: [FeedImage], local: [LocalFeedImage]) {
        let images = [uniqueImage(),uniqueImage(),uniqueImage()]
        
        let localFeedImage = images.map { LocalFeedImage(id: $0.id,
                                                         description: $0.description,
                                                         location: $0.location,
                                                         url: $0.url) }
        return (images, localFeedImage)
    }
}

extension Date {
    
    func adding(days: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: days, to: self)!
    }
    
    func adding(seconds: Int) -> Date {
        return Calendar.current.date(byAdding: .second, value: seconds, to: self)!
    }
}
