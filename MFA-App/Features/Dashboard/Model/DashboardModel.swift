//
//  DashboardModel.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import Foundation

enum ActionStatus: Equatable {
    case idle
    case running
    case success(String)
    case failed(String)

    var detail: String? {
        switch self {
        case .idle: return nil
        case .running: return "Running..."
        case .success(let message): return message
        case .failed(let message): return message
        }
    }
}
