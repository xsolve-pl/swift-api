//
//  RequestCallback.swift
//  SwiftAPI
//
//  Created by Marek Kojder on 20.12.2016.
//  Copyright © 2016 XSolve. All rights reserved.
//

import Foundation

enum ResponseAction {
    case success((Data, HttpResponse?) -> Void)
    case failure((Error) -> Void)
    case progress((Int64, Int64) -> Void)
}

extension ResponseAction {

    func perform(with error: Error) {
        switch self {
        case .failure(let action):
            action(error)
        default:
            break
        }
    }

    func perform(with data: Data, and response: HttpResponse?) {
        switch self {
        case .success(let action):
            action(data, response)
        default:
            break
        }
    }

    func perform(with totalBytesSent: Int64, and totalBytesToSend: Int64) {
        switch self {
        case .progress(let action):
            action(totalBytesSent, totalBytesToSend)
        default:
            break
        }
    }

    func hasEqualType(with action: ResponseAction) -> Bool {
        switch (self, action) {
        case (.success(_), .success(_)):
            return true

        case (.failure(_), .failure(_)):
            return true

        case (.progress(_), .progress(_)):
            return true

        default:
            return false
        }
    }
}