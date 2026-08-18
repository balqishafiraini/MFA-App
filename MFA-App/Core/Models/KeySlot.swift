//
//  KeySlot.swift
//  MFA-App
//
//  Created by Balqis Shafira Aini on 16/08/26.
//

import Foundation

enum KeySlot: String {
    case a = "id.mfaapp.securekey.a"
    case b = "id.mfaapp.securekey.b"

    var next: KeySlot {
        self == .a ? .b : .a
    }

    var tag: Data {
        Data(rawValue.utf8)
    }
}
