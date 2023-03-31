import EventKit
import LaunchAtLogin
import SwiftUI

@main
struct BarHours: App {
    @State var currentWorkType: Int = 0
    @State var started: Date? = nil

    var body: some Scene {
        let selectedWorkType = workTypes[currentWorkType]

        return MenuBarExtra(selectedWorkType.name, systemImage: selectedWorkType.icon) {
            if currentWorkType == 0 {
                ForEach(workTypes.dropFirst(), id: \.name) { workType in
                    Button(workType.name) {
                        if let index = workTypes.firstIndex(where: { $0.name == workType.name }) {
                            started = Date()
                            currentWorkType = index
                        }
                    }
                }
            } else {
                Button("Done for today \\o/") {
                    saveIntoCalendar(name: selectedWorkType.name, start: started!, end: Date())
                    currentWorkType = 0
                }
            }

            Divider()

            LaunchAtLogin.Toggle("Autostart")

            Button("Quit") {
                if currentWorkType != 0 {
                    let alert = NSAlert()
                    alert.messageText = "Are you sure you want to quit?"
                    alert.informativeText = "That does not save today into the calendar."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "Quit")
                    alert.addButton(withTitle: "Cancel")

                    let appIcon = NSImage(named: "AppIcon")?.copy() as? NSImage
                    appIcon?.isTemplate = false
                    alert.icon = appIcon

                    if alert.runModal() == .alertFirstButtonReturn {
                        NSApplication.shared.terminate(nil)
                    }
                } else {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    struct WorkType {
        let name: String
        let icon: String
    }

    let workTypes = [
        WorkType(name: "Off duty", icon: "beach.umbrella.fill"),
        WorkType(name: "Office", icon: "building.2.fill"),
        WorkType(name: "Home Office", icon: "house.fill"),
        WorkType(name: "Meeting", icon: "person.2.fill")
    ]

    func saveIntoCalendar(name: String, start: Date, end: Date) {
        // Filter out events shorter than 15 minutes
        let duration = end.timeIntervalSince(start)
        guard duration >= 900 else {
            print("Event shorter than 15 minutes, skipping")
            return
        }

        // Round the start and end dates to the nearest quarter hour
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute], from: start)
        let minute = (components.minute ?? 0) % 15
        let startRounded = calendar.date(byAdding: .minute, value: -minute, to: start)!
        let endRounded = calendar.date(byAdding: .minute, value: -minute, to: end)!

        let eventStore = EKEventStore()

        // Request access to the calendar
        eventStore.requestAccess(to: .event) { granted, error in
            if granted && error == nil {
                // Find the "Work Time" calendar
                let calendars = eventStore.calendars(for: .event)
                let workTimeCalendar = calendars.first(where: { $0.title == "Work Time" })

                if let workTimeCalendar = workTimeCalendar {
                    let event = EKEvent(eventStore: eventStore)

                    // Set the event title, start date, and end date
                    event.title = name
                    event.startDate = startRounded
                    event.endDate = endRounded

                    // Set the event's calendar to "Work Time"
                    event.calendar = workTimeCalendar

                    do {
                        try eventStore.save(event, span: .thisEvent)
                        print("Event saved to calendar")
                    } catch {
                        print("Error saving event: \(error.localizedDescription)")
                    }
                } else {
                    print("Error finding Work Time calendar")
                }
            } else {
                print("Error accessing calendar: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
}
