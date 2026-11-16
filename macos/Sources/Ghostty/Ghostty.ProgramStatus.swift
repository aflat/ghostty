import Foundation

extension Ghostty {
    /// What one program reported about itself with the Program Status
    /// Protocol (OSC 7501).
    struct ProgramStatus: Equatable {
        enum State: String {
            /// At rest, waiting for the user's next instruction.
            case idle

            /// Running.
            case working

            /// Finished, and the user hasn't seen the result yet.
            case done

            /// Can't continue until the user does something.
            case blocked

            /// Failed and stopped.
            case error
        }

        /// What a blocked program is waiting for.
        enum Kind: String {
            case permission
            case question
            case auth
        }

        var state: State
        var kind: Kind?
        var progress: Int?
        var app: String?
        var title: String?
        var message: String?
    }

    /// The program status records of one terminal, keyed by record ID. The
    /// root record, for a program that reports only its own state, has the
    /// empty ID.
    struct ProgramStatusRecords: Equatable {
        private(set) var records: [String: ProgramStatus] = [:]

        var isEmpty: Bool { records.isEmpty }

        /// Applies one report from libghostty: either a validated OSC 7501
        /// report with one `key=value` per line, or an event that ends
        /// earlier reports. See `apprt.action.ProgramStatus` in the core.
        mutating func apply(report: String) {
            var fields: [String: String] = [:]
            for line in report.split(separator: "\n", omittingEmptySubsequences: true) {
                guard let eq = line.firstIndex(of: "=") else { continue }
                fields[String(line[..<eq])] = String(line[line.index(after: eq)...])
            }

            // A new shell prompt or the process exiting means whatever was
            // working or blocked is gone. Done and error stay, so the user
            // still finds out about them.
            if fields["event"] != nil {
                records = records.filter { $0.value.state != .working && $0.value.state != .blocked }
                return
            }

            let id = fields["id"] ?? ""
            guard let rawState = fields["state"] else { return }

            // Clearing removes the record and everything beneath it. With
            // no ID it removes every record.
            if rawState == "clear" {
                if id.isEmpty {
                    records.removeAll()
                } else {
                    records = records.filter { $0.key != id && !$0.key.hasPrefix(id + "/") }
                }
                return
            }

            // Each report replaces its record completely.
            guard let state = ProgramStatus.State(rawValue: rawState) else { return }
            records[id] = ProgramStatus(
                state: state,
                kind: fields["kind"].flatMap(ProgramStatus.Kind.init(rawValue:)),
                progress: fields["progress"].flatMap(Int.init),
                app: fields["app"],
                title: fields["title"],
                message: fields["msg"]
            )
        }

        /// Drops the records that only exist to tell the user something
        /// finished or failed. Call it once the user is back at the terminal.
        mutating func acknowledge() {
            records = records.filter { $0.value.state != .done && $0.value.state != .error }
        }
    }
}

/// What the programs in a terminal, or in all the terminals of a tab, are
/// doing. It combines program status reports (OSC 7501) with progress
/// reports (OSC 9;4), which only say whether a program is busy.
enum TerminalActivity: String, Equatable {
    /// Nothing to show.
    case idle

    /// A program is running.
    case working

    /// A program finished and the user hasn't looked yet.
    case done

    /// A program failed.
    case error

    /// A program is waiting on the user.
    case blocked

    /// How much each activity matters when several compete for one
    /// indicator. Waiting on the user comes first, because nothing else
    /// moves until they act.
    private var urgency: Int {
        switch self {
        case .idle: 0
        case .done: 1
        case .working: 2
        case .error: 3
        case .blocked: 4
        }
    }

    /// The most urgent of a group of activities.
    init(combining activities: some Sequence<TerminalActivity>) {
        self = activities.max { $0.urgency < $1.urgency } ?? .idle
    }

    /// The activity of one terminal.
    init(progress: Ghostty.Action.ProgressReport?, status: Ghostty.ProgramStatusRecords) {
        let fromStatus = status.records.values.map { record -> TerminalActivity in
            switch record.state {
            case .idle: .idle
            case .working: .working
            case .done: .done
            case .blocked: .blocked
            case .error: .error
            }
        }

        let fromProgress: TerminalActivity = switch progress?.state {
        case .set, .indeterminate, .pause: .working
        case .error: .error
        case .remove, nil: .idle
        }

        self.init(combining: fromStatus + [fromProgress])
    }
}
