//
//  JMNetworkManager.swift
//  JMMediaStackSDK
//
//  Created by Onkar Dhanlobhe on 26/07/23.
//

import Foundation

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

//ERROR API
enum JMMediaAPIResult<T, E> {
    case success(T)
    case failure(E)
}

public class JMNetworkManager {
    public class func performRequest(with url: URL, method: HTTPMethod, body: Data? = nil, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.allHTTPHeaderFields = ["Content-Type":"application/json"]
        
        let session = URLSession.shared
        let task = session.dataTask(with: request) { (data, response, error) in
        
            if let error = error {
                completion(.failure(error))
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if !(200...299).contains(httpResponse.statusCode) {
                    let httpError = NSError(domain: "HTTPErrorDomain", code: httpResponse.statusCode, userInfo: nil)
                    completion(.failure(httpError))
                    return
                }
            }

            guard let responseData = data else {
                let noDataError = NSError(domain: "NoDataErrorDomain", code: -1, userInfo: nil)
                completion(.failure(noDataError))
                return
            }

            do {
                let jsonObject = try JSONSerialization.jsonObject(with: responseData, options: [])
                if let jsonDict = jsonObject as? [String: Any] {
                    completion(.success(jsonDict))
                } else {
                    let parsingError = NSError(domain: "ParsingErrorDomain", code: -1, userInfo: nil)
                    completion(.failure(parsingError))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
}

public class JMJSONConverter {
    public class func convertDictionaryToData(_ dictionary: [String: Any]) -> Data? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dictionary, options: [])
            return jsonData
        }
        catch {
            print("Error converting dictionary to data: \(error)")
            return nil
        }
    }
}
