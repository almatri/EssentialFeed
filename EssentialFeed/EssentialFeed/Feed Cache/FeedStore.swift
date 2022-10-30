//
//  FeedStore.swift
//  EssentialFeed
//
//  Created by Musa Almatri on 30/10/2022.
//  Copyright © 2022 Essential Developer. All rights reserved.
//

import Foundation

public protocol FeedStore {
    typealias DeletionCompletion = ((Error?) -> Void)
    typealias InsertionCompletion = ((Error?) -> Void)
    
    func deleteCacheFeed(completion: @escaping DeletionCompletion)
    func insertCache(items: [FeedItem], timestamp: Date, completion: @escaping InsertionCompletion)
}
