//
//  validate-screenshots.swift — ASC screenshot validator/flattener (#55)
//
//  Created by Claude, Fast Five Products LLC, on 7/30/26.
//
//  Copyright © 2026 Fast Five Products LLC. All rights reserved.
//
//  This file is part of a project licensed under the GNU Affero General Public License v3.0.
//  See the LICENSE file at the root of this repository for full terms.
//
//  An exception applies: Fast Five Products LLC retains the right to use this code and
//  derivative works in proprietary software without being subject to the AGPL terms.
//  See LICENSE-EXCEPTIONS.md for details.
//
//  Usage: validate-screenshots <WIDTHxHEIGHT> <file.png> [...]
//
//  Asserts each PNG's pixel dimensions EXACTLY match the accepted App Store
//  Connect size, and that the file carries no alpha channel (the ASC analog
//  of the Play Store gotcha). A file captured WITH alpha is flattened in
//  place (redrawn into an opaque RGB context on white) and re-verified.
//  Exits non-zero on any failure so capture scripts fail loudly.
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
    exit(1)
}

func isOpaque(_ image: CGImage) -> Bool {
    switch image.alphaInfo {
    case .none, .noneSkipLast, .noneSkipFirst:
        return true
    default:
        return false
    }
}

func loadImage(_ path: String) -> CGImage {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fail("\(path): unreadable image")
    }
    return image
}

func writePNG(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fail("\(path): cannot create PNG destination")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fail("\(path): PNG write failed")
    }
}

// Redraw on an opaque white RGB canvas — drops the alpha channel.
func flattened(_ image: CGImage) -> CGImage {
    guard let context = CGContext(
        data: nil,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        fail("cannot create opaque context")
    }
    let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(rect)
    context.draw(image, in: rect)
    guard let result = context.makeImage() else {
        fail("flatten failed")
    }
    return result
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    fail("usage: validate-screenshots <WIDTHxHEIGHT> <file.png> [...]")
}

let dims = arguments[1].split(separator: "x").compactMap { Int($0) }
guard dims.count == 2 else {
    fail("bad dimension spec '\(arguments[1])' (expected WIDTHxHEIGHT)")
}
let (expectedWidth, expectedHeight) = (dims[0], dims[1])

var failures = 0
for path in arguments.dropFirst(2) {
    var image = loadImage(path)

    guard image.width == expectedWidth && image.height == expectedHeight else {
        FileHandle.standardError.write(Data(
            "FAIL: \(path): \(image.width)x\(image.height), expected \(expectedWidth)x\(expectedHeight)\n".utf8))
        failures += 1
        continue
    }

    var note = "opaque"
    if !isOpaque(image) {
        image = flattened(image)
        writePNG(image, to: path)
        image = loadImage(path)
        guard isOpaque(image) else {
            fail("\(path): still carries alpha after flatten")
        }
        note = "alpha flattened"
    }

    print("OK \(path) \(image.width)x\(image.height) \(note)")
}

if failures > 0 {
    fail("\(failures) file(s) failed validation")
}
