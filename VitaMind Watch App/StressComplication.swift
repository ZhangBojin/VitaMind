#if os(watchOS)

import ClockKit

/// Provides complication data from the latest stress measurement.
final class ComplicationController: NSObject, CLKComplicationDataSource {

    func currentTimelineEntry(for complication: CLKComplication) async -> CLKComplicationTimelineEntry? {
        await createEntry(for: complication, date: Date())
    }

    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        handler(nil)
    }

    func getPrivacyBehavior(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void
    ) {
        handler(.showOnLockScreen)
    }

    func getTimelineEntries(
        for complication: CLKComplication,
        after date: Date,
        limit: Int,
        withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void
    ) {
        Task { @MainActor in
            let entry = await createEntry(for: complication, date: Date())
            handler(entry.map { [$0] } ?? [])
        }
    }

    func getLocalizableSampleTemplate(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationTemplate?) -> Void
    ) {
        handler(makeTemplate(for: complication.family, score: 72, level: "注意"))
    }

    // MARK: - Private

    private func createEntry(for complication: CLKComplication, date: Date) async -> CLKComplicationTimelineEntry? {
        let score = await StressDataStore.shared.latestScore
        let level = await StressDataStore.shared.latestLevel
        guard let template = makeTemplate(for: complication.family, score: score, level: level) else {
            return nil
        }
        return CLKComplicationTimelineEntry(date: date, complicationTemplate: template)
    }

    private func makeTemplate(
        for family: CLKComplicationFamily,
        score: Int?,
        level: String
    ) -> CLKComplicationTemplate? {
        let text = score.map { "\($0)" } ?? "--"

        switch family {
        case .circularSmall:
            return CLKComplicationTemplateCircularSmallSimpleText(
                textProvider: CLKSimpleTextProvider(text: text)
            )

        case .modularSmall:
            return CLKComplicationTemplateModularSmallSimpleText(
                textProvider: CLKSimpleTextProvider(text: text)
            )

        case .modularLarge:
            return CLKComplicationTemplateModularLargeStandardBody(
                headerTextProvider: CLKSimpleTextProvider(text: "压力 \(text)"),
                body1TextProvider: CLKSimpleTextProvider(text: level)
            )

        case .utilitarianSmall:
            return CLKComplicationTemplateUtilitarianSmallFlat(
                textProvider: CLKSimpleTextProvider(text: text)
            )

        case .utilitarianLarge:
            return CLKComplicationTemplateUtilitarianLargeFlat(
                textProvider: CLKSimpleTextProvider(text: "压力 \(text)")
            )

        case .extraLarge:
            return CLKComplicationTemplateExtraLargeSimpleText(
                textProvider: CLKSimpleTextProvider(text: text)
            )

        default:
            return CLKComplicationTemplateCircularSmallSimpleText(
                textProvider: CLKSimpleTextProvider(text: text)
            )
        }
    }
}

#endif

