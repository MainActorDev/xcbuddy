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
    private static let cyan = "\(escape)36m"
    
    // Clear Commands
    private static let clearLine = "\(escape)2K"
    private static let moveUp = "\(escape)1A"
    
    // MARK: - API
    
    /// Prints a sticky header representing the current active context.
    public static func printHeader(project: ProjectContext) {
        print("\n\(bold)\(blue)xcbuddy\(reset)\(bold) Interactive\(reset)")
        print("\(dim)v1.0.0\(reset)\n")
        
        let targetStr = project.inferredScheme ?? "N/A"
        let schemeStr = project.inferredScheme ?? "N/A"
        
        print("\(dim)App:\(reset)      \(targetStr)")
        print("\(dim)Scheme:\(reset)   \(schemeStr)")
        print("\(dim)Config:\(reset)   Debug\n")
        
        print("\(dim)Press 'h' for help\(reset)\n")
    }
    
    /// Prints a primary processing step (e.g., "Build Started")
    public static func printMainStep(_ icon: String, message: String) {
        print("\n\(icon) \(bold)\(message)\(reset)")
    }
    
    /// Prints a sub-step/progress item (e.g., "Installing app...")
    public static func printSubStep(_ message: String) {
        print("  \(cyan)•\(reset) \(message)")
    }
    
    /// Replaces the last sub-step with a completed version.
    /// Note: This assumes standard sequential terminal output.
    public static func completeLastSubStep(_ message: String) {
        // Move up one line, clear it, and print the success version
        print("\(moveUp)\(clearLine)  \(green)✓\(reset) \(message)")
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
}
