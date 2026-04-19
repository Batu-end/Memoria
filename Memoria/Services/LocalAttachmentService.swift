//
//  LocalAttachmentService.swift
//  Memoria
//
//  Created by Memoria on 4/18/26.
//

import Foundation
import SwiftUI

/// Safely anchors massive Image files onto the local macOS Application Support directory
/// rather than bloating the SwiftData SQLite tables with memory-heavy binary strings.
class LocalAttachmentService {
    static let shared = LocalAttachmentService()
    
    private let fileManager = FileManager.default
    private let domainMask = FileManager.SearchPathDomainMask.userDomainMask
    private let directory = FileManager.SearchPathDirectory.applicationSupportDirectory
    
    private var baseDirectoryURL: URL? {
        guard let appSupport = fileManager.urls(for: directory, in: domainMask).first else { return nil }
        let memoriaDir = appSupport.appendingPathComponent("MemoriaApp", isDirectory: true)
        let attachmentsDir = memoriaDir.appendingPathComponent("Attachments", isDirectory: true)
        
        // Create architecture if it doesn't exist
        if !fileManager.fileExists(atPath: attachmentsDir.path) {
            do {
                try fileManager.createDirectory(at: attachmentsDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Memoria Error: Failed to create attachments OS directory - \(error)")
                return nil
            }
        }
        
        return attachmentsDir
    }
    
    /// Reads raw NSImage data from a dragged-in file URL and writes it to the local cache.
    /// Returns a UUID string tracking the specific file.
    func saveImage(from url: URL) -> String? {
        // Gain file access permission (crucial for macOS sandbox)
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        
        guard let data = try? Data(contentsOf: url),
              let nsImage = NSImage(data: data),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("Memoria Error: Disallowed or corrupted file type dropped.")
            return nil
        }
        
        // Re-encode natively to standard high-quality JPEG
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            return nil
        }
        
        guard let targetFolder = baseDirectoryURL else { return nil }
        
        let uniqueID = UUID().uuidString
        let destinationURL = targetFolder.appendingPathComponent("\(uniqueID).jpg")
        
        do {
            try jpegData.write(to: destinationURL)
            return uniqueID
        } catch {
            print("Memoria Error: Failed to write JPG chunk to disk - \(error)")
            return nil
        }
    }
    
    /// Fetches the raw Data for a requested attachment UUID string.
    func loadImageData(id: String) -> Data? {
        guard let folder = baseDirectoryURL else { return nil }
        let targetURL = folder.appendingPathComponent("\(id).jpg")
        
        guard fileManager.fileExists(atPath: targetURL.path) else { return nil }
        
        return try? Data(contentsOf: targetURL)
    }
    
    /// Purges a specific file from disk (e.g. when dropping a new screenshot or deleting the trade).
    func deleteImage(id: String) {
        guard let folder = baseDirectoryURL else { return }
        let targetURL = folder.appendingPathComponent("\(id).jpg")
        
        if fileManager.fileExists(atPath: targetURL.path) {
            try? fileManager.removeItem(at: targetURL)
        }
    }
}
