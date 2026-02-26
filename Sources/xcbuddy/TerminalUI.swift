import Foundation

/// A utility for rendering structured, interactive terminal UI components.
public struct TerminalUI {
    
    // MARK: - ANSI Escape Codes
    private static let escape = "\u{001B}["
    private static let reset = "\(escape)0m"
    private static let bold = "\(escape)1m"
    private static let dim = "\(escape)2m"
    
    // Common Colors
    private static let red = "\(escape)31m"
    private static let green = "\(escape)32m"
    private static let yellow = "\(escape)33m"
    private static let blue = "\(escape)34m"
    private static let magenta = "\(escape)35m"
    private static let cyan = "\(escape)36m"
    
    // Clear Commands
    private static let clearLine = "\(escape)2K"
    private static let moveUp = "\(escape)1A"
    
    // MARK: - API
    
    /// Prints a sticky header representing the current active context.
    public static func printHeader(project: ProjectContext) {
        let width = 80
        
        let logoLines = [
            "██   ██  ██████ ██████  ██   ██ ██████  ██████  ██    ██",
            " ██ ██  ██      ██   ██ ██   ██ ██   ██ ██   ██  ██  ██ ",
            "  ███   ██      ██████  ██   ██ ██   ██ ██   ██   ████  ",
            " ██ ██  ██      ██   ██ ██   ██ ██   ██ ██   ██    ██   ",
            "██   ██  ██████ ██████   ██████ ██████  ██████     ██   "
        ]
        
        // --- 1. Top Border ---
        let title = " xcbuddy-1.0.0 "
        let leftDashesCount = 5
        let rightDashesCount = width - 2 - leftDashesCount - title.count // 2 for corners
        let topBorder = "┌" + String(repeating: "─", count: leftDashesCount) + title + String(repeating: "─", count: rightDashesCount) + "┐"
        
        print(topBorder)
        
        // Padding
        print("│\(String(repeating: " ", count: width - 2))│")
        print("│\(String(repeating: " ", count: width - 2))│")
        print("│\(String(repeating: " ", count: width - 2))│")
        
        // --- 2. ASCII Logo ---
        let maxLogoLength = logoLines.map { $0.count }.max() ?? 0
        let leftLogoPadding = (width - 2 - maxLogoLength) / 2
        
        // Provide the uncolored padded string, then apply gradient to the *real* text inside
        for line in logoLines {
            let spaceLeft = String(repeating: " ", count: leftLogoPadding)
            let spaceRight = String(repeating: " ", count: width - 2 - leftLogoPadding - line.count)
            let gradientStr = gradientText(
                line,
                startColor: (0, 150, 255),
                endColor: (255, 50, 150)
            )
            print("│\(spaceLeft)\(gradientStr)\(spaceRight)│")
        }
        
        // Padding
        print("│\(String(repeating: " ", count: width - 2))│")
        
        // --- 3. Subtitles & Links ---
        let subtitleText = "Your best buddy for Xcode projects."
        print(padLine(subtitleText, totalWidth: width, isCentered: true))
        print("│\(String(repeating: " ", count: width - 2))│")
        
        let targetText = "https://github.com/MainActorDev/Construkt"
        print(padLine("\(magenta)\(targetText)\(reset)", rawLength: targetText.count, totalWidth: width, isCentered: true))
        
        let authorText = "[with ❤️  by xcbuddy]"
        print(padLine("\(dim)\(authorText)\(reset)", rawLength: authorText.count, totalWidth: width, isCentered: true))
        print("│\(String(repeating: " ", count: width - 2))│")
        print("│\(String(repeating: " ", count: width - 2))│")
        
        // --- 4. Inner Properties Box ---
        let projStr = project.inferredScheme ?? "N/A"
        let boxWidth = 36
        let boxLeftPad = (width - 2 - boxWidth) / 2
        let spaceLeft = String(repeating: " ", count: boxLeftPad)
        let spaceRight = String(repeating: " ", count: width - 2 - boxLeftPad - boxWidth)
        
        print("│\(spaceLeft)┌\(String(repeating: "─", count: boxWidth - 2))┐\(spaceRight)│")
        
        func printInnerLine(_ key: String, _ value: String) {
            let rawContent = " \(key): \(value)" // Left aligned inside box
            let padRight = boxWidth - 2 - rawContent.count
            let rightSpaces = padRight > 0 ? String(repeating: " ", count: padRight) : ""
            print("│\(spaceLeft)│\(dim) \(key):\(reset) \(value)\(rightSpaces)│\(spaceRight)│")
        }
        
        printInnerLine("App", projStr)
        printInnerLine("Scheme", projStr)
        printInnerLine("Config", "Debug")
        
        print("│\(spaceLeft)└\(String(repeating: "─", count: boxWidth - 2))┘\(spaceRight)│")
        
        print("│\(String(repeating: " ", count: width - 2))│")
        print("│\(String(repeating: " ", count: width - 2))│")
        
        // --- 5. Bottom Shortcut Border ---
        let shortcutsRaw = " [r → Run] [b → Build] [t → Test] [c → Clean] [l → Logs] [q → Quit] "
        
        // We want to color it nicely but keep border integrity
        let shortcutsColored = " [\(yellow)r\(reset) → Run] [\(yellow)b\(reset) → Build] [\(yellow)t\(reset) → Test] [\(yellow)c\(reset) → Clean] [\(yellow)l\(reset) → Logs] [\(dim)q\(reset) → Quit] "
        
        // Center the shortcuts in the bottom border
        let rightDashCnt = max(0, width - 2 - shortcutsRaw.count - leftDashesCount)
        let bottomBorder = "└" + String(repeating: "─", count: leftDashesCount) + shortcutsColored + String(repeating: "─", count: rightDashCnt) + "┘"
        
        print(bottomBorder)
    }
    
    /// Pads a single line inside the box
    private static func padLine(_ content: String, rawLength: Int? = nil, totalWidth: Int, isCentered: Bool = false) -> String {
        let actualLength = rawLength ?? content.count
        
        if isCentered {
            let leftPad = max(0, (totalWidth - 2 - actualLength) / 2)
            let rightPad = max(0, totalWidth - 2 - leftPad - actualLength)
            return "│\(String(repeating: " ", count: leftPad))\(content)\(String(repeating: " ", count: rightPad))│"
        } else {
            let pad = max(0, totalWidth - 2 - actualLength - 2) // -2 for left offset
            return "│  \(content)\(String(repeating: " ", count: pad))│"
        }
    }
    
    /// Prints a primary processing step (e.g., "Build Started")
    public static func printMainStep(_ icon: String, message: String) {
        print("\n\(cyan)>\(reset) \(message)")
    }
    
    /// Prints a sub-step/progress item (e.g., "Installing app...")
    public static func printSubStep(_ message: String) {
        print("\(magenta)✦\(reset) \(message)")
    }
    
    /// Replaces the last sub-step with a completed version.
    /// Note: This assumes standard sequential terminal output.
    public static func completeLastSubStep(_ message: String) {
        // Move up one line, clear it, and print the success version
        print("\(moveUp)\(clearLine)\(green)✦\(reset) \(message)")
    }
    
    /// Prints a distinct success message.
    public static func printSuccess(_ message: String) {
        print("\n\(green)✓\(reset) \(message)\n")
    }
    
    /// Prints a distinct error message.
    public static func printError(_ message: String) {
        print("\n\(red)❌ ERROR:\(reset) \(message)\n")
    }
    
    /// Simple prompt arrow
    public static func printPrompt() {
        print("\(bold)\(cyan)>\(reset) ", terminator: "")
        fflush(stdout)
    }
    
    /// Wraps text in bold ANSI
    public static func textBold(_ text: String) -> String {
        return "\(bold)\(text)\(reset)"
    }
    /// Wraps text in dim ANSI
    public static func textDim(_ text: String) -> String {
        return "\(dim)\(text)\(reset)"
    }
    
    // MARK: - Gradient Generation
    
    /// Generates a TrueColor ANSI gradient string linearly interpolating from startColor to endColor
    /// from left to right across the string's characters.
    public static func gradientText(
        _ text: String,
        startColor: (r: Int, g: Int, b: Int),
        endColor: (r: Int, g: Int, b: Int)
    ) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard let maxLineLength = lines.map({ $0.count }).max(), maxLineLength > 0 else { return text }
        
        var result = ""
        for line in lines {
            for (i, char) in line.enumerated() {
                // Calculate progress from 0.0 to 1.0 across the maximum width of the text block
                let progress = Double(i) / Double(maxLineLength)
                
                let r = Int(Double(startColor.r) + (Double(endColor.r) - Double(startColor.r)) * progress)
                let g = Int(Double(startColor.g) + (Double(endColor.g) - Double(startColor.g)) * progress)
                let b = Int(Double(startColor.b) + (Double(endColor.b) - Double(startColor.b)) * progress)
                
                // 24-bit standard: \ESC[38;2;{r};{g};{b}m
                result += "\(escape)38;2;\(r);\(g);\(b)m\(char)"
            }
            // Reset color at the end of each line before the newline
            result += "\(reset)\n"
        }
        
        return String(result.dropLast()) // Remove trailing newline added by the loop
    }
}
