import Foundation

func testPeekFrontLoopNeverTurnsTheHead() throws {
    let loop = PetPeekScript.frontLoop
    try expect(!loop.contains(where: \.isTurned), "the everyday loop should stay facing the user")
    try expect(loop.first == .rest, "the loop should start from the front rest frame")
    let rest = loop.filter { $0 == .rest }.count
    try expect(Double(rest) / Double(loop.count) >= 0.5, "mostly resting (got \(rest)/\(loop.count))")
}

func testPeekHeadTurnIsARareEasterEgg() throws {
    let loopSeconds = Double(PetPeekScript.frontLoop.count) / PetPeekScript.framesPerSecond
    let averageGap = loopSeconds / PetPeekScript.turnChancePerLoop
    try expect(averageGap >= 120, "on average the head should turn at most every couple of minutes (got \(averageGap)s)")

    let turnSeconds = Double(PetPeekScript.turnLoop.count) / PetPeekScript.framesPerSecond
    try expect(turnSeconds >= 1.5, "a head turn should last long enough to notice (got \(turnSeconds)s)")
    try expect(PetPeekScript.turnLoop.allSatisfy(\.isTurned), "the head stays turned for the whole turn")
    try expect(PetPeekScript.turnLoop.contains(.turnedBlink), "it should blink while the head is turned")
}

func testPeekPlaybackTurnsOnlyWhenTheRollHitsAtTheEndOfALoop() throws {
    let never = (0..<(PetPeekScript.frontLoop.count * 5)).reduce(PetPeekPlayback.start) { playback, _ in
        playback.advanced(roll: 0.999)
    }
    try expect(!never.frame.isTurned, "a high roll should keep it facing the user")

    var playback = PetPeekPlayback.start
    var frames: [PetPeekFrame] = [playback.frame]
    for _ in 0..<(PetPeekScript.frontLoop.count + PetPeekScript.turnLoop.count) {
        playback = playback.advanced(roll: 0)
        frames.append(playback.frame)
    }
    try expect(
        Array(frames.prefix(PetPeekScript.frontLoop.count)) == PetPeekScript.frontLoop,
        "the first loop always plays facing the user, even with a winning roll"
    )
    try expect(
        Array(frames.dropFirst(PetPeekScript.frontLoop.count).prefix(PetPeekScript.turnLoop.count)) == PetPeekScript.turnLoop,
        "a winning roll at the end of a loop should play the head turn"
    )
    try expect(frames.last == PetPeekScript.frontLoop[0], "after the turn it should face the user again")
}

func testPeekFrameFileNames() throws {
    try expect(PetPeekFrame.rest.fileName == "peek_0.png", "front rest")
    try expect(PetPeekFrame.blink.fileName == "peek_1.png", "front blink")
    try expect(PetPeekFrame.reach.fileName == "peek_2.png", "front reach")
    try expect(PetPeekFrame.turned.fileName == "turn_0.png", "head turned sideways")
    try expect(PetPeekFrame.turnedBlink.fileName == "turn_1.png", "head turned, blinking")
}

func testPeekFlinchIsATouchReactionNotPartOfTheLoops() throws {
    try expect(PetPeekFrame.flinch.fileName == "peek_3.png", "flinch frame file (got \(PetPeekFrame.flinch.fileName))")
    try expect(!PetPeekFrame.flinch.isTurned, "the flinch faces the user")
    let loops = PetPeekScript.frontLoop + PetPeekScript.turnLoop
    try expect(!loops.contains(.flinch), "the flinch only plays when the pet is touched")
}
