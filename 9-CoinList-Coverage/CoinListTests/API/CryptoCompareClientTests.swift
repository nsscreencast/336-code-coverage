//
//  CryptoCompareClientTests.swift
//  CoinListTests
//
//  Created by Ben Scheirman on 2/23/18.
//  Copyright © 2018 Fickle Bits, LLC. All rights reserved.
//

import XCTest
import OHHTTPStubs
@testable import CoinList

class CryptoCompareClientTests : XCTestCase {
    var client: CryptoCompareClient!
    
    override func setUp() {
        super.setUp()
        
        OHHTTPStubs.onStubMissing { request in
            XCTFail("Missing stub for \(request)")
        }
        
        FixtureLoader.stubCoinListResponse()
        
        client = CryptoCompareClient(session: URLSession.shared)
    }
    
    override func tearDown() {
        super.tearDown()
        FixtureLoader.reset()
    }
    
    func testFetchesCoinListResponse() {
        let exp = expectation(description: "Received response")
        client.fetchCoinList { result in
            exp.fulfill()
            switch result {
            case .success(let coinList):
                XCTAssertEqual(coinList.response, "Success")
            case .failure(let error):
                XCTFail("Error in coin list request: \(error)")
            }
        }
        waitForExpectations(timeout: 3.0, handler: nil)
    }
    
    func testCoinListResponseReturnsServerError() {
        FixtureLoader.stubCoinListReturningError()
        
        let exp = expectation(description: "Received response")
        client.fetchCoinList { result in
            exp.fulfill()
            switch result {
            case .success(_):
                XCTFail("Should have returned an error")
                
            case .failure(let error):
                
                if case ApiError.serverError(let status) = error {
                    XCTAssertEqual(status, 500)
                } else {
                    XCTFail("Expected a server error but got \(error)")
                }
            }
        }
        waitForExpectations(timeout: 3.0, handler: nil)
    }
    
    func testCallsBackOnMainQueue() {
        let exp = expectation(description: "Received response")
        client.fetchCoinList { result in
            exp.fulfill()
            XCTAssert(Thread.isMainThread, "Expected to be called back on the main queue")
        }
        waitForExpectations(timeout: 3.0, handler: nil)
    }
    
    func testCoinListRetrievesCoins() {
        let exp = expectation(description: "Received response")
        client.fetchCoinList { result in
            exp.fulfill()
            switch result {
            case .success(let coinList):
            
                XCTAssertGreaterThan(coinList.data.allCoins().count, 1)
                let coin = coinList.data["BTC"]
                XCTAssertNotNil(coin)
                XCTAssertEqual(coin?.symbol, "BTC")
                XCTAssertEqual(coin?.name, "Bitcoin")
                XCTAssertNotNil(coin?.imagePath)
                
            case .failure(let error):
                XCTFail("Error in coin list request: \(error)")
            }
        }
        waitForExpectations(timeout: 3.0, handler: nil)
    }
    
    func testConnectionErrorIsReturned() {
        FixtureLoader.stubCoinListWithConnectionError(code: 999)
        let exp = expectation(description: "Received response")
        client.fetchCoinList { result in
            exp.fulfill()
            switch result {
            case .success(_):
                XCTFail("Should have failed")
                
            case .failure(let error):
                switch error {
                case .connectionError(let e):
                    XCTAssertEqual( (e as NSError).code, 999)
                    
                default:
                    XCTFail("Expected connection error, but got: \(error)")
                }
            }
        }
        waitForExpectations(timeout: 3.0, handler: nil)
    }
    
    func testCatchesInvalidJSONOn200Response() {
        FixtureLoader.stubCoinListWithInvalidJSON()
        let exp = expectation(description: "Received response")
        client.fetchCoinList { result in
            exp.fulfill()
            switch result {
            case .success(_):
                XCTFail("Should have failed")
                
            case .failure(let error):
                switch error {
                case .responseFormatInvalid(let body):
                    XCTAssertEqual(body, "this is not valid json")
                    
                default:
                    XCTFail("Expected connection error, but got: \(error)")
                }
            }
        }
        waitForExpectations(timeout: 3.0, handler: nil)
    }
    
    func testCatchesInvalidJSONWithNoBody() {
        let invalidData = Data(bytes: [UInt8.max])
        FixtureLoader.stubCoinListWithData(invalidData)
        let exp = expectation(description: "Received response")
        client.fetchCoinList { result in
            exp.fulfill()
            switch result {
            case .success(_):
                XCTFail("Should have failed")
                
            case .failure(let error):
                switch error {
                case .responseFormatInvalid(let body):
                    XCTAssertEqual(body, "<no body>")
                    
                default:
                    XCTFail("Expected connection error, but got: \(error)")
                }
            }
        }
        waitForExpectations(timeout: 3.0, handler: nil)
    }
}
