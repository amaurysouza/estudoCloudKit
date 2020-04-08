//
//  CloudKitHelper.swift
//  SwiftUICloudKitDemo
//
//  Created by Alex Nagy on 23/09/2019.
//  Copyright © 2019 Alex Nagy. All rights reserved.
//

import Foundation
import CloudKit
import SwiftUI

// MARK: - notes
// good to read: https://www.hackingwithswift.com/read/33/overview
//
// important setup in CloudKit Dashboard:
//
// https://www.hackingwithswift.com/read/33/4/writing-to-icloud-with-cloudkit-ckrecord-and-ckasset
// https://www.hackingwithswift.com/read/33/5/a-hands-on-guide-to-the-cloudkit-dashboard
//
// On your device (or in the simulator) you should make sure you are logged into iCloud and have iCloud Drive enabled.

struct CloudKitHelper {
    
    // Declaração de tipos de recrods
    struct RecordType {
        static let Items = "Items"
    }
    
    // MARK: - errors
    enum CloudKitHelperError: Error {
        case recordFailure
        case recordIDFailure
        case castFailure
        case cursorFailure
    }
    
    // Função de salvar do CloudKit
    static func save(item: ListElement, completion: @escaping (Result<ListElement, Error>) -> ()) {
        //criação de um item do tipo CkRecord que é do tipo RecordType.Items que a gente criou lá em cima
        let itemRecord = CKRecord(recordType: RecordType.Items)
        //cast do texto do itemRecord como um CKRecordValue pra poder salvar no  cloudkit - esse text é o que tá lá na dashboard do CloudKit
        itemRecord["text"] = item.text as CKRecordValue
        //chamado da operação de salvar em si em uma publicCloudDatabase salvando o nosso itemRecord
        CKContainer.default().publicCloudDatabase.save(itemRecord) { (record, err) in
            //na main thread como sempre
            DispatchQueue.main.async {
                if let err = err {
                    completion(.failure(err))
                    return
                }
                guard let record = record else {
                    completion(.failure(CloudKitHelperError.recordFailure))
                    return
                }
                //dando um id pro record
                let recordID = record.recordID
                guard let text = record["text"] as? String else {
                    completion(.failure(CloudKitHelperError.castFailure))
                    return
                }
                let listElement = ListElement(recordID: recordID, text: text)
                completion(.success(listElement))
            }
        }
    }
    
    // MARK: - fetching from CloudKit
    static func fetch(completion: @escaping (Result<ListElement, Error>) -> ()) {
        //cria um predicate e um sort, o primeiro pra dar pra query como parâmetro, o segundo pra usar nela como sort descriptor
        let pred = NSPredicate(value: true)
        let sort = NSSortDescriptor(key: "creationDate", ascending: false)
        let query = CKQuery(recordType: RecordType.Items, predicate: pred)
        query.sortDescriptors = [sort]

        //criar uma operação com a query que criamos (que redundante!)
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = ["text"]
        operation.resultsLimit = 50
        
       //tratar a lista retornada com a operação
        operation.recordFetchedBlock = { record in
            DispatchQueue.main.async {
                let recordID = record.recordID
                guard let text = record["text"] as? String else { return }
                let listElement = ListElement(recordID: recordID, text: text)
                completion(.success(listElement))
            }
        }
         //tratar erros
        operation.queryCompletionBlock = { (/*cursor*/ _, err) in
            DispatchQueue.main.async {
                if let err = err {
                    completion(.failure(err))
                    return
                }

            }
            
        }
        //fazer a query de fato
        CKContainer.default().publicCloudDatabase.add(operation)
    }
    
    // MARK: - delete from CloudKit
    static func delete(recordID: CKRecord.ID, completion: @escaping (Result<CKRecord.ID, Error>) -> ()) {
        //a essa altura parece tudo meio parecido, trata o erro, faz na main, manda a completion pra alterar
        CKContainer.default().publicCloudDatabase.delete(withRecordID: recordID) { (recordID, err) in
            DispatchQueue.main.async {
                if let err = err {
                    completion(.failure(err))
                    return
                }
                guard let recordID = recordID else {
                    completion(.failure(CloudKitHelperError.recordIDFailure))
                    return
                }
                completion(.success(recordID))
            }
        }
    }
    
    // MARK: - modify in CloudKit
    static func modify(item: ListElement, completion: @escaping (Result<ListElement, Error>) -> ()) {
        //ele tá basicamente juntando o fetch e o save
        guard let recordID = item.recordID else { return }
        CKContainer.default().publicCloudDatabase.fetch(withRecordID: recordID) { record, err in
            if let err = err {
                DispatchQueue.main.async {
                    completion(.failure(err))
                }
                return
            }
            guard let record = record else {
                DispatchQueue.main.async {
                    completion(.failure(CloudKitHelperError.recordFailure))
                }
                return
            }
            record["text"] = item.text as CKRecordValue

            CKContainer.default().publicCloudDatabase.save(record) { (record, err) in
                DispatchQueue.main.async {
                    if let err = err {
                        completion(.failure(err))
                        return
                    }
                    guard let record = record else {
                        completion(.failure(CloudKitHelperError.recordFailure))
                        return
                    }
                    let recordID = record.recordID
                    guard let text = record["text"] as? String else {
                        completion(.failure(CloudKitHelperError.castFailure))
                        return
                    }
                    let listElement = ListElement(recordID: recordID, text: text)
                    completion(.success(listElement))
                }
            }
        }
    }
}
