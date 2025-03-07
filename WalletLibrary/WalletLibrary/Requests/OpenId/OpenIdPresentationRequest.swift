/*---------------------------------------------------------------------------------------------
*  Copyright (c) Microsoft Corporation. All rights reserved.
*  Licensed under the MIT License. See License.txt in the project root for license information.
*--------------------------------------------------------------------------------------------*/

enum VerifiedIdPresentationRequestError: Error {
    case cancelPresentationRequestIsUnsupported
}

//SDKCHANGE: Added this type, to be able to use the fields in EntraWallet, and be able to encode to JSON
public class PresentationTokenResponse: Codable {
    public let idToken: String
    
    public let vpToken: String
    
    public let state: String?
    
    init(presentationResponse: PresentationResponse) throws {
      idToken = try presentationResponse.idToken.serialize()
      vpToken = (try presentationResponse.vpTokens.first?.serialize() ?? "Nothing")
      state = presentationResponse.state ?? "Nothing"
    }
}
//CHANGEEND

/**
 * Presentation Requst that is Open Id specific.
 */
class OpenIdPresentationRequest: VerifiedIdPresentationRequest {
    
    /// The look and feel of the requester.
    let style: RequesterStyle
    
    /// The requirement needed to fulfill request.
    let requirement: Requirement
    
    /// The root of trust results between the request and the source of the request.
    let rootOfTrust: RootOfTrust
    
    private let rawRequest: any OpenIdRawRequest
    
    private let responder: OpenIdResponder
    
    private let configuration: LibraryConfiguration
    
    init(content: PresentationRequestContent,
         rawRequest: any OpenIdRawRequest,
         openIdResponder: OpenIdResponder,
         configuration: LibraryConfiguration) {
        
        self.style = content.style
        self.requirement = content.requirement
        self.rootOfTrust = content.rootOfTrust
        self.rawRequest = rawRequest
        self.responder = openIdResponder
        self.configuration = configuration
    }
    
    /// Whether or not the request is satisfied on client side.
    func isSatisfied() -> Bool {
        do {
            try requirement.validate().get()
            return true
        } catch {
            /// TODO: log error.
            return false
        }
    }
    
    /// Completes the request and returns a Result object containing void if successful, and an error if not successful.
    func complete() async -> VerifiedIdResult<Void> {
        return await VerifiedIdResult<Void>.getResult {
            var response = try PresentationResponseContainer(rawRequest: self.rawRequest)
            try response.add(requirement: self.requirement)
            try await self.responder.send(response: response)
        }
    }

//SDKCHANGE: Added retrieveTokens to get the formatted presentation response, and return it in our type "PresentationTokenResponse".
    func retrieveTokens() async -> VerifiedIdResult<PresentationTokenResponse> {
        await VerifiedIdResult<PresentationTokenResponse>.getResult {
            var response = try PresentationResponseContainer(rawRequest: self.rawRequest)
            try response.add(requirement: self.requirement)
            let presentationResponseResult = try await self.responder.retrieveTokens(response: response)
          
            let tokens = try PresentationTokenResponse(presentationResponse: presentationResponseResult)
            return tokens;
        }
    }
//CHANGEEND
    
    /// Cancel the request with an optional message.
    func cancel(message: String?) async -> VerifiedIdResult<Void> {
        return VerifiedIdError(message: message ?? "User Canceled.", code: VerifiedIdErrors.ErrorCode.UserCanceled).result()
    }
}
