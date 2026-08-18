//
//  SecurityCheck.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import Foundation

enum CheckStatus: Equatable {
    case checking
    case passed(String)
    case failed(String)

    var isPassed: Bool {
        if case .passed = self { return true }
        return false
    }

    var detail: String {
        switch self {
        case .checking: return "Checking..."
        case .passed(let message): return message
        case .failed(let message): return message
        }
    }
}

struct SecurityCheck: Identifiable {
    let id: String
    let title: String
    var status: CheckStatus

    var pending: SecurityCheck {
        SecurityCheck(id: id, title: title, status: .checking)
    }

    static let pendingBackend = SecurityCheck(
        id: "backend",
        title: "Server Connection",
        status: .checking
    )
}
