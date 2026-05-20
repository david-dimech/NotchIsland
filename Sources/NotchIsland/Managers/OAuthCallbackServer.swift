import Foundation
import Darwin

/// Minimal single-use loopback HTTP server for capturing the OAuth authorization code.
/// Binds on port 0 (OS picks a free port), accepts one connection, parses the code, responds.
final class OAuthCallbackServer {

    private(set) var port: Int = 0
    var onCode:  ((String) -> Void)?
    var onError: ((String) -> Void)?

    private var serverFD: Int32 = -1

    func start() {
        serverFD = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard serverFD >= 0 else { onError?("socket() failed"); return }

        var opt: Int32 = 1
        setsockopt(serverFD, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port   = 0                              // OS assigns free port
        addr.sin_addr   = in_addr(s_addr: INADDR_ANY)

        let bindResult: Int32 = withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(serverFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else { onError?("bind() failed"); return }
        Darwin.listen(serverFD, 1)

        // Retrieve the OS-assigned port
        var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(serverFD, $0, &addrLen)
            }
        }
        port = Int(CFSwapInt16BigToHost(addr.sin_port))

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in self?.acceptOne() }
    }

    func stop() {
        if serverFD >= 0 { Darwin.close(serverFD); serverFD = -1 }
    }

    // MARK: – Private

    private func acceptOne() {
        let clientFD = Darwin.accept(serverFD, nil, nil)
        Darwin.close(serverFD); serverFD = -1
        guard clientFD >= 0 else { return }
        defer { Darwin.close(clientFD) }

        var buf = [UInt8](repeating: 0, count: 8192)
        let n = Darwin.recv(clientFD, &buf, buf.count - 1, 0)
        guard n > 0 else { return }

        let request = String(bytes: buf.prefix(n), encoding: .utf8) ?? ""

        // Respond immediately so the browser shows a success page
        let html = """
            <html><head><meta charset="utf-8"></head>
            <body style="font-family:-apple-system;text-align:center;padding:60px">
            <h2 style="color:#1a73e8">✓ NotchIsland connected</h2>
            <p style="color:#5f6368">Authentication complete. You can close this tab.</p>
            </body></html>
            """
        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\n" +
                       "Content-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n\(html)"
        response.withCString { _ = Darwin.send(clientFD, $0, strlen($0), 0) }

        // Parse code= from query string: "GET /?code=XXXX&scope=..."
        if let range = request.range(of: "code=") {
            let tail = request[range.upperBound...]
            let code = String(tail.prefix { $0 != "&" && $0 != " " && $0 != "\r" && $0 != "\n" })
            if !code.isEmpty {
                DispatchQueue.main.async { [weak self] in self?.onCode?(code) }
                return
            }
        }
        DispatchQueue.main.async { [weak self] in self?.onError?("No code in callback") }
    }
}
