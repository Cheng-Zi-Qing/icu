import Foundation

func testPeekFrontLoopNeverTurnsTheHead() throws {
    let loop = PetPeekScript.frontLoop
    try expect(!loop.contains(where: \.isTurned), "the everyday loop should stay facing the user")
    try expect(loop.first == .rest && loop.last == .rest, "the quiet loop should start and end at front rest")
    try expect(!loop.contains(.birdFlyIn), "birds are reserved for the rare glance script")
    let rest = loop.filter { $0 == .rest }.count
    try expect(Double(rest) / Double(loop.count) >= 0.5, "mostly resting (got \(rest)/\(loop.count))")
}

func testPeekHeadTurnIsARareEasterEgg() throws {
    let loopSeconds = Double(PetPeekScript.frontLoop.count) / PetPeekScript.framesPerSecond
    let averageGap = loopSeconds / PetPeekScript.turnChancePerLoop
    try expect(averageGap >= 120, "on average the bird-search glance should happen at most every couple of minutes (got \(averageGap)s)")

    let glance = PetPeekScript.turnLoop
    let turnSeconds = Double(glance.count) / PetPeekScript.framesPerSecond
    try expect(turnSeconds >= 1.5 && turnSeconds <= 6, "a glance is short but readable (got \(turnSeconds)s)")
    try expect(!glance.contains(where: \.isTurned), "normal playback must never switch to the side silhouette")
    try expect(glance.first == .rest && glance.last == .rest, "glancing starts and settles at neutral")
    try expect(glance.contains(.lookLeft) && glance.contains(.lookRight), "scan both ways without turning the body")
    try expect(glance.contains(.blink), "blink between glances")
    let birds: [PetPeekFrame] = [.birdFlyIn, .birdFlyPast, .birdFlyOut]
    try expect(glance.filter { birds.contains($0) } == birds, "the bird flies in, past and out in order")
    // 先飞过去，再转头找：小鸟飞走以后才左右张望，第一下看向它飞走的那边（屏幕边）
    guard let gone = glance.firstIndex(of: .birdFlyOut) else { throw TestFailure(message: "the bird flies out") }
    try expect(!glance[..<gone].contains(.lookLeft) && !glance[..<gone].contains(.lookRight), "it only searches after the bird has gone")
    let afterBird = glance[(gone + 1)...].filter { $0 == .lookLeft || $0 == .lookRight }
    try expect(afterBird.first == .lookRight, "it first turns toward the edge the bird flew past")
    try expect(afterBird.contains(.lookLeft), "then looks the other way for it")
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
        "a winning roll at the end of a loop should play the frontal glance"
    )
    try expect(frames.last == PetPeekScript.frontLoop[0], "after the bird leaves it should return to neutral")
    try expect(!frames.contains(where: \.isTurned), "even a winning roll never uses the old turned frames")

    // Winning rolls before the boundary are ignored; equality at the threshold is not a win.
    var boundary = PetPeekPlayback.start
    for _ in 1..<PetPeekScript.frontLoop.count { boundary = boundary.advanced(roll: 0) }
    try expect(boundary.advanced(roll: PetPeekScript.turnChancePerLoop) == .start, "threshold equality stays in the quiet loop")
    try expect(boundary.advanced(roll: 0.999999) == .start, "the upper random boundary stays quiet")
    let winning = boundary.advanced(roll: PetPeekScript.turnChancePerLoop.nextDown)
    var finished = winning
    var glanced: [PetPeekFrame] = []
    for _ in PetPeekScript.turnLoop {
        glanced.append(finished.frame)
        finished = finished.advanced(roll: 0)
    }
    try expect(glanced == PetPeekScript.turnLoop, "a roll just below the threshold plays the complete glance")
    try expect(finished == .start, "the rare loop never immediately chains another rare loop")

    var quiet = PetPeekPlayback.start
    for index in 0..<(PetPeekScript.frontLoop.count * 3) {
        try expect(quiet.frame == PetPeekScript.frontLoop[index % PetPeekScript.frontLoop.count], "high rolls repeat complete quiet loops")
        quiet = quiet.advanced(roll: 0.999999)
    }
}

func testPeekFrameFileNames() throws {
    try expect(PetPeekFrame.rest.fileName == "peek_0.png", "front rest")
    try expect(PetPeekFrame.blink.fileName == "peek_1.png", "front blink")
    try expect(PetPeekFrame.reach.fileName == "peek_2.png", "front reach")
    try expect(PetPeekFrame.lookLeft.fileName == "look_left.png", "frontal left glance")
    try expect(PetPeekFrame.lookRight.fileName == "look_right.png", "frontal right glance")
    try expect(PetPeekFrame.birdFlyIn.fileName == "bird_0.png", "bird arrival")
    try expect(PetPeekFrame.birdFlyPast.fileName == "bird_1.png", "bird passes")
    try expect(PetPeekFrame.birdFlyOut.fileName == "bird_2.png", "bird departure")
    try expect(PetPeekFrame.turned.fileName == "turn_0.png", "head turned sideways")
    try expect(PetPeekFrame.turnedBlink.fileName == "turn_1.png", "head turned, blinking")
}

func testPeekFlinchIsATouchReactionNotPartOfTheLoops() throws {
    try expect(PetPeekFrame.flinch.fileName == "peek_3.png", "flinch frame file (got \(PetPeekFrame.flinch.fileName))")
    try expect(!PetPeekFrame.flinch.isTurned, "the flinch faces the user")
    let loops = PetPeekScript.frontLoop + PetPeekScript.turnLoop
    try expect(!loops.contains(.flinch), "the flinch only plays when the pet is touched")
}
