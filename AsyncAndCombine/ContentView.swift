//
//  ContentView.swift
//  AsyncAndCombine
//
//  Created by 覃孙波 on 2023/4/13.
//

import SwiftUI
import Combine

class ImageLoader {
    let url = URL(string: "https://picsum.photos/100")!
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
                await viewModel.fetchImages()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
