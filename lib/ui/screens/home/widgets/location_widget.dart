import 'package:Ziepick/app/routes.dart';
import 'package:Ziepick/ui/screens/addresss/address_screen.dart';
import 'package:Ziepick/ui/theme/theme.dart';
import 'package:Ziepick/utils/app_icon.dart';
import 'package:Ziepick/utils/custom_text.dart';
import 'package:Ziepick/utils/extensions/extensions.dart';
import 'package:Ziepick/utils/hive_keys.dart';
import 'package:Ziepick/utils/hive_utils.dart';
import 'package:Ziepick/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LocationWidget extends StatelessWidget {
  const LocationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.none,
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () async {
              // Navigator.pushNamed(context, Routes.countriesScreen,
              //     arguments: {"from": "home"});
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => AddressScreen()));
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: context.color.secondaryColor,
                  borderRadius: BorderRadius.circular(10)),
              child: UiUtils.getSvg(
                AppIcons.location,
                fit: BoxFit.none,
                color: context.color.territoryColor,
              ),
            ),
          ),
          SizedBox(
            width: 10,
          ),
          ValueListenableBuilder(
              valueListenable: Hive.box(HiveKeys.userDetailsBox).listenable(),
              builder: (context, value, child) {
                final isLiveMode = HiveUtils.isLiveLocationMode();

                // Get address text or fallback to area + city
                String locationText;
                if (isLiveMode) {
                  // For live GPS mode, show current location details
                  locationText = [
                    HiveUtils.getCurrentAreaName(),
                    HiveUtils.getCurrentCityName(),
                  ]
                          .where((element) =>
                              element != null && element.isNotEmpty)
                          .join(", ")
                          .isEmpty
                      ? "------"
                      : [
                          HiveUtils.getCurrentAreaName(),
                          HiveUtils.getCurrentCityName(),
                        ]
                          .where((element) =>
                              element != null && element.isNotEmpty)
                          .join(", ");
                } else {
                  // For address mode, prioritize full address text
                  final addressText = HiveUtils.getAddressText();
                  if (addressText != null && addressText.isNotEmpty) {
                    locationText = addressText;
                  } else {
                    // Fallback to area + city
                    locationText = [
                      HiveUtils.getAreaName(),
                      HiveUtils.getCityName(),
                    ]
                            .where((element) =>
                                element != null && element.isNotEmpty)
                            .join(", ")
                            .isEmpty
                        ? "------"
                        : [
                            HiveUtils.getAreaName(),
                            HiveUtils.getCityName(),
                          ]
                            .where((element) =>
                                element != null && element.isNotEmpty)
                            .join(", ");
                  }
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomText(
                          "locationLbl".translate(context),
                          color: context.color.textColorDark,
                          fontSize: context.font.small,
                        ),
                        SizedBox(width: 4),
                        // Mode indicator
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isLiveMode
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.blue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: CustomText(
                            isLiveMode ? "GPS" : "📍",
                            color: isLiveMode ? Colors.green : Colors.blue,
                            fontSize: context.font.small - 2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    CustomText(
                      locationText,
                      maxLines: 1,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      color: context.color.textColorDark,
                      fontSize: context.font.small,
                      fontWeight: FontWeight.w600,
                    ),
                  ],
                );
              }),
        ],
      ),
    );
  }
}
