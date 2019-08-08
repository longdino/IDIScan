//
//  QRScanner.swift
//  QRCodeReader
//
//  Created by Han Jeon on 7/23/19.
//  Copyright © 2019 AppCoda. All rights reserved.
//

import UIKit

protocol CodeInputDelegate {
    func sendWasTapped(code: String)
}

protocol QRScannerDelegate: class {
    func received(code: Code)
}

class QRScanner: NSObject {
    var inputStream: InputStream!
    var outputStream: OutputStream!
    
    weak var delegate: QRScannerDelegate?
    
    var code = ""
    
    let maxReadLength = 4096
    
    func setupNetworkCommunication() {
        // 1
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        
        // 2
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                           "192.168.20.10" as CFString,
                                           9611,
                                           &readStream,
                                           &writeStream)
        
        inputStream = readStream!.takeRetainedValue()
        outputStream = writeStream!.takeRetainedValue()
        
        inputStream.delegate = self
        
        inputStream.schedule(in: .current, forMode: .common)
        outputStream.schedule(in: .current, forMode: .common)
        
        inputStream.open()
        outputStream.open()
        //outputStream.write("hello2", maxLength: 6)
        //outputStream.write("hello3", maxLength: 6)

        print("connected to the server")
    }
    
    func joinServer(code: String) {
        let data = "url: \(code)".data(using: .utf8)!

        self.code = code

        _ = data.withUnsafeBytes {
            guard ($0.baseAddress?.assumingMemoryBound(to: UInt8.self)) != nil else {
                print("Error joining server")
                return
            }
            //outputStream.write("hello6", maxLength: 6)
        }
    }
    
    func send(code: String) {
        let data = "url: \(code)".data(using: .utf8)!
        
        _ = data.withUnsafeBytes {
            guard ($0.baseAddress?.assumingMemoryBound(to: UInt8.self)) != nil else {
                print("Error joining server")
                return
            }
            print(code)
            print(data)
            print(code.count)
 //           outputStream.write("hello4", maxLength: 6)
            let encodedCode = [UInt8](code.utf8)
            outputStream.write(encodedCode, maxLength: encodedCode.count)
//            outputStream.write("hello4", maxLength: 6)
            //print("hello4")

        }
    }
    
    func receive() -> String? {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 512)
        let numberOfBytesRead = inputStream?.read(buffer, maxLength: 512)
        print("read buffer")
        let length = buffer.withMemoryRebound(to: Int8.self, capacity: 512) {
            return strlen($0)
        }
        print("length: \(length)")
        var message = ""
        //print("h1")
        if numberOfBytesRead! < 0, let error = inputStream.streamError{
            print(error)
            return message
        }
        else /*if numberOfBytesRead == length*/ {
            //print("h2")
            let array = Array(UnsafeBufferPointer(start: buffer, count: numberOfBytesRead!))
            //print("h3")
            for i in 0 ..< array.count {
                let u = UnicodeScalar(array[i])
                let char = Character(u)
                message.append(char)
                //print(message)
            }
            //print("h4")
            //print(message + "\n") // this lets the function to print the message right away.
            //message.append("\n")
            //stopServer()
        }
        return message
    }
    
    // Split and make a list of location received from the database
    func splitMessage(input: String) -> [String]? {
        var options = input.components(separatedBy: "|")
        if var last_elem = options.last {
            last_elem.removeLast(2)
            options.removeLast()
            options.insert(last_elem, at: options.endIndex)
            //print("last element: \(last_elem)")
        }
        //print("Returning list: \(options)")
            
        return options
    }
    
    func stopServer() {
        inputStream.close()
        outputStream.close()
    }
}

extension QRScanner: StreamDelegate {
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .hasBytesAvailable:
            print("bytes available")
            readAvailableBytes(stream: aStream as! InputStream)
        case .endEncountered:
            print("new code received")
            stopServer()
        case .errorOccurred:
            print("error occurred")
        case .hasSpaceAvailable:
            print("has space available")
        default:
            print("some other event...")
        }
    }
    private func readAvailableBytes(stream: InputStream) {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxReadLength)
        while stream.hasBytesAvailable {
            let numberOfBytesRead = inputStream.read(buffer, maxLength: maxReadLength)
            
            if numberOfBytesRead < 0, let error = stream.streamError {
                print(error)
                break
            }
        }
    }
}
