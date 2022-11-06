//
//  LocalFeedImage.swift
//  EssentialFeed
//
//  Created by Musa Almatri on 06/11/2022.
//  Copyright © 2022 Essential Developer. All rights reserved.
//

import Foundation

public struct LocalFeedImage: Decodable, Equatable {
    let id: UUID
    let description: String?
    let location: String?
    let url: URL
}
