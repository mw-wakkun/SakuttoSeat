//
//  VenueExpansionTests.swift
//  SakuttoSeatTests
//
//  v2.1（人数・会場サイズ上限とセッション解放の横断契約）
//

import XCTest
@testable import SakuttoSeat

final class VenueExpansionInteractorCrossTests: XCTestCase {

    func test_列3で視聴成功したセッションは41人目も11卓目も広告なし() {
        let unlock = FeatureUnlockState()
        let venue = VenueSettingsInteractor(currentColumnCount: 2, featureUnlock: unlock)
        venue.select(3)
        XCTAssertEqual(venue.applyRequirement(), .rewardedAd)
        venue.grantSessionUnlock()
        venue.select(8)
        XCTAssertEqual(venue.applyRequirement(), .none)

        let attendees = AttendeeListInteractor(featureUnlock: unlock)
        _ = attendees.add(fromText: (1...FeatureLimit.freeAttendeeCount).map { "P\($0)" }.joined(separator: ","))
        XCTAssertEqual(attendees.attendeeCapacityDecision(addingCount: 1), .allowed)
        XCTAssertEqual(attendees.applyAttendeeAppend(["41人目"]).decision, .allowed)

        let chart = SeatingChartInteractor(
            attendees: [Attendee(name: "A")],
            featureUnlock: unlock
        )
        for _ in 1..<FeatureLimit.freeTableCount {
            _ = chart.addTable()
        }
        XCTAssertEqual(chart.tableAddDecision(additionalCapacity: nil), .allowed)
        XCTAssertEqual(chart.addTable().count, FeatureLimit.freeTableCount + 1)
    }
}

@MainActor
final class VenueExpansionPresenterCrossTests: XCTestCase {

    func test_列解放後は人数も卓もpresentしない() async {
        let unlock = FeatureUnlockState()
        let venueFake = RewardedAdGatewayFake(outcome: .success)
        let venuePresenter = VenueSettingsPresenter(
            interactor: VenueSettingsInteractor(currentColumnCount: 2, featureUnlock: unlock),
            router: VenueSettingsRouter(rewardedAd: venueFake),
            output: nil
        )
        venuePresenter.didChangeSelection(3)
        await venuePresenter.confirmWatchAd(requestedColumnCount: 3)
        XCTAssertTrue(unlock.isSessionUnlocked)
        XCTAssertEqual(venueFake.presentCallCount, 1)

        let attendeeFake = RewardedAdGatewayFake(outcome: .success)
        let attendeeInteractor = AttendeeListInteractor(featureUnlock: unlock)
        _ = attendeeInteractor.add(fromText: (1...FeatureLimit.freeAttendeeCount).map { "P\($0)" }.joined(separator: ","))
        let attendeePresenter = AttendeeListPresenter(
            interactor: attendeeInteractor,
            router: AttendeeListRouter(rewardedAd: attendeeFake)
        )
        XCTAssertTrue(attendeePresenter.didTapAdd(name: "41人目"))
        XCTAssertNil(attendeePresenter.route)
        XCTAssertEqual(attendeeFake.presentCallCount, 0)

        let tableFake = RewardedAdGatewayFake(outcome: .success)
        let chartPresenter = SeatingChartPresenter(
            interactor: SeatingChartInteractor(
                attendees: [Attendee(name: "A")],
                featureUnlock: unlock
            ),
            router: SeatingChartRouter(rewardedAd: tableFake)
        )
        for _ in 1..<FeatureLimit.freeTableCount {
            chartPresenter.didTapAddTable()
        }
        chartPresenter.didTapAddTable()
        XCTAssertNil(chartPresenter.route)
        XCTAssertEqual(tableFake.presentCallCount, 0)
    }
}
