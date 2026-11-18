import XCTest
@testable import ChessCore

final class PerftTests: XCTestCase {
    private func perft(_ fen: String, _ depth: Int) -> Int {
        Position(fen: fen)!.perft(depth)
    }

    func testStartPosition() {
        XCTAssertEqual(perft(Position.startFEN, 1), 20)
        XCTAssertEqual(perft(Position.startFEN, 2), 400)
        XCTAssertEqual(perft(Position.startFEN, 3), 8902)
        XCTAssertEqual(perft(Position.startFEN, 4), 197281)
    }

    func testKiwipete() {
        XCTAssertEqual(perft("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", 3), 97862)
    }

    func testPosition3() {
        XCTAssertEqual(perft("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", 4), 43238)
    }

    func testPosition4() {
        XCTAssertEqual(perft("r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1", 3), 9467)
    }

    func testPosition5() {
        XCTAssertEqual(perft("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", 3), 62379)
    }

    func testFENRoundTrip() {
        let fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"
        XCTAssertEqual(Position(fen: fen)!.fen, fen)
    }

    func testSAN() {
        let p = Position.start
        XCTAssertEqual(p.san(Move(uci: "g1f3")!), "Nf3")
        XCTAssertEqual(p.sanLine(["e2e4", "e7e5", "g1f3", "b8c6", "f1b5"].compactMap(Move.init(uci:))), "1. e4 e5 2. Nf3 Nc6 3. Bb5")
        let mate = Position(fen: "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5Q2/PPPP1PPP/RNB1K1NR w KQkq - 4 4")!
        XCTAssertEqual(mate.san(Move(uci: "f3f7")!), "Qxf7#")
        XCTAssertTrue(mate.applying(Move(uci: "f3f7")!).isCheckmate)
        let dis = Position(fen: "4k3/8/8/8/8/8/8/R4RK1 w - - 0 1")!
        XCTAssertEqual(dis.san(Move(uci: "a1d1")!), "Rad1")
        XCTAssertEqual(Position(fen: "4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1")!.san(Move(uci: "e1g1")!), "O-O")
    }

    func testPuzzleDataParses() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../Resources/puzzles.csv")
        let text = try String(contentsOf: url, encoding: .utf8)
        var count = 0
        for line in text.split(separator: "\n") {
            let cols = line.split(separator: ",", omittingEmptySubsequences: false)
            guard var pos = Position(fen: String(cols[1])) else { return XCTFail("bad fen \(line)") }
            for uci in cols[2].split(separator: " ") {
                guard let m = Move(uci: String(uci)), pos.isLegal(m) else { return XCTFail("illegal \(uci) in \(line)") }
                pos = pos.applying(m)
            }
            count += 1
        }
        XCTAssertGreaterThan(count, 5000)
    }
}
