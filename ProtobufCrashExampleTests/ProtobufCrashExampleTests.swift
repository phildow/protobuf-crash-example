//
//  ProtobufCrashExampleTests.swift
//  ProtobufCrashExampleTests
//
//  Created by Phil Dow on 6/12/20.
//  Copyright © 2020 doc.ai. All rights reserved.
//

import XCTest
import TensorIO

@testable import ProtobufCrashExample

class ProtobufCrashExampleTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        let _ = TIOBatch(keys: ["foo"])
        let _ = LocalClass()
    }

}
