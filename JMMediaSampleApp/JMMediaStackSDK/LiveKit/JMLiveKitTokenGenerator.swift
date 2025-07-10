//
//  JMLiveKitTokenGenerator.swift
//  JMMediaStackSDK
//
//  Created by AI Assistant on LiveKit Integration
//

import Foundation
import CommonCrypto

// Define LOG for logging


public class JMLiveKitTokenGenerator {
    
    public static func generateAccessToken(
        apiKey: String,
        apiSecret: String,
        roomName: String,
        participantName: String,
        ttl: TimeInterval = 3600 // 1 hour default
    ) -> String? {
        
        let now = Date()
        let exp = now.addingTimeInterval(ttl)
        
        // JWT Header
        let header: [String: Any] = [
            "alg": "HS256",
            "typ": "JWT"
        ]
        
        // JWT Payload with LiveKit claims
        let payload: [String: Any] = [
            "iss": apiKey,
            "sub": participantName,
            "iat": Int(now.timeIntervalSince1970),
            "exp": Int(exp.timeIntervalSince1970),
            "nbf": Int(now.timeIntervalSince1970),
            "video": [
                "room": roomName,
                "roomJoin": true,
                "roomListParticipant": true,
                "roomRecord": false,
                "roomAdmin": false,
                "roomCreate": false,
                "canPublish": true,
                "canSubscribe": true,
                "canPublishData": true
            ]
        ]
        
        do {
            // Encode header and payload
            let headerData = try JSONSerialization.data(withJSONObject: header)
            let payloadData = try JSONSerialization.data(withJSONObject: payload)
            
            let headerString = headerData.base64URLEncodedString()
            let payloadString = payloadData.base64URLEncodedString()
            
            // Create signature input
            let signatureInput = "\(headerString).\(payloadString)"
            
            // Generate HMAC-SHA256 signature
            guard let signature = hmacSHA256(data: signatureInput, key: apiSecret) else {
                LOG.error("LiveKit: Failed to generate HMAC signature")
                return nil
            }
            
            // Create final JWT
            let jwt = "\(signatureInput).\(signature)"
            
            LOG.debug("LiveKit: Generated JWT token for room: \(roomName), participant: \(participantName)")
            return jwt
            
        } catch {
            LOG.error("LiveKit: Error generating access token: \(error)")
            return nil
        }
    }
    
    private static func hmacSHA256(data: String, key: String) -> String? {
        guard let keyData = key.data(using: .utf8),
              let inputData = data.data(using: .utf8) else {
            return nil
        }
        
        let algorithm = CCHmacAlgorithm(kCCHmacAlgSHA256)
        let digestLength = Int(CC_SHA256_DIGEST_LENGTH)
        
        var result = Data(count: digestLength)
        
        result.withUnsafeMutableBytes { resultBytes in
            keyData.withUnsafeBytes { keyBytes in
                inputData.withUnsafeBytes { inputBytes in
                    CCHmac(algorithm,
                          keyBytes.baseAddress, keyData.count,
                          inputBytes.baseAddress, inputData.count,
                          resultBytes.baseAddress)
                }
            }
        }
        
        return result.base64URLEncodedString()
    }
}

// MARK: - Data Extensions for Base64URL encoding
extension Data {
    func base64URLEncodedString() -> String {
        let base64 = self.base64EncodedString()
        let base64URL = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return base64URL
    }
} 
