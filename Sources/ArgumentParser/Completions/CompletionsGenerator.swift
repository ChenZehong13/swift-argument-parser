//===----------------------------------------------------------*- swift -*-===//
//
// This source file is part of the Swift Argument Parser open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#elseif canImport(MSVCRT)
import MSVCRT
#endif

/// A shell for which the parser can generate a completion script.
public struct CompletionShell: RawRepresentable, Hashable, CaseIterable {
  public var rawValue: String
  
  /// Creates a new instance from the given string.
  public init?(rawValue: String) {
    switch rawValue {
    case "zsh", "bash":
      self.rawValue = rawValue
    default:
      return nil
    }
  }
  
  /// An instance representing `zsh`.
  public static var zsh: CompletionShell { CompletionShell(rawValue: "zsh")! }

  /// An instance representing `bash`.
  public static var bash: CompletionShell { CompletionShell(rawValue: "bash")! }

  /// Returns an instance representing the current shell, if recognized.
  public static func autodetect() -> CompletionShell? {
    // FIXME: This retrieves the user's preferred shell, not necessarily the one currently in use.
    guard let shellVar = getenv("SHELL") else { return nil }
    let shellParts = String(cString: shellVar).split(separator: "/")
    return CompletionShell(rawValue: String(shellParts.last ?? ""))
  }
  
  /// An array of all supported shells for completion scripts.
  public static var allCases: [CompletionShell] {
    [.zsh, .bash]
  }
}

struct CompletionsGenerator {
  var shell: CompletionShell
  var command: ParsableCommand.Type
  
  init(command: ParsableCommand.Type, shell: CompletionShell?) throws {
    guard let _shell = shell ?? .autodetect() else {
      throw ParserError.unsupportedShell()
    }

    self.shell = _shell
    self.command = command
  }

  init(command: ParsableCommand.Type, shellName: String?) throws {
    if let shellName = shellName {
      guard let shell = CompletionShell(rawValue: shellName) else {
        throw ParserError.unsupportedShell(shellName)
      }
      try self.init(command: command, shell: shell)
    } else {
      try self.init(command: command, shell: nil)
    }
  }
  
  /// Generates a Bash completion script for this generators shell and command..
  func generateCompletionScript() -> String {
    switch shell {
    case .zsh:
      return ZshCompletionsGenerator.generateCompletionScript(command)
    case .bash:
      return BashCompletionsGenerator.generateCompletionScript(command)
    default:
      fatalError("Invalid CompletionShell: \(shell)")
    }
  }
}

extension ArgumentDefinition {
  /// Returns a string with the arguments for the callback to generate custom completions for
  /// this argument.
  func customCompletionCall(_ commands: [ParsableCommand.Type]) -> String {
    let subcommandNames = commands.dropFirst().map { $0._commandName }.joined(separator: " ")
    let argumentName = preferredNameForSynopsis?.synopsisString
          ?? self.help.keys.first?.rawValue ?? "---"
    return "---completion \(subcommandNames) -- \(argumentName)"
  }
}
