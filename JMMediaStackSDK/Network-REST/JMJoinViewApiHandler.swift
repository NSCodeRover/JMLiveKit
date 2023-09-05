//
//  JoinViewApiHandler.swift
//  MediaStack
//
//  Created by Onkar Dhanlobhe on 26/07/23.
//

import Foundation

class JMJoinViewApiHandler {
    
    class func validateJoiningDetails(meetingId: String, meetingPin: String, userName: String, meetingUrl: String, completion: @escaping ((JMMediaAPIResult<RoomdetailsData, JMMediaError>) -> Void)) {
        
        let parameters = [
            "extension": meetingId,
            "pin": meetingPin,
            "memberName": userName,
        ]
        
        let baseurl = meetingUrl + "api/roomdetails"
        let bodyData = JMJSONConverter.convertDictionaryToData(parameters)
        JMNetworkManager.performRequest(with: URL.init(string: baseurl)!, method: .post,body: bodyData) { result in
            LOG.debug("URL: \(baseurl)")
            switch result {
            case .success(let json):
                LOG.debug("success with json - \(json.description)")
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
                    let decoder = JSONDecoder()
                    var dataModel = try decoder.decode(RoomdetailsResponseDTO.self, from: jsonData)
                    dataModel.data.jiomeetId = parameters["extension"] as? String ?? ""
                    completion(.success(dataModel.data))
                }
                catch {
                    LOG.debug("failed with error - \(error.localizedDescription)")
                    completion(.failure(JMMediaError(type: .loginFailed, description: error.localizedDescription)))
                }
            case .failure(let error):
                LOG.debug("failed with error - \(error.localizedDescription)")
                completion(.failure(JMMediaError(type: .loginFailed, description: error.localizedDescription)))
            }
        }
    }
}

//MODEL
struct RoomdetailsResponseDTO: Decodable {
    var success: Bool
    var data: RoomdetailsData
}
struct RoomdetailsData: Decodable {
    private enum CodingKeys: String, CodingKey {
        case mediaServer
        case jwtToken
    }
    let mediaServer: MediaServer
    let jwtToken: String
    var jiomeetId: String = ""
}
struct MediaServer: Decodable {
    let publicBaseUrl: String
}
struct JMMeetingDetails{
    var meetingId:String
    var meetingPin:String
    var meetingUrl:String
    init(meetingId: String, meetingPin: String, meetingUrl: String) {
        self.meetingId = meetingId
        self.meetingPin = meetingPin
        self.meetingUrl = meetingUrl
    }
}
