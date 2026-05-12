//
//  ContentView.swift
//  pomodoro
//
//  Created by Jinsong Li on 2026-05-11.
//

import SwiftUI
import AppKit

@MainActor
final class PomodoroTimer: ObservableObject {
    @Published var totalSeconds: Int = 25 * 60
    @Published var remainingSeconds: Int = 25 * 60
    @Published var isRunning: Bool = false
    @Published var isEditing: Bool = false
    @Published var inputBuffer: String = ""

    private var ticker: Timer?

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(remainingSeconds) / Double(totalSeconds)
    }

    var displayText: String {
        if isEditing {
            let (m, s) = parsedInput
            return String(format: "%02d:%02d", m, s)
        }
        return String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }

    private var parsedInput: (mins: Int, secs: Int) {
        let buf = inputBuffer
        if buf.isEmpty { return (0, 0) }
        if buf.count <= 2 { return (0, Int(buf) ?? 0) }
        let cut = buf.index(buf.endIndex, offsetBy: -2)
        return (Int(buf[..<cut]) ?? 0, Int(buf[cut...]) ?? 0)
    }

    func toggle() {
        if isEditing { return }
        isRunning ? pause() : start()
    }

    func start() {
        guard remainingSeconds > 0, !isRunning else { return }
        isRunning = true
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func pause() {
        isRunning = false
        ticker?.invalidate()
        ticker = nil
    }

    func reset() {
        pause()
        isEditing = false
        inputBuffer = ""
        remainingSeconds = totalSeconds
    }

    func appendDigit(_ ch: Character) {
        if !isEditing {
            pause()
            isEditing = true
            inputBuffer = ""
        }
        guard inputBuffer.count < 5 else { return }
        inputBuffer.append(ch)
    }

    func backspace() {
        guard isEditing, !inputBuffer.isEmpty else { return }
        inputBuffer.removeLast()
    }

    func commitInput() {
        guard isEditing else { return }
        let (m, s) = parsedInput
        let total = m * 60 + s
        let shouldStart = total > 0
        if shouldStart {
            totalSeconds = total
            remainingSeconds = total
        }
        isEditing = false
        inputBuffer = ""
        if shouldStart { start() }
    }

    func cancelInput() {
        isEditing = false
        inputBuffer = ""
    }

    private func tick() {
        guard remainingSeconds > 0 else {
            pause()
            NSSound.beep()
            return
        }
        remainingSeconds -= 1
        if remainingSeconds == 0 {
            pause()
            NSSound.beep()
        }
    }
}

struct ContentView: View {
    @StateObject private var timer = PomodoroTimer()
    @FocusState private var focused: Bool

    private let size: CGFloat = 165

    var body: some View {
        ZStack {
            Circle()
                .fill(background)

            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 6)
                .padding(8)

            Circle()
                .trim(from: 0, to: timer.progress)
                .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(8)
                .animation(.linear(duration: 0.2), value: timer.progress)

            Text(timer.displayText)
                .font(.system(size: 33, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .opacity(timer.isEditing ? 0.7 : 1)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onAppear { focused = true }
        .onKeyPress(.space) {
            timer.toggle()
            return .handled
        }
        .onKeyPress(.return) {
            timer.commitInput()
            return .handled
        }
        .onKeyPress(.escape) {
            timer.cancelInput()
            return .handled
        }
        .onKeyPress(.delete) {
            timer.backspace()
            return .handled
        }
        .onKeyPress { press in
            if let ch = press.characters.first {
                if ch.isNumber {
                    timer.appendDigit(ch)
                    return .handled
                }
                if ch == "r" || ch == "R" {
                    timer.reset()
                    return .handled
                }
            }
            return .ignored
        }
    }

    private var background: Color {
        let base: Color
        if timer.isEditing {
            base = Color(red: 0.45, green: 0.55, blue: 0.80)
        } else if timer.remainingSeconds == 0 {
            base = Color(red: 0.65, green: 0.65, blue: 0.65)
        } else if timer.isRunning {
            base = Color(red: 1.00, green: 0.72, blue: 0.78)
        } else {
            base = Color(red: 0.45, green: 0.45, blue: 0.50)
        }
        return base.opacity(0.70)
    }
}

#Preview {
    ContentView()
}
