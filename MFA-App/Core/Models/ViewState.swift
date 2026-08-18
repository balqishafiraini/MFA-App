//
//  ViewState.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import Foundation

enum ViewState: Equatable {
    case idle
    case loading
    case success
    case failed(String)
}
