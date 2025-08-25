//
//  NetworkManager+GigaChat.swift
//  tourar
//
//  Created by Артем Стратиенко on 16.06.2024.
//

import Foundation
import UIKit

var lastGenerateMessage = ""
let RgUID = "07f0892f-403d-410b-b4e4-516c50e21e10"
let authBasic = "MDdmMDg5MmYtNDAzZC00MTBiLWI0ZTQtNTE2YzUwZTIxZTEwOjhkMzYyNDc0LTQ2ZjgtNGYzMy1hMzcxLTk0NTI0YTU1NDVlZg=="
var lastGeneratedImagePrompt = "" // Переменная для отслеживания последнего использованного промта

extension TouchViewController
{
    func getTokenToGigaChat(requestString : String )
    {
        let url = URL(string: "https://ngw.devices.sberbank.ru:9443/api/v2/oauth")!
        let payload = "scope=GIGACHAT_API_PERS"
        let headers: [String: String] = [
            "Content-Type": "application/x-www-form-urlencoded",
            "Accept": "application/json",
            "RqUID": "\(RgUID)",
            "Authorization": "Basic \(authBasic)"
        ]

        var request = URLRequest(url: url)
        request.httpBody = payload.data(using: .utf8)
        request.allHTTPHeaderFields = headers
        request.httpMethod = "POST"

        let session = URLSession.shared
        session.dataTask(with: request) { (data, response, error) in
            guard let data = data else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] {
                    let token = json["access_token"] as? String
                    if ( token != nil ) {
                        if ( self.prompCheckerGiga(promt: requestString, word: "маршрут") &&
                             ( self.prompCheckerGiga(promt: requestString, word: "построить") ||
                               self.prompCheckerGiga(promt: requestString, word: "построй")   ||
                               self.prompCheckerGiga(promt: requestString, word: "Построй")
                             ) )
                        {
                            // вычленяем адресс точки маршрута
                            // либо передаем в геокодер
                            var prefixPromt = "В ответе верни только адресс в формате -  Address:"
                            self.sendPostRequestToChat(tokenGiga: token!, textToGiga: requestString + prefixPromt)
                        }
                        else if ( self.prompCheckerGiga(promt: requestString, word: "маршрут") &&
                                  ( self.prompCheckerGiga(promt: requestString, word: "сбросить") ||
                                    self.prompCheckerGiga(promt: requestString, word: "Сбрось") ||
                                    self.prompCheckerGiga(promt: requestString, word: "Отмени") ||
                                    self.prompCheckerGiga(promt: requestString, word: "отменить")
                                  ) )
                        {
                            DispatchQueue.main.async {
                                self.resetRoute()
                            }
                        }
                        else if ( ( self.prompCheckerGiga(promt: requestString, word: "Режим") ||
                                    self.prompCheckerGiga(promt: requestString, word: "режим") )  &&
                                  ( self.prompCheckerGiga(promt: requestString, word: "смени") ||
                                    self.prompCheckerGiga(promt: requestString, word: "Переключить") ||
                                    self.prompCheckerGiga(promt: requestString, word: "Поменяй")    ||
                                    self.prompCheckerGiga(promt: requestString, word: "переключи")
                                  )
                                )
                        {
                            // Запускаем AR режим и наоборот
                            DispatchQueue.main.async {
                                self.toggleARMode()
                            }
                        }
                        else if ( self.prompCheckerGiga(promt: requestString, word: "геолокации") &&
                             ( self.prompCheckerGiga(promt: requestString, word: "места")        ||
                               self.prompCheckerGiga(promt: requestString, word: "культурные")   ||
                               self.prompCheckerGiga(promt: requestString, word: "центры")       ||
                               self.prompCheckerGiga(promt: requestString, word: "культурный")   ||
                               self.prompCheckerGiga(promt: requestString, word: "центр")       ||
                               self.prompCheckerGiga(promt: requestString, word: "развлекательные")
                             ) )
                        {
                            // вычленяем адресс точки маршрута
                            // либо передаем в геокодер
                            var suffixPromt = "Вот моя геопозиция : \(self.userLocation!.latitude),\(self.userLocation!.longitude) + Электросталь"
                            var prefixPromt = "В ответе укажи только название обьекта и улицу! Больше ничего не нужно возвращать"
                            self.sendPostRequestToChat(tokenGiga: token!, textToGiga: requestString + suffixPromt + prefixPromt)
                        }
                        else if ( self.prompCheckerGiga(promt: requestString, word: "отобразить") &&
                             ( self.prompCheckerGiga(promt: requestString, word: "фотографии") ||
                               self.prompCheckerGiga(promt: requestString, word: "фотографию") 
                             ) )
                        {
                            var suffixPromt = "В ответе верни изображение и краткий исторический факт!"
                            self.sendPostRequestToChat(tokenGiga: token!, textToGiga: requestString.replacingOccurrences(of: "отобразить:", with: "нарисовать") + suffixPromt)
                        }
                        else
                        {
                            self.sendPostRequestToChat(tokenGiga: token!, textToGiga: requestString)
                        }
                    }
                }
            } catch let parseError {
                print("Error serializing json: \(parseError)")
            }
        }.resume()
    }
    func sendPostRequestToChat( tokenGiga : String, textToGiga : String )
    {
        let url = URL(string: "https://gigachat.devices.sberbank.ru/api/v1/chat/completions")!
        let payload = ["model": "GigaChat", "messages": [["role": "user", "content": "\(textToGiga)"]], "temperature": 1, "top_p": 0.1, "n": 1, "stream": false, "max_tokens": 512, "repetition_penalty": 1,"function_call": "auto"] as [String : Any]

        var request = URLRequest(url: url)
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(tokenGiga)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "POST"

        let session = URLSession.shared
        session.dataTask(with: request) { (data, response, error) in
            guard let data = data else { return }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String: Any]
                print(json)
                let responGiga = json["choices"] as? [[String : Any]]
                if ( responGiga != nil )
                {
                    for itemRespoGiga in responGiga!
                    {
                        let messageArray = itemRespoGiga["message"] as? [String:Any]
                        if ( messageArray != nil )
                        {
                            let contentResponse = messageArray!["content"] as? String
                            
                            if ( contentResponse != nil )
                            {
                                if ( self.prompCheckerGiga(promt: contentResponse!, word: "Address:") )
                                {
                                    // вычленяем адресс точки маршрута
                                    // либо передаем в геокодер
                                    DispatchQueue.main.async {
                                        self.resetRoute()
                                    }
                                    self.geocodeAddressString(contentResponse!.replacingOccurrences(of: "Address:", with: ""))
                                }
                                else
                                {
                                    // Вызов общих промтов к чату
                                    if ( contentResponse!.contains("<img") )
                                    {
                                        let parsed = self.parseContent(contentResponse!)
                                        if let text = parsed.description {
                                            if ( lastGenerateMessage != text)
                                            {
                                                self.words = text.components(separatedBy: " ")
                                                self.voiceHelperUI(textSpeech: "\(text)")
                                                lastGenerateMessage = text
                                            }
                                        }
                                        if let id_image = parsed.imgId {
                                            self.downloadImageWithID(id_image, token: tokenGiga) { image in
                                                DispatchQueue.main.async {
                                                    if let image = image {
                                                        self.lastGeneratedImage = image
                                                    } else {
                                                        self.voiceHelperUI(textSpeech: "Не удалось загрузить изображение")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    else
                                    {
                                        if ( lastGenerateMessage != contentResponse!)
                                        {
                                            self.words = contentResponse!.components(separatedBy: " ")
                                            self.voiceHelperUI(textSpeech: "\(contentResponse!)")
                                            lastGenerateMessage = contentResponse!
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } catch let parseError {
                print("Error serializing json: \(parseError)")
            }
        }.resume()
    }
    
    func parseContent(_ content: String) -> (imgId: String?, description: String?)
    {
        var img_id: String?
        if let imgRange = content.range(of: #"src="([^"]+)""#, options: .regularExpression) {
            let srcPart = String(content[imgRange])
            img_id = srcPart.replacingOccurrences(of: #"src=""#, with: "")
                .replacingOccurrences(of: #"""#, with: "")
        }
        var desc: String?
        if let textRange = content.range(of: #"/>(.*)"#, options: .regularExpression) {
            desc = String(content[textRange])
                .replacingOccurrences(of: #"/>"#, with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: #"^- "#, with: "", options: .regularExpression)
        }
            return (img_id, desc)
    }
    func downloadImageWithID(_ imageID: String, token: String, completion: @escaping (UIImage?) -> Void) {
        let urlString = "https://gigachat.devices.sberbank.ru/api/v1/files/\(imageID)/content"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/jpg", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let session = URLSession.shared
        session.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error downloading image: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }

            // Проверяем Content-Type
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               httpResponse.mimeType == "image/jpeg" || httpResponse.mimeType == "image/jpg" {
                DispatchQueue.main.async {
                    completion(UIImage(data: data))
                }
            } else {
                completion(nil)
            }
        }.resume()
    }
    func prompCheckerGiga(promt : String, word : String ) -> Bool
    {
        var isCheck = false
        if ( promt.contains(word) )
        {
            isCheck = true
        }
        return isCheck
    }
}
