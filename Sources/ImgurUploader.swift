import AppKit
import Foundation

class ImgurUploader: UploadProvider {
    let name = "Imgur (Anonymous)"

    // Note: In production, use your own Imgur Client-ID registered at https://api.imgur.com/oauth2/addclient
    // For development/testing, this uses Imgur's anonymous API
    private let clientID = "YEuW7H4G3bVPeiAqmj0eLvJZ3n7xnT4Q"  // Demo client ID
    private let uploadEndpoint = URL(string: "https://api.imgur.com/3/image")!

    func upload(image: NSImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let imageData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            completion(.failure(CloudError.invalidImage))
            return
        }

        let base64 = pngData.base64EncodedString(options: .lineLength64Characters)

        var request = URLRequest(url: uploadEndpoint)
        request.httpMethod = "POST"
        request.setValue("Client-ID \(clientID)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "image=\(base64.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&type=base64"
        request.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(CloudError.uploadFailed("No data returned")))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let responseData = json["data"] as? [String: Any],
                   let link = responseData["link"] as? String {
                    completion(.success(link))
                } else {
                    // Try parsing as Imgur response
                    let decoder = JSONDecoder()
                    let imgurResponse = try decoder.decode(ImgurResponse.self, from: data)
                    if let link = imgurResponse.data.link {
                        completion(.success(link))
                    } else {
                        completion(.failure(CloudError.uploadFailed("No link in response")))
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

// MARK: - Imgur API Response

struct ImgurResponse: Codable {
    let data: ImgurData
    let status: Int
    let success: Bool
}

struct ImgurData: Codable {
    let id: String?
    let title: String?
    let description: String?
    let datetime: Int?
    let type: String?
    let animated: Bool?
    let width: Int?
    let height: Int?
    let size: Int?
    let bandwidth: Int?
    let deletehash: String?
    let name: String?
    let link: String?
    let gifv: String?
    let mp4: String?
    let vote: String?
    let favorite: Bool?
    let nsfw: Bool?
    let section: String?
    let account_url: String?
    let account_id: Int?
    let is_ad: Bool?
    let in_most_viral: Bool?
    let has_sound: Bool?
    let tags: [String]?
    let width_str: String?
    let height_str: String?
}
