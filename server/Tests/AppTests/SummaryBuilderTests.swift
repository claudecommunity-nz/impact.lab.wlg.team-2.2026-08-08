// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import App

@Suite("G5 SummaryBuilder")
struct SummaryBuilderTests {
    @Test("Empty warnings produces an honest empty line")
    func emptyWarningsHonest() {
        let lines = SummaryBuilder.build(
            warnings: .ok([]),
            conditions: .ok(ConditionsEnvelope(gauges: [], electricityOutages: [], waterFaults: [])),
            hazards: HazardsEnvelope(
                status: "ok",
                note: HazardsService.planningNote,
                items: []
            ),
            nearestHub: nil
        )
        #expect(lines.contains { $0.lowercased().contains("no official warnings") })
        #expect(!SummaryBuilder.containsBannedWords(lines))
    }

    @Test("Summary never contains banned advice words")
    func noBannedWords() {
        let source = SourceMeta(
            name: "test",
            id: "test",
            trust: .official,
            fetchedAt: Date(),
            url: nil
        )
        let warning = Warning(
            id: "w1",
            event: "Heavy Rain Warning",
            headline: "Heavy Rain Warning for Wellington",
            severity: "Moderate",
            urgency: "Expected",
            certainty: "Likely",
            areaDesc: "Wellington",
            onset: Date(),
            expires: Date().addingTimeInterval(3600),
            description: "Periods of heavy rain.",
            web: nil,
            source: source
        )
        let gauge = GaugeReading(
            site: "Karori Stream at Makara Peak",
            lat: -41.29,
            lng: 174.72,
            distanceKm: 5.9,
            measurement: "Stage",
            value: 24613,
            units: "mm",
            observedAt: Date(),
            trend: "rising",
            source: source
        )
        let hub = NearestHub(
            hub: Hub(
                id: 87,
                name: "Lyall Bay Community Centre",
                type: "Community Centre",
                address: "36 Freyberg Street",
                suburb: "Lyall Bay",
                town: "Wellington",
                taName: "Wellington City",
                lat: -41.3271,
                lng: 174.7960,
                source: source
            ),
            distanceKm: 0.2
        )
        let hazard = HazardItem(
            layer: "Tsunami Evacuation Zones",
            id: "tsunami-evacuation-zones",
            value: "Orange Zone",
            detail: "Zone_Class 2",
            publisher: "Wellington City Council",
            source: SourceMeta(
                name: "WCC",
                id: "tsunami-evacuation-zones",
                trust: .planning,
                fetchedAt: Date(),
                url: nil
            )
        )

        let lines = SummaryBuilder.build(
            warnings: .ok([warning]),
            conditions: .ok(
                ConditionsEnvelope(
                    gauges: [gauge],
                    electricityOutages: [],
                    waterFaults: []
                )
            ),
            hazards: HazardsEnvelope(
                status: "ok",
                note: HazardsService.planningNote,
                items: [hazard]
            ),
            nearestHub: hub
        )

        #expect(!lines.isEmpty)
        #expect(!SummaryBuilder.containsBannedWords(lines))
        for word in SummaryBuilder.bannedWords {
            for line in lines {
                #expect(!line.lowercased().contains(word), "Found banned '\(word)' in: \(line)")
            }
        }
        #expect(lines.contains { $0.lowercased().contains("tsunami") })
        #expect(lines.contains { $0.lowercased().contains("lyall bay community centre") })
    }
}
