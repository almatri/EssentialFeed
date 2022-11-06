//
//  Copyright © 2019 Essential Developer. All rights reserved.
//

import Foundation

public struct RemoteFeedItem: Decodable, Equatable {
    let id: UUID
    let description: String?
    let location: String?
    let image: URL
}
