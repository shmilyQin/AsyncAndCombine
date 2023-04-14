//
//  ContentView.swift
//  AsyncAndCombine
//
//  Created by 覃孙波 on 2023/4/13.
//

import SwiftUI
import Combine
import Alamofire

class ImageLoader {
    let url = URL(string: "https://picsum.photos/100")!
    let bigUrl = URL(string: "https://picsum.photos/500")!
    enum Status {
        case downloading(Float)
        case finished(Data)
    }
    
    func fetchImageWithAsync() async throws -> UIImage? {
        let (data, _) = try await URLSession.shared.data(from: url)
        return UIImage(data: data)
    }
    
    func fetchImageWithCombine() -> AnyPublisher<UIImage?, Error> {
        URLSession.shared.dataTaskPublisher(for: url)
            .map { UIImage(data: $0.data) }
            .mapError {$0}
            .eraseToAnyPublisher()
    }
    
    func fetchImages() async throws -> [UIImage] {
        async let firstImage = fetchImageWithAsync()
        async let secondImage = fetchImageWithAsync()
        async let thirdImage = fetchImageWithAsync()
        let images = try await [firstImage, secondImage, thirdImage]
        return images.compactMap{$0}
    }
    
    func download(_ url: URL, progressHandler: @escaping (Float) -> Void, completion: @escaping (Result<Data, Error>) -> Void) throws {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent("downLoadFile/" + "\(Date(timeIntervalSinceNow: 0))" + ".ipg")
        let destination: DownloadRequest.Destination = { _, _ in
            //两个参数表示如果有同名文件则会覆盖，如果路径中文件夹不存在则会自动创建
            return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        let request = AF.download(url, to: destination).responseData { item in
            let result = Result<Data, Error>.success(item.value!)
            completion(result)
        }
        request.downloadProgress { progress in
            progressHandler(Float(progress.fractionCompleted))
        }
    }
}

extension ImageLoader {
    func download() -> AsyncThrowingStream<Status, Error> {
        return AsyncThrowingStream { continuation in
            do {
                try self.download(bigUrl, progressHandler: { progress in
                    continuation.yield(.downloading(progress))
                }, completion: { result in
                    switch result {
                    case .success(let success):
                        continuation.yield(.finished(success))
                        continuation.finish()
                    case .failure(let failure):
                        continuation.finish(throwing: failure)
                    }
                })
            } catch {
                
            }
        }
    }
    
}

class ViewModel: ObservableObject {
    let loader = ImageLoader()
    @Published
    var image: UIImage?
    @Published
    var imageList: [UIImage] = []
    var bag = Set<AnyCancellable>()
    
    func fetchImage() async {
        do {
            let value = try await loader.fetchImageWithAsync()
            await MainActor.run(body: {
                image = value
            })
        } catch let error {
            print("error -- \(error)")
        }
    }
    
    func fetchImageWithCombine() {
        loader.fetchImageWithCombine()
            .receive(on: DispatchQueue.main)
            .sink { _ in
                
            } receiveValue: {[weak self] value in
                guard let self = self else { return }
                image = value
            }
            .store(in: &bag)
    }
    
    func fetchImages() async {
        do {
            let value = try await loader.fetchImages()
            await MainActor.run(body: {
                imageList = value
            })
        } catch let error {
            print("error -- \(error)")
        }
    }
    
    func downloadImage() async {
        do {
            for try await status in loader.download() {
                switch status {
                case .downloading(let progress):
                    print("progress --- \(progress)")
                case .finished(let data):
                    print("finished --- \(data)")
                }
            }
        } catch let error {
            print("error --- \(error)")
        }
    }
    
}

struct ContentView: View {
    @StateObject var viewModel = ViewModel()
    var body: some View {
        VStack(spacing: 20) {
//            if let image = viewModel.image {
//                Image(uiImage: image)
//            } else {
//                ProgressView()
//                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
//            }
            
            if !viewModel.imageList.isEmpty {
                ForEach(0 ..< viewModel.imageList.count, id: \.self) { index
                    in
                    Image(uiImage: viewModel.imageList[index])
                }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
            }
            
        }
        .onAppear {
//            viewModel.fetchImageWithCombine()
            Task {
//                await viewModel.fetchImage()
//                await viewModel.fetchImages()
                await viewModel.downloadImage()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
