import Foundation
import AVFoundation
import CoreMedia

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - C FFI Exports for AVFoundation Video Probe

/// Returns the duration of the video in seconds.
/// Returns -1.0 on error.
@_cdecl("get_duration")
public func get_duration(_ path: UnsafePointer<CChar>?) -> Double {
    guard let path = path else { return -1.0 }
    
    let pathString = String(cString: path)
    let url = URL(fileURLWithPath: pathString)
    let asset = AVURLAsset(url: url)
    
    // Use synchronous loading for FFI
    let duration = asset.duration
    if duration.isIndefinite || duration.isNegativeInfinity {
        return -1.0
    }
    
    return CMTimeGetSeconds(duration)
}

/// Returns the total number of frames in the video.
/// Returns -1 on error.
@_cdecl("get_frame_count")
public func get_frame_count(_ path: UnsafePointer<CChar>?) -> Int32 {
    guard let path = path else { return -1 }
    
    let pathString = String(cString: path)
    let url = URL(fileURLWithPath: pathString)
    let asset = AVURLAsset(url: url)
    
    // Get the video track
    guard let videoTrack = asset.tracks(withMediaType: .video).first else {
        return -1
    }
    
    let duration = CMTimeGetSeconds(asset.duration)
    let frameRate = videoTrack.nominalFrameRate
    
    if duration <= 0 || frameRate <= 0 {
        return -1
    }
    
    return Int32(duration * Double(frameRate))
}

/// Extracts a specific frame as a JPEG buffer.
/// Returns a pointer to the buffer. The caller is responsible for freeing it using free_frame().
/// Sets *outSize to the size of the buffer.
/// Returns NULL on error.
@_cdecl("extract_frame")
public func extract_frame(
    _ path: UnsafePointer<CChar>?,
    _ frameNum: Int32,
    _ outSize: UnsafeMutablePointer<Int32>?
) -> UnsafeMutablePointer<UInt8>? {
    guard let path = path else { return nil }
    
    let pathString = String(cString: path)
    let url = URL(fileURLWithPath: pathString)
    let asset = AVURLAsset(url: url)
    
    // Get the video track to calculate time from frame number
    guard let videoTrack = asset.tracks(withMediaType: .video).first else {
        return nil
    }
    
    let frameRate = videoTrack.nominalFrameRate
    if frameRate <= 0 { return nil }
    
    // Calculate time for the requested frame
    let timeInSeconds = Double(frameNum) / Double(frameRate)
    let requestedTime = CMTime(seconds: timeInSeconds, preferredTimescale: 600)
    
    // Create image generator
    let imageGenerator = AVAssetImageGenerator(asset: asset)
    imageGenerator.appliesPreferredTrackTransform = true
    imageGenerator.requestedTimeToleranceBefore = .zero
    imageGenerator.requestedTimeToleranceAfter = .zero
    
    do {
        let cgImage = try imageGenerator.copyCGImage(at: requestedTime, actualTime: nil)
        
        // Convert CGImage to JPEG data
        #if os(iOS)
        let uiImage = UIImage(cgImage: cgImage)
        guard let jpegData = uiImage.jpegData(compressionQuality: 0.9) else {
            return nil
        }
        #elseif os(macOS)
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else {
            return nil
        }
        #endif
        
        // Allocate buffer and copy data
        let size = jpegData.count
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        jpegData.copyBytes(to: buffer, count: size)
        
        outSize?.pointee = Int32(size)
        return buffer
        
    } catch {
        return nil
    }
}

/// Frees the buffer returned by extract_frame.
@_cdecl("free_frame")
public func free_frame(_ buffer: UnsafeMutablePointer<UInt8>?) {
    buffer?.deallocate()
}
