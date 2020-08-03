//
//  MultipartRequestHandler.swift
//  www.pausanchezv.com
//
//  Created by Pau Sanchez on 05/07/2020.
//  Copyright © 2020 pausanchezv.com. All rights reserved.
//

import UIKit

///
/// ## Class MultipartRequestHandler
///
/// ## Understanding what a multipart request actually looks like
///
/// The headers of your post requests contained the following key amongst several others:
/// ```
/// Content-Type: multipart/form-data; boundary=3A42CBDB-01A2-4DDE-A9EE-425A344ABA13
/// ```
///
/// The body of the post request typically looks a little bit like like the following:
/// ```
/// --Boundary-3A42CBDB-01A2-4DDE-A9EE-425A344ABA13
/// Content-Disposition: form-data; name="name"
///
/// Pau
/// --Boundary-3A42CBDB-01A2-4DDE-A9EE-425A344ABA13
/// Content-Disposition: form-data; name="lastname"
///
/// Sanchez
/// --Boundary-3A42CBDB-01A2-4DDE-A9EE-425A344ABA13
/// Content-Disposition: form-data; name="file"; filename="pau.jpg"
/// Content-Type: image/png
///
/// -a long string of image data-
/// --Boundary-3A42CBDB-01A2-4DDE-A9EE-425A344ABA13—
/// ```
///
/// First, there’s the Content-Type header. It contains information about the type of data we sending (multipart/form-data;) and a boundary. This boundary should always have a unique, somewhat random value. In the example above I used a UUID. Since multipart forms are not always sent to the server all at once but rather in chunks, the server needs some way to know when a certain part of the form we are sending it ends or begins. This is what the boundary value is used for. This must be communicated in the headers since that’s the first thing the receiving server will be able to read. Next, let’s look at the http body. It starts with the following block of text:
///
/// ```
/// --Boundary-3A42CBDB-01A2-4DDE-A9EE-425A344ABA13
/// Content-Disposition: form-data; name="family_name"
///
/// Pau
/// ```
///
/// We send two dashes (--) followed by the predefined boundary string (Boundary-3A42CBDB-01A2-4DDE-A9EE-425A344ABA13) to inform the server that it’s about to read a new chunk of content. In this case a form field. The server knows that it’s receiving a form field thanks to the first bit of the next line: Content-Disposition: form-data;. It also knows that the form field it’s about to receive is named family-name due to the second part of the Content-Disposition line: name="name". This is followed by a blank line and the value of the form field we want to send the server.

/// This pattern is repeated for the other form field in the example body:
///
/// ```
/// --Boundary-3A42CBDB-01A2-4DDE-A9EE-425A344ABA13
/// Content-Disposition: form-data; name="lastname"
///
/// Sanchez
/// ```
///
/// The third field in the example is slightly different. It’s Content-Disposition looks like this:
///
/// ```
/// Content-Disposition: form-data; name="file"; filename="pau.jpg"
/// ```
///
/// It has an extra field called filename. This tells the server that it can refer to the uploaded file using that name once the upload succeeded. This last chunk for the file itself also has its own Content-Type field. This tells the server about the uploaded file’s Mime Type. In this example, it’s image/png because we’re uploading an imaginary png image.

/// After that, we should see another empty line and then a whole lot of cryptic data. That’s the raw image data. And after all of this data, we'll find the last line of the HTTP body:
///
/// ```
/// --Boundary-E82EE6C1-377D-486C-AFE1-C0CE9A03E9A3--
/// ```
///
/// It’s one last boundary, suffixed with --. This tells the server that it has now received all of the HTTP data that we wanted to send it. Every form field essentially has the same structure:
///
/// ```
/// BOUNDARY
/// CONTENT TYPE
/// -- BLANK LINE --
/// VALUE
/// ```
///
/// Once we understand this structure, the HTTP body of a multipart request should look a lot less daunting, and implementing our own multipart uploader with URLSession shouldn’t sound as scary as it seems. This is the library that Pau Sanchez implemented in order to handle multipart URLRequest that can be executed by URLSession!
///
/// - Version: 2.0
/// - Author: Pau Sanchez - Computer Engineer
/// - Date: 05/07/2020
/// - Copyright: www.pausanchezv.com
///
open class MultipartRequestHandler: NSObject {
    
    ///
    /// ## serverUrl
    ///
    /// The server url where the call is made
    ///
    /// - Version: 2.0
    /// - Author: Pau Sanchez - Computer Engineer
    /// - Date: 05/07/2020
    /// - Copyright: www.pausanchezv.com
    ///
    private(set) var serverUrl: String
    
    ///
    /// ## MultipartRequestHandler Constructor
    ///
    /// Used to get an instance
    ///
    /// - Version: 2.0
    /// - Author: Pau Sanchez - Computer Engineer
    /// - Date: 05/07/2020
    /// - Copyright: www.pausanchezv.com
    ///
    public init(serverUrl: String) {
        self.serverUrl = serverUrl
    }
    
    ///
    /// ## getMultipartRequest
    ///
    /// Returns a multipart request with both a file attached to it and the desired form fields
    ///
    /// - Version: 2.0
    /// - Author: Pau Sanchez - Computer Engineer
    /// - Date: 05/07/2020
    /// - Copyright: www.pausanchezv.com
    ///
    public func getMultipartRequest(filePath: URL, formFields: [String: String], fileKey: String) -> URLRequest {
        
        // Getting the file extension
        let fileExtension = self.getFileExtension(from: String(describing: filePath))
        
        // Getting the mime-type depending on the extension of the file
        let mimeType = self.getMimeType(from: fileExtension)

        // Defining the boundary
        let boundary = "Boundary-\(UUID().uuidString)"
        
        // Defining the post request and setting the desired headers
        let url = URL(string: self.serverUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(ONController.instance.authSessionToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = Constants.REQUEST_TIMEOUT
        
        // Creating the body of the request
        let httpBody = NSMutableData()
        
        // Adding the form fields to the body
        for (key, value) in formFields {
            let field = self.convertFormField(named: key, value: value, using: boundary)
            httpBody.appendString(field)
        }
        
        // Defining the filedata abd getting it from the path of the file we want to attach
        var fileData: Data?
        
        do {
            fileData = try Data(contentsOf: filePath)
        } catch {
            ONController.instance.loggingAppErrors(with: "Could not get the data - \(String(describing: error)).", from: #function)
        }
        
        // Converting into chunks of data
        let file = self.convertFileData(
            fieldName: fileKey,
            fileName: String(describing: filePath),
            mimeType: mimeType,
            fileData: fileData ?? Data(),
            using: boundary
        )
            
        // Adding the attachment to the body
        httpBody.append(file)
        
        // Closing the boundary
        httpBody.appendString("--\(boundary)--")
        
        // Adding body as data
        request.httpBody = httpBody as Data
        
        return request
    }
    
    ///
    /// ## convertFormField
    ///
    /// The code of this method should pretty much speak for itself. We construct a String that has all the discussed elements in the Class definition. Note the \r\n that is added to the string after every line. This is needed to add a new line to the string so we get the output that we want.
    ///
    /// - Version: 2.0
    /// - Author: Pau Sanchez - Computer Engineer
    /// - Date: 05/07/2020
    /// - Copyright: www.pausanchezv.com
    ///
    private func convertFormField(named name: String, value: String, using boundary: String) -> String {
        var fieldString = "--\(boundary)\r\n"
        fieldString += "Content-Disposition: form-data; name=\"\(name)\"\r\n"
        fieldString += "\r\n"
        fieldString += "\(value)\r\n"

        return fieldString
    }
    
    ///
    /// ## convertFileData
    ///
    /// While the previous method is pretty neat for the form fields that contain text, we need a separate method to create the chunk for file data since it works slightly different from the rest. This is mainly because we need to specify the content type for our file, and we have file data as the value rather than a String. The following code can be used to create a body chunk for the file.
    /// Instead of a String, we create Data this time. The reason for this is twofold. One is that we already have the file data. Converting this to a String and then back to Data when we add it to the HTTP body is wasteful. The second reason is that the HTTP body itself must be created as Data rather than a String. To make appending text to the Data object, we add an extension on NSMutableData that safely appends the given string as Data. From the structure of the method, we should be able to derive that it matches the HTTP body that was discussed earlier.
    ///
    /// - Version: 2.0
    /// - Author: Pau Sanchez - Computer Engineer
    /// - Date: 05/07/2020
    /// - Copyright: www.pausanchezv.com
    ///
    private func convertFileData(fieldName: String, fileName: String, mimeType: String, fileData: Data, using boundary: String) -> Data {
        let data = NSMutableData()

        data.appendString("--\(boundary)\r\n")
        data.appendString("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n")
        data.appendString("Content-Type: \(mimeType)\r\n\r\n")
        data.append(fileData)
        data.appendString("\r\n")

        return data as Data
    }
    
    ///
    /// ## getFileExtension
    ///
    /// Obtains the extension of the file
    ///
    /// - Version: 2.0
    /// - Author: Pau Sanchez - Computer Engineer
    /// - Date: 05/07/2020
    /// - Copyright: www.pausanchezv.com
    ///
    private func getFileExtension(from file: String) -> String {
        return String(file.split(separator: ".").last ?? "")
    }
    
    ///
    /// ## getMimeType
    ///
    /// Obtains the mime-type depending n the extension
    ///
    /// - Version: 2.0
    /// - Author: Pau Sanchez - Computer Engineer
    /// - Date: 05/07/2020
    /// - Copyright: www.pausanchezv.com
    ///
    private func getMimeType(from fileExtension: String) -> String {
        
        switch fileExtension.lowercased() {
            
            case "jpg", "jpeg":
                return "image/jpeg"
            
            case "png":
                return "image/png"
            
            case "pdf":
                return "application/pdf"
            
            case "gif":
                return "image/gif"
            
            case "bmp":
                return "image/bmp"
            
            case "doc":
                return "application/msword"
            
            case "docx":
                return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            
            case "odt":
                return "application/vnd.oasis.opendocument.text"
            
            case "rtf":
                return "application/rtf"
            
            default:
                return ""
        }
    }
}

///
/// ## Extension NSMutableData
///
/// NSMutableData Additional functionality
///
/// - Version: 2.0
/// - Author: Pau Sanchez - Computer Engineer
/// - Date: 05/07/2020
/// - Copyright: www.pausanchezv.com
///
extension NSMutableData {
    func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            self.append(data)
        }
    }
}
