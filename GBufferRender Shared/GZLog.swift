/// Copyright (c) 2022 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import Foundation

#if DEBUG
let GZLOG_FLAG = true
#else
let GZLOG_FLAG = false
#endif

private class GZLogUtil {

    static var formatter: DateFormatter = {
        let format = DateFormatter()
        format.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return format
    }()
    
    class func notNilObj(_ obj: Any?) -> Any {
        if let a: Any = obj {
            return a
        }
        return "nil"
    }
}

private func fileNameOfFile(_ file: String) -> String {
    let fileParts = file.components(separatedBy: "/")
    if let lastPart = fileParts.last {
        return lastPart
    }
    return ""
}

func GZLogFunc(_ message: @autoclosure () -> Any? = "", function: String = #function, file: String = #file, line: Int = #line) -> Void {
    if GZLOG_FLAG == false {
        return
    }
    NSLog("\(GZLogUtil.formatter.string(from: Date())) [\(fileNameOfFile(file)) \(function)](\(line)) \(GZLogUtil.notNilObj(message()))")
}
