//
//  Extensions.swift
//  native_file_explorer_launcher
//
//  Created by Leon Hoppe on 08.09.22.
//

import Foundation

extension NSBitmapImageRep {
    var png: Data? { representation(using: .png, properties: [:]) }
}

extension Data {
    var bitmap: NSBitmapImageRep? { NSBitmapImageRep(data: self) }
}

extension NSImage {
    var png: Data? { tiffRepresentation?.bitmap?.png }
}
