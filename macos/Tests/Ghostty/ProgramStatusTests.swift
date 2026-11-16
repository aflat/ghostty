import Testing

@testable import Ghostty

/// Tests for `Ghostty.ProgramStatusRecords`, which keeps the Program Status
/// Protocol (OSC 7501) records of one terminal, and for the `TerminalActivity`
/// the sidebar derives from them.
///
/// Reports arrive already validated by libghostty, one `key=value` per line.
struct ProgramStatusTests {
    private func records(_ reports: String...) -> Ghostty.ProgramStatusRecords {
        var records = Ghostty.ProgramStatusRecords()
        for report in reports { records.apply(report: report) }
        return records
    }

    private func activity(_ reports: String...) -> TerminalActivity {
        var records = Ghostty.ProgramStatusRecords()
        for report in reports { records.apply(report: report) }
        return TerminalActivity(progress: nil, status: records)
    }

    // MARK: Records

    @Test func reportWithoutIDSetsTheRootRecord() {
        let root = records("state=blocked\nkind=permission\napp=terraform\nmsg=Apply 3 to add?").records[""]
        #expect(root?.state == .blocked)
        #expect(root?.kind == .permission)
        #expect(root?.app == "terraform")
        #expect(root?.message == "Apply 3 to add?")
    }

    @Test func messageMayContainEqualsSigns() {
        #expect(records("state=done\nmsg=a=b=c").records[""]?.message == "a=b=c")
    }

    @Test func reportReplacesItsRecordCompletely() {
        let root = records("state=working\nprogress=40\napp=cargo", "state=working").records[""]
        #expect(root?.progress == nil)
        #expect(root?.app == nil)
    }

    @Test func recordsWithDifferentIDsCoexist() {
        let all = records("state=idle", "state=blocked\nid=build/test").records
        #expect(all[""]?.state == .idle)
        #expect(all["build/test"]?.state == .blocked)
    }

    @Test func clearWithIDRemovesTheRecordAndItsChildren() {
        let all = records(
            "state=working\nid=build",
            "state=working\nid=build/test",
            "state=working\nid=builder",
            "state=clear\nid=build"
        ).records
        #expect(Set(all.keys) == ["builder"])
    }

    @Test func clearWithoutIDRemovesEverything() {
        #expect(records("state=working", "state=done\nid=a", "state=clear").isEmpty)
    }

    @Test(arguments: ["event=prompt", "event=exit"])
    func eventsDropWorkingAndBlockedButKeepDoneAndError(event: String) {
        let all = records(
            "state=working\nid=a",
            "state=blocked\nid=b",
            "state=done\nid=c",
            "state=error\nid=d",
            event
        ).records
        #expect(Set(all.keys) == ["c", "d"])
    }

    @Test func acknowledgeDropsDoneAndErrorOnly() {
        var all = records(
            "state=working\nid=a",
            "state=blocked\nid=b",
            "state=done\nid=c",
            "state=error\nid=d"
        )
        all.acknowledge()
        #expect(Set(all.records.keys) == ["a", "b"])
    }

    // MARK: Activity

    @Test func noReportsIsIdle() {
        #expect(activity() == .idle)
    }

    @Test func blockedOutranksEverything() {
        #expect(activity("state=working", "state=error\nid=a", "state=blocked\nid=b") == .blocked)
    }

    @Test func errorOutranksWorkingAndDone() {
        #expect(activity("state=working", "state=done\nid=a", "state=error\nid=b") == .error)
    }

    @Test func workingOutranksDone() {
        #expect(activity("state=done", "state=working\nid=a") == .working)
    }

    @Test func combiningTakesTheMostUrgent() {
        #expect(TerminalActivity(combining: [.idle, .done, .working]) == .working)
        #expect(TerminalActivity(combining: []) == .idle)
    }
}
