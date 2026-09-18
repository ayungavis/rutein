import Foundation

public enum RouteFormat {
    public static func distance(_ metres: Double, locale: Locale = .autoupdatingCurrent) -> String {
        Measurement(value: metres / 1000, unit: UnitLength.kilometers)
            .formatted(
                .measurement(
                    width: .abbreviated,
                    usage: .asProvided,
                    numberFormatStyle: .number.precision(.fractionLength(1)),
                ).locale(locale),
            )
    }

    public static func elevation(_ metres: Double, locale: Locale = .autoupdatingCurrent) -> String {
        Measurement(value: metres, unit: UnitLength.meters)
            .formatted(
                .measurement(
                    width: .abbreviated,
                    usage: .asProvided,
                    numberFormatStyle: .number.precision(.fractionLength(0)),
                ).locale(locale),
            )
    }

    public static func signedElevation(_ metres: Double, locale: Locale = .autoupdatingCurrent) -> String {
        Measurement(value: metres, unit: UnitLength.meters)
            .formatted(
                .measurement(
                    width: .abbreviated,
                    usage: .asProvided,
                    numberFormatStyle: .number
                        .precision(.fractionLength(0))
                        .sign(strategy: .always()),
                ).locale(locale),
            )
    }

    public static func kilometreMark(_ metres: Double, locale: Locale = .autoupdatingCurrent) -> String {
        (metres / 1000).formatted(.number.precision(.fractionLength(0)).locale(locale))
    }

    public static func grade(_ fraction: Double, locale: Locale = .autoupdatingCurrent) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    public static func duration(_ seconds: Double, locale: Locale = .autoupdatingCurrent) -> String {
        Duration.seconds(seconds)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated).locale(locale))
    }

    public static func offset(_ seconds: Double, locale: Locale = .autoupdatingCurrent) -> String {
        Duration.seconds(seconds)
            .formatted(.time(pattern: .hourMinute(padHourToLength: 2)).locale(locale))
    }

    public static func pace(
        secondsPerKilometre: Double,
        locale: Locale = .autoupdatingCurrent,
    ) -> String {
        Duration.seconds(secondsPerKilometre)
            .formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2)).locale(locale))
    }

    public static func arrival(
        _ instant: Date,
        in timeZone: TimeZone,
        locale: Locale = .autoupdatingCurrent,
    ) -> String {
        instant.formatted(
            .dateTime
                .weekday(.abbreviated)
                .hour(.defaultDigits(amPM: .abbreviated))
                .minute()
                .timeZone(.identifier(.short))
                .locale(locale),
        )
    }
}
