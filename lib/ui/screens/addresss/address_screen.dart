import 'dart:convert';
import 'dart:developer';

import 'package:Ziepick/data/cubits/home/fetch_home_all_items_cubit.dart';
import 'package:Ziepick/data/cubits/home/fetch_home_screen_cubit.dart';
import 'package:Ziepick/settings.dart';
import 'package:Ziepick/ui/screens/addresss/add_edit_address.dart';
import 'package:Ziepick/ui/screens/widgets/errors/no_data_found.dart';
import 'package:Ziepick/ui/screens/widgets/shimmerLoadingContainer.dart';
import 'package:Ziepick/ui/theme/theme.dart';
import 'package:Ziepick/utils/constant.dart';
import 'package:Ziepick/utils/custom_text.dart';
import 'package:Ziepick/utils/extensions/extensions.dart';
import 'package:Ziepick/utils/hive_utils.dart';
import 'package:Ziepick/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  List<Map<String, dynamic>> addressData = [];
  List<Map<String, dynamic>> filteredAddressData = [];
  bool isLoading = false;

  int? selectedAddressId;

  TextEditingController _searchController = TextEditingController();
  ValueNotifier<String> _locationStatus = ValueNotifier('enableLocation');
  String _currentLocation = '';
  bool _isFetchingLocation = false;

  @override
  void initState() {
    super.initState();
    getAddressData();

    // 🔎 Search listener
    _searchController.addListener(() {
      filterAddresses(_searchController.text);
    });
  }

  // 🔎 Filter logic
  void filterAddresses(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredAddressData = List.from(addressData);
      });
    } else {
      setState(() {
        filteredAddressData = addressData.where((address) {
          final addr = (address["address"] ?? "").toString().toLowerCase();
          final city = (address["city"] ?? "").toString().toLowerCase();
          final state = (address["state"] ?? "").toString().toLowerCase();
          final landmark = (address["landmark"] ?? "").toString().toLowerCase();
          final type = (address["addr_type"] ?? "").toString().toLowerCase();

          return addr.contains(query.toLowerCase()) ||
              city.contains(query.toLowerCase()) ||
              state.contains(query.toLowerCase()) ||
              landmark.contains(query.toLowerCase()) ||
              type.contains(query.toLowerCase());
        }).toList();
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    if (_isFetchingLocation) return;
    _isFetchingLocation = true;
    try {
      final locationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!locationEnabled) {
        await Geolocator.openLocationSettings();
        return;
      }

      final permission = await Geolocator.checkPermission();
      log('$permission', name: 'current status');
      if (permission == LocationPermission.denied) {
        final newPermission = await Geolocator.requestPermission();
        if (newPermission == LocationPermission.denied) {
          Fluttertoast.showToast(
              msg: "Location permission is required to fetch address");
          return;
        }
      } else if (permission == LocationPermission.deniedForever) {
        Fluttertoast.showToast(msg: "Enable location from app settings");
        await Geolocator.openAppSettings();
        return;
      } else {
        _locationStatus.value = 'fetchingLocation';
      }

      Position position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(accuracy: LocationAccuracy.high));
      await setLocaleIdentifier("en_US");
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks[0];
        if (mounted) {
          _currentLocation = [
            placemark.subLocality,
            placemark.locality,
            placemark.administrativeArea,
            placemark.country,
          ].where((part) => part != null && part.isNotEmpty).join(', ');
          _locationStatus.value = _currentLocation.isNotEmpty
              ? 'locationFetched'
              : 'enableLocation';

          HiveUtils.setCurrentLocation(
            area: placemark.subLocality,
            city: placemark.locality!,
            state: placemark.administrativeArea!,
            country: placemark.country!,
            latitude: position.latitude,
            longitude: position.longitude,
          );

          if (Constant.isDemoModeOn) {
            UiUtils.setDefaultLocationValue(
                isCurrent: false, isHomeUpdate: true, context: context);
            Navigator.pop(context);
          } else {
            HiveUtils.setLocation(
              area: placemark.subLocality,
              city: placemark.locality!,
              state: placemark.administrativeArea!,
              country: placemark.country!,
              latitude: position.latitude,
              longitude: position.longitude,
            );

            // Set mode to live GPS
            HiveUtils.setLocationMode("live");

            Future.delayed(Duration.zero, () {
              context.read<FetchHomeScreenCubit>().fetch(
                  latitude: position.latitude,
                  longitude: position.longitude,
                  radius: null);
              context.read<FetchHomeAllItemsCubit>().fetch(
                  latitude: position.latitude,
                  longitude: position.longitude,
                  radius: null);
            });
            Navigator.pop(context);
          }
        }
      } else {
        _locationStatus.value = 'unableToDetermineLocation';
      }
    } catch (e) {
      log('$e');
      _locationStatus.value = 'locationFetchError';
    } finally {
      _isFetchingLocation = false;
    }
  }

  void getAddressData() async {
    addressData.clear();
    if (HiveUtils.getAreaId() != null) {
      selectedAddressId = HiveUtils.getAreaId();
    }
    setState(() {
      isLoading = true;
    });
    var response = await http.get(Uri.parse(
        '${AppSettings.baseUrl}my-addresses?user_id=${HiveUtils.getUserDetails().id}'));
    setState(() {
      isLoading = false;
    });
    if (response.statusCode == 200) {
      Map<String, dynamic> data = jsonDecode(response.body);
      if (data['data'] != null) {
        addressData = List<Map<String, dynamic>>.from(data['data']);
        filteredAddressData = List.from(addressData); // init filtered
        setState(() {});
      }
    }
  }

  // Method to handle address selection
  Future<void> selectAddress(Map<String, dynamic> address) async {
    final latitude = double.tryParse(address['latitude'] ?? "0") ?? 0.0;
    final longitude = double.tryParse(address['longtitude'] ?? "0") ?? 0.0;

    log("📍 Selected Address Details:", name: "AddressScreen");
    log("   City: ${address['city']}", name: "AddressScreen");
    log("   State: ${address['state']}", name: "AddressScreen");
    log("   Landmark: ${address['landmark']}", name: "AddressScreen");
    log("   Latitude (from DB): ${address['latitude']}", name: "AddressScreen");
    log("   Longitude (from DB): ${address['longtitude']}",
        name: "AddressScreen");
    log("   Parsed Latitude: $latitude", name: "AddressScreen");
    log("   Parsed Longitude: $longitude", name: "AddressScreen");

    // Save to Hive - home screen will auto-refresh via listener
    await HiveUtils.setLocation(
      area: address['landmark'] ?? "",
      city: address['city'],
      state: address['state'],
      country: "India",
      latitude: latitude,
      longitude: longitude,
      areaId: address["id"] ?? 0,
      addressText: address['address'] ?? "",
    );

    // Ensure radius is set for distance-based filtering
    if (HiveUtils.getNearbyRadius() == null) {
      await HiveUtils.setNearbyRadius(3); // Default 3km radius
      log("⚙️ Set default radius: 3km", name: "AddressScreen");
    }

    log("💾 Saved to Hive:", name: "AddressScreen");
    log("   HiveUtils.getLatitude(): ${HiveUtils.getLatitude()}",
        name: "AddressScreen");
    log("   HiveUtils.getLongitude(): ${HiveUtils.getLongitude()}",
        name: "AddressScreen");
    log("   HiveUtils.getCityName(): ${HiveUtils.getCityName()}",
        name: "AddressScreen");
    log("   HiveUtils.getNearbyRadius(): ${HiveUtils.getNearbyRadius()}",
        name: "AddressScreen");
    log("   HiveUtils.getLocationMode(): ${HiveUtils.getLocationMode()}",
        name: "AddressScreen");

    // Set mode to address (not live GPS)
    await HiveUtils.setLocationMode("address");

    setState(() {
      selectedAddressId = address["id"];
    });

    // Show success message
    Fluttertoast.showToast(
        msg: "Address changed successfully",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM);

    // Navigate back - home screen will automatically refresh
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: UiUtils.buildAppBar(context,
          showBackButton: true, title: "My Address".translate(context)),
      body: Column(
        children: [
          // 🔎 Search Field
          if (addressData.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search address...",
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

          // 📍 Use Current Location
          /*Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            child: InkWell(
              onTap: _getCurrentLocation,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.my_location,
                    color: context.color.territoryColor,
                  ),
                  Expanded(
                    child: Padding(
                      padding:
                      const EdgeInsetsDirectional.only(start: 13),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomText(
                            "useCurrentLocation".translate(context),
                            color: context.color.territoryColor,
                            fontWeight: FontWeight.bold,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 3.0),
                            child: ValueListenableBuilder(
                                valueListenable: _locationStatus,
                                builder: (context, value, child) {
                                  return CustomText(
                                    value == 'locationFetched'
                                        ? _currentLocation
                                        : value.translate(context),
                                    softWrap: true,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  );
                                }),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),*/

          // 🏠 Address List
          Expanded(
            child: isLoading
                ? shimmerEffect()
                : addressData.isEmpty
                    ? NoDataFound(onTap: () {})
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredAddressData.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final address = filteredAddressData[index];
                          final isSelected = selectedAddressId == address["id"];

                          return InkWell(
                            onTap: () => selectAddress(address),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? context.color.territoryColor
                                      : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Transform.scale(
                                            scale: 1.1,
                                            child: Radio<int>(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              value: address["id"],
                                              groupValue: selectedAddressId,
                                              activeColor:
                                                  context.color.territoryColor,
                                              onChanged: (val) {
                                                selectAddress(address);
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color:
                                                  address["addr_type"] == "Home"
                                                      ? Colors.blue
                                                          .withOpacity(0.15)
                                                      : Colors.green
                                                          .withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              address["addr_type"] ?? "",
                                              style: TextStyle(
                                                color: address["addr_type"] ==
                                                        "Home"
                                                    ? Colors.blue
                                                    : Colors.green,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            onPressed: () {
                                              Navigator.of(context)
                                                  .push(MaterialPageRoute(
                                                      builder: (context) =>
                                                          AddEditAddress(
                                                            editData: address,
                                                          )))
                                                  .then((e) {
                                                getAddressData();
                                              });
                                            },
                                            icon: const Icon(Icons.edit,
                                                color: Colors.orange),
                                            tooltip: "Edit",
                                          ),
                                          IconButton(
                                            onPressed: () {
                                              deleteLocationData({
                                                "id": address["id"].toString(),
                                              });
                                            },
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            tooltip: "Delete",
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    address["address"] ?? "",
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (address["landmark"] != null &&
                                      (address["landmark"] as String)
                                          .isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      "Landmark: ${address["landmark"]}",
                                      style: const TextStyle(
                                          fontSize: 13, color: Colors.grey),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    "${address["city"] ?? ""}, ${address["state"] ?? ""}",
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(8, 8, 8, 45),
        child: GestureDetector(
          onTap: () {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (context) => AddEditAddress()))
                .then((e) {
              getAddressData();
            });
          },
          child: Container(
            height: 45,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: context.color.territoryColor,
            ),
            child: const Center(
              child: Text(
                "Add New Address",
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void deleteLocationData(Map<String, dynamic> rawData) async {
    var response = await http
        .post(Uri.parse("${AppSettings.baseUrl}delete-address"), body: rawData);

    if (response.statusCode == 200) {
      Map<String, dynamic> data = jsonDecode(response.body);
      Fluttertoast.showToast(msg: data['message']);
      getAddressData();
    }
  }

  ListView shimmerEffect() {
    return ListView.separated(
      shrinkWrap: true,
      itemCount: 8,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
          width: double.maxFinite,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(15)),
                child: CustomShimmer(height: 90, width: 90),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SizedBox(height: 10),
                    CustomShimmer(height: 10, width: 150),
                    SizedBox(height: 10),
                    CustomShimmer(height: 10),
                    SizedBox(height: 10),
                    CustomShimmer(height: 10, width: 200),
                    SizedBox(height: 10),
                    CustomShimmer(width: 80),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
