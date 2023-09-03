#!/usr/bin/env xcrun swift

//
//  fixtimezone.swift
//  TimeZone Fix
//
//  Created by Lakr Aream on 2023/9/4.
//

import Cocoa

guard CommandLine.arguments.count == 4 else {
    print("[!] unrecognized command line argument format")
    print("[i] \(CommandLine.arguments[0]) /path/to/photo/dir 'expected timezone' 'target timezone'")
    print("[i] eg: \(CommandLine.arguments[0]) /path/to/photo/dir '+08:00' '+09:00'")
    exit(1)
}

let searchDir = URL(fileURLWithPath: CommandLine.arguments[1])
let expectedOffsetString = CommandLine.arguments[2]
let changeToOffset = CommandLine.arguments[3]

print("[+] changing timezone without shifting date time from \(expectedOffsetString) to \(changeToOffset)")

func rebuildTimeZone(
    imageFile: URL,
    expectedOffsetString: String,
    changeToOffset: String
) {
    guard let dataProvider = CGDataProvider(filename: imageFile.path),
          let data = dataProvider.data
    else {
        print("[E] unable to prepare data")
        return
    }
    let mutableData = NSMutableData(data: data as Data)
    guard let imageSource = CGImageSourceCreateWithData(data, nil),
          let type = CGImageSourceGetType(imageSource),
          let imageDestination = CGImageDestinationCreateWithData(mutableData, type, 1, nil),
          let imageProperties = CGImageSourceCopyMetadataAtIndex(imageSource, 0, nil),
          let mutableMetadata = CGImageMetadataCreateMutableCopy(imageProperties)
    else {
        print("[E] unable to load image")
        return
    }
    guard let dataProvider = CGDataProvider(filename: imageFile.path),
          let data = dataProvider.data,
          let cgImage = NSImage(data: data as Data)?
          .cgImage(forProposedRect: nil, context: nil, hints: nil)
    else {
        print("[E] unable to prepare data")
        return
    }
    guard let offsetTag = CGImageMetadataCopyTagMatchingImageProperty(
        imageProperties,
        kCGImagePropertyExifDictionary,
        kCGImagePropertyExifOffsetTimeDigitized
    ), let offsetDigitizedTag = CGImageMetadataCopyTagMatchingImageProperty(
        imageProperties,
        kCGImagePropertyExifDictionary,
        kCGImagePropertyExifOffsetTimeDigitized
    ), let offsetOriginalTag = CGImageMetadataCopyTagMatchingImageProperty(
        imageProperties,
        kCGImagePropertyExifDictionary,
        kCGImagePropertyExifOffsetTimeOriginal
    ) else {
        print("[E] unable to read from image")
        return
    }
    if let offsetTagValue = CGImageMetadataTagCopyValue(offsetTag) as? String {
        guard offsetTagValue == expectedOffsetString else {
            print("[E] timezone string mismatched! expected: \(expectedOffsetString) found: \(offsetTagValue)")
            return
        }
        CGImageMetadataSetValueMatchingImageProperty(
            mutableMetadata,
            kCGImagePropertyExifDictionary,
            kCGImagePropertyExifOffsetTime,
            changeToOffset as CFString
        )
        print("[+] writing timezone information for tag \(kCGImagePropertyExifOffsetTime)")
    }
    if let offsetTagValue = CGImageMetadataTagCopyValue(offsetDigitizedTag) as? String {
        guard offsetTagValue == expectedOffsetString else {
            print("[E] timezone string mismatched! expected: \(expectedOffsetString) found: \(offsetTagValue)")
            return
        }
        CGImageMetadataSetValueMatchingImageProperty(
            mutableMetadata,
            kCGImagePropertyExifDictionary,
            kCGImagePropertyExifOffsetTimeDigitized,
            changeToOffset as CFString
        )
        print("[+] writing timezone information for tag \(kCGImagePropertyExifOffsetTimeDigitized)")
    }
    if let offsetTagValue = CGImageMetadataTagCopyValue(offsetOriginalTag) as? String {
        guard offsetTagValue == expectedOffsetString else {
            print("[E] timezone string mismatched! expected: \(expectedOffsetString) found: \(offsetTagValue)")
            return
        }
        CGImageMetadataSetValueMatchingImageProperty(
            mutableMetadata,
            kCGImagePropertyExifDictionary,
            kCGImagePropertyExifOffsetTimeOriginal,
            changeToOffset as CFString
        )
        print("[+] writing timezone information for tag \(kCGImagePropertyExifOffsetTimeOriginal)")
    }
    let finalMetadata = mutableMetadata as CGImageMetadata
    CGImageDestinationAddImageAndMetadata(imageDestination, cgImage, finalMetadata, nil)
    guard CGImageDestinationFinalize(imageDestination) else {
        print("[E] failed to finalize image data")
        return
    }
    do {
        try FileManager.default.removeItem(at: imageFile)
        try mutableData.write(toFile: imageFile.path)
    } catch {
        print("[E] failed to write")
        print(error.localizedDescription)
        return
    }
    print("[+] timezone information updated successfully")
}

print("[*] starting file walk inside \(searchDir.path)")

let enumerator = FileManager.default.enumerator(atPath: searchDir.path)
var candidates = [URL]()
while let subPath = enumerator?.nextObject() as? String {
    guard subPath.lowercased().hasSuffix("jpg") || subPath.lowercased().hasSuffix("jpeg") else { continue }
    let file = searchDir.appendingPathComponent(subPath)
    candidates.append(file)
}

print("[*] found \(candidates.count) candidates")

guard candidates.count > 0 else {
    print("no candidates found!")
    exit(1)
}

let paddingLength = String(candidates.count).count
for (idx, url) in candidates.enumerated() {
    print("[*] processing \(idx.paddedString(totalLength: paddingLength))/\(candidates.count) <\(url.lastPathComponent)>")
    fflush(stdout)
    autoreleasepool {
        rebuildTimeZone(imageFile: url, expectedOffsetString: expectedOffsetString, changeToOffset: changeToOffset)
    }
}

print("[*] completed update")

// helpers

extension Int {
    func paddedString(totalLength: Int) -> String {
        var str = String(self)
        while str.count < totalLength {
            str = "0" + str
        }
        return str
    }
}
