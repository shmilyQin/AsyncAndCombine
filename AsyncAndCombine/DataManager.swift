//
//  DataManager.swift
//  AsyncAndCombine
//
//  Created by 覃孙波 on 2023/4/15.
//

import Foundation
import Combine
import Alamofire
class DataManager {
    private(set) var value = 0.0 {
        didSet {
            subject.send(value)
            if value == 1 {
                subject.send(completion: .finished)
            }
            
        }
    }

    private let subject = PassthroughSubject<Double, Never>()

    func increment(by value: Double) {
        self.value = value
    }
    
    func saveFile(urlString: String, fileName: String) -> AnyPublisher<Double, Never> {
        download(urlString: urlString, fileName: fileName)
        return subject.eraseToAnyPublisher()
    }
    
    private func download(urlString: String, fileName: String) {
        AF.download(urlString)
            .downloadProgress { [self] progress in
                increment(by: progress.fractionCompleted)
            }
            .responseData { response in
                if let data = response.value {
                    print("data recieved")
                    self.writeToFile(data: data, fileName: fileName)
                }
            }
    }
    
    func writeToFile(data: Data, fileName: String) {
        // get path of directory
        
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last else {
            return
        }
        // create file url
        let fileurl =  directory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: fileurl.path) {
            if let fileHandle = FileHandle(forWritingAtPath: fileurl.path) {
                print("FileExist")
            } else {
                print("Can't open file to write.")
            }
        } else {
            // if file does not exist write data for the first time
            do {
                try data.write(to: fileurl, options: .atomic)
            } catch {
                print("Unable to write in new file.")
            }
        }
    }
}
