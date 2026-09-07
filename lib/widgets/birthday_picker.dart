import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

const _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

DateTime birthdayMinDate() {
  final now = DateTime.now();
  return DateTime(now.year - 120, now.month, now.day);
}

DateTime birthdayMaxDate() {
  final now = DateTime.now();
  return DateTime(now.year - 13, now.month, now.day);
}

DateTime clampBirthday(DateTime value) {
  final min = birthdayMinDate();
  final max = birthdayMaxDate();
  if (value.isAfter(max)) return max;
  if (value.isBefore(min)) return min;
  return DateTime(value.year, value.month, value.day);
}

String formatBirthdayDisplay(DateTime d) =>
    '${_monthAbbr[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';

/// iOS-style month/day/year wheel used on Edit Profile and onboarding.
Future<DateTime?> showBirthdayWheelPicker(
  BuildContext context, {
  DateTime? selected,
}) {
  var current = clampBirthday(selected ?? birthdayMaxDate());
  final min = birthdayMinDate();
  final max = birthdayMaxDate();

  return showModalBottomSheet<DateTime>(
    context: context,
    useRootNavigator: true,
    backgroundColor: AppColors.warmWhite,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Birthday',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      onPressed: () => Navigator.pop(ctx, current),
                      child: Text(
                        'Done',
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepRose,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoTheme(
                  data: const CupertinoThemeData(
                    brightness: Brightness.light,
                    primaryColor: AppColors.deepRose,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        fontSize: 21,
                        color: AppColors.charcoal,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: current,
                    minimumDate: min,
                    maximumDate: max,
                    onDateTimeChanged: (value) => current = value,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
