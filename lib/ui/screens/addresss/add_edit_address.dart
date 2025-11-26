import 'dart:convert';
import 'package:Ziepick/settings.dart';
import 'package:Ziepick/ui/theme/theme.dart';
import 'package:Ziepick/utils/extensions/extensions.dart';
import 'package:Ziepick/utils/hive_utils.dart';
import 'package:Ziepick/utils/ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class AddEditAddress extends StatefulWidget {
  final Map<String, dynamic>? editData;
  const AddEditAddress({super.key, this.editData});

  @override
  State<AddEditAddress> createState() => _AddEditAddressState();
}

class _AddEditAddressState extends State<AddEditAddress> {
  GoogleMapController? mapController;
  LatLng? centerPosition;

  String addressType = 'Home';
  List<Map<String, dynamic>> states = [];
  List<Map<String, dynamic>> cities = [];

  String? selectedStateId;
  String? selectedStateName;
  String? selectedCityId;
  String? selectedCityName;

  int statePage = 1;
  bool isLoadingStates = false;
  bool hasMoreStates = true;

  int cityPage = 1;
  bool isLoadingCities = false;
  bool hasMoreCities = true;

  TextEditingController addressController = TextEditingController();
  TextEditingController landmarkController = TextEditingController();
  late OutlineInputBorder border;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
    );
    _setCurrentLocation();
    _fetchStates().then((_) {
      if (mounted && widget.editData != null) {
        _prefillEditData();
      }
    });
  }

  /// Set current location
  Future<void> _setCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    if (mounted) {
      setState(() {
        centerPosition = LatLng(position.latitude, position.longitude);
      });
    }
    if (mapController != null && centerPosition != null) {
      mapController!.animateCamera(CameraUpdate.newLatLng(centerPosition!));
    }
  }

  /// Prefill edit data
  void _prefillEditData() async {
    final data = widget.editData!;
    addressController.text = data['address'] ?? "";
    landmarkController.text = data['landmark'] ?? "";
    addressType = data['addr_type'] ?? "Home";
    selectedStateName = data['state'];
    selectedCityName = data['city'];

    if (data['latitude'] != null && data['longtitude'] != null) {
      centerPosition = LatLng(
        double.parse(data['latitude'].toString()),
        double.parse(data['longtitude'].toString()),
      );
    }

    final stateMatch = states.firstWhere(
      (s) =>
          s['name'].toString().toLowerCase() ==
          selectedStateName?.toLowerCase(),
      orElse: () => {},
    );

    if (stateMatch.isNotEmpty) {
      selectedStateId = stateMatch['id'];
      if (mounted) {
        await _fetchCities(selectedStateId!);
      }

      final cityMatch = cities.firstWhere(
        (c) =>
            c['name'].toString().toLowerCase() ==
            selectedCityName?.toLowerCase(),
        orElse: () => {},
      );
      if (cityMatch.isNotEmpty) {
        selectedCityId = cityMatch['id'];
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  /// Fetch all states
  Future<void> _fetchStates({String? searchQuery}) async {
    if (isLoadingStates || !hasMoreStates) return;
    if (mounted) {
      setState(() => isLoadingStates = true);
    }

    String url = "${AppSettings.baseUrl}states?page=$statePage&country_id=101";
    if (searchQuery != null && searchQuery.isNotEmpty) {
      url += "&search=$searchQuery";
    }
    final res = await http.get(Uri.parse(url));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final List<dynamic> stateList = data['data']['data'];
      if (mounted) {
        setState(() {
          states.addAll(stateList.map((e) => {
                "id": e['id'].toString(),
                "name": e['name'].toString(),
              }));
          if (statePage < data['data']['last_page']) {
            statePage++;
          } else {
            hasMoreStates = false;
          }
        });
      }
    }
    if (mounted) {
      setState(() => isLoadingStates = false);
    }
  }

  /// Fetch all cities
  Future<void> _fetchCities(String stateId, {String? searchQuery}) async {
    if (isLoadingCities || !hasMoreCities) return;
    if (mounted) {
      setState(() => isLoadingCities = true);
    }

    String url =
        "${AppSettings.baseUrl}cities?state_id=$stateId&page=$cityPage";
    if (searchQuery != null && searchQuery.isNotEmpty) {
      url += "&search=$searchQuery";
    }
    final res = await http.get(Uri.parse(url));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final List<dynamic> cityList = data['data']['data'] ?? data['data'];
      if (mounted) {
        setState(() {
          cities.addAll(cityList.map((e) => {
                "id": e['id'].toString(),
                "name": e['name'].toString(),
              }));
          if (data['data'] is Map &&
              cityPage < (data['data']['last_page'] ?? 1)) {
            cityPage++;
          } else {
            hasMoreCities = false;
          }
        });
      }
    }
    if (mounted) {
      setState(() => isLoadingCities = false);
    }
  }

  /// Search states from API
  Future<List<Map<String, dynamic>>> _searchStates(String query) async {
    final url =
        Uri.parse("${AppSettings.baseUrl}states?country_id=101&search=$query");
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final List<dynamic> stateList = data['data']['data'] ?? data['data'];
      return stateList
          .map((e) => {
                "id": e['id'].toString(),
                "name": e['name'].toString(),
              })
          .toList();
    }
    return [];
  }

  /// Search cities from API
  Future<List<Map<String, dynamic>>> _searchCities(
      String stateId, String query) async {
    final url = Uri.parse(
        "${AppSettings.baseUrl}cities?state_id=$stateId&search=$query");
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final List<dynamic> cityList = data['data']['data'] ?? data['data'];
      return cityList
          .map((e) => {
                "id": e['id'].toString(),
                "name": e['name'].toString(),
              })
          .toList();
    }
    return [];
  }

  /// Bottom sheet selector
  Future<void> _openSelectionSheet({
    required String title,
    required List<Map<String, dynamic>> items,
    required String? selectedId,
    required Function(String id, String name) onSelected,
    required Future<void> Function() onLoadMore,
    required Future<List<Map<String, dynamic>>> Function(String) onSearch,
    required bool isLoading,
    required bool hasMore,
  }) async {
    ScrollController scrollController = ScrollController();
    TextEditingController searchController = TextEditingController();
    List<Map<String, dynamic>> filteredItems = List.from(items);
    bool isSearching = false;
    bool isModalOpen = true;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            scrollController.addListener(() async {
              if (scrollController.position.pixels >=
                  scrollController.position.maxScrollExtent - 50) {
                if (!isLoading &&
                    hasMore &&
                    searchController.text.isEmpty &&
                    isModalOpen) {
                  if (isModalOpen) {
                    modalSetState(() => isLoading = true);
                  }
                  await onLoadMore();
                  if (isModalOpen) {
                    modalSetState(() {
                      isLoading = false;
                      filteredItems = List.from(items);
                    });
                  }
                }
              }
            });

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: "Search...",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      onChanged: (query) async {
                        if (query.isEmpty) {
                          if (isModalOpen) {
                            modalSetState(() {
                              filteredItems = List.from(items);
                              isSearching = false;
                            });
                          }
                        } else {
                          if (isModalOpen) {
                            modalSetState(() => isSearching = true);
                          }
                          final results = await onSearch(query);
                          if (isModalOpen) {
                            modalSetState(() {
                              filteredItems = results;
                              isSearching = false;
                            });
                          }
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: isSearching
                        ? const Center(child: CircularProgressIndicator())
                        : filteredItems.isEmpty
                            ? const Center(child: Text("No results found"))
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: filteredItems.length +
                                    (hasMore && searchController.text.isEmpty
                                        ? 1
                                        : 0),
                                itemBuilder: (context, index) {
                                  if (index < filteredItems.length) {
                                    final item = filteredItems[index];
                                    bool isSelected = selectedId == item['id'];
                                    return ListTile(
                                      title: Text(item['name']),
                                      trailing: isSelected
                                          ? Icon(Icons.check,
                                              color:
                                                  context.color.territoryColor)
                                          : null,
                                      onTap: () {
                                        Navigator.pop(context);
                                        onSelected(item['id'], item['name']);
                                      },
                                    );
                                  } else {
                                    return const Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: Center(
                                          child: CircularProgressIndicator()),
                                    );
                                  }
                                },
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() => isModalOpen = false);
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide:
              BorderSide(color: context.color.territoryColor, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      controller: TextEditingController(text: value ?? ""),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.backgroundColor,
      appBar: UiUtils.buildAppBar(
        context,
        showBackButton: true,
        title: widget.editData == null
            ? "Add Address".translate(context)
            : "Edit Address".translate(context),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 300,
              child: Stack(
                children: [
                  if (centerPosition != null)
                    GoogleMap(
                      initialCameraPosition:
                          CameraPosition(target: centerPosition!, zoom: 14),
                      onMapCreated: (controller) => mapController = controller,
                      onCameraMove: (position) =>
                          centerPosition = position.target,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                    )
                  else
                    const Center(child: CircularProgressIndicator()),
                  const Center(
                      child:
                          Icon(Icons.location_on, size: 40, color: Colors.red)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDropdownField(
                    label: "Select State",
                    value: selectedStateName,
                    onTap: () {
                      _openSelectionSheet(
                        title: "Select State",
                        items: states,
                        selectedId: selectedStateId,
                        onSelected: (id, name) {
                          if (mounted) {
                            setState(() {
                              selectedStateId = id;
                              selectedStateName = name;
                              selectedCityId = null;
                              selectedCityName = null;
                              cities.clear();
                              cityPage = 1;
                              hasMoreCities = true;
                            });
                            _fetchCities(id);
                          }
                        },
                        onLoadMore: _fetchStates,
                        onSearch: _searchStates,
                        isLoading: isLoadingStates,
                        hasMore: hasMoreStates,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildDropdownField(
                    label: "Select City",
                    value: selectedCityName,
                    onTap: selectedStateId == null
                        ? null
                        : () {
                            _openSelectionSheet(
                              title: "Select City",
                              items: cities,
                              selectedId: selectedCityId,
                              onSelected: (id, name) {
                                if (mounted) {
                                  setState(() {
                                    selectedCityId = id;
                                    selectedCityName = name;
                                  });
                                }
                              },
                              onLoadMore: () => _fetchCities(selectedStateId!),
                              onSearch: (query) =>
                                  _searchCities(selectedStateId!, query),
                              isLoading: isLoadingCities,
                              hasMore: hasMoreCities,
                            );
                          },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressController,
                    decoration: InputDecoration(
                      labelText: "Address",
                      border: border,
                      enabledBorder: border,
                      focusedBorder: border.copyWith(
                        borderSide: BorderSide(
                            color: context.color.territoryColor, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: landmarkController,
                    decoration: InputDecoration(
                      labelText: "Landmark (Optional)",
                      border: border,
                      enabledBorder: border,
                      focusedBorder: border.copyWith(
                        borderSide: BorderSide(
                            color: context.color.territoryColor, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                      alignment: Alignment.centerLeft, child: Text("Save as")),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildAddressTypeButton("Home", Icons.home),
                      const SizedBox(width: 8),
                      _buildAddressTypeButton("Work", Icons.work),
                      const SizedBox(width: 8),
                      _buildAddressTypeButton("Other", Icons.location_on),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all(
                            context.color.territoryColor),
                        foregroundColor:
                            MaterialStateProperty.all(Colors.white),
                      ),
                      onPressed: _saveAddress,
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white))
                          : Text(widget.editData == null
                              ? "Save Address"
                              : "Update Address"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveAddress() {
    if (selectedStateName == null) {
      Fluttertoast.showToast(msg: "Please select state.");
      return;
    }
    if (selectedCityName == null) {
      Fluttertoast.showToast(msg: "Please select city.");
      return;
    }
    if (addressController.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: "Please enter address.");
      return;
    }

    Map<String, String> data = {
      "user_id": "${HiveUtils.getUserDetails().id}",
      "address": addressController.text,
      "state": selectedStateName ?? "",
      "city": selectedCityName ?? "",
      "addr_type": addressType,
      "latitude": centerPosition?.latitude.toString() ?? "",
      "longtitude": centerPosition?.longitude.toString() ?? "",
      "landmark": landmarkController.text,
    };

    if (widget.editData != null) {
      data["id"] = widget.editData!['id'].toString();
      _submitData("${AppSettings.baseUrl}update-address", data);
    } else {
      _submitData("${AppSettings.baseUrl}add-address", data);
    }
  }

  void _submitData(String url, Map<String, String> rawData) async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    var response = await http.post(Uri.parse(url), body: rawData);
    if (mounted) {
      setState(() => _isLoading = false);
    }

    if (response.statusCode == 200) {
      Map<String, dynamic> data = jsonDecode(response.body);
      Fluttertoast.showToast(msg: data['message']);
      Navigator.pop(context);
    }
  }

  Widget _buildAddressTypeButton(String type, IconData icon) {
    bool isSelected = addressType == type;
    return GestureDetector(
      onTap: () => setState(() => addressType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? context.color.territoryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? context.color.territoryColor : Colors.grey),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: isSelected ? context.color.territoryColor : Colors.grey),
            const SizedBox(width: 5),
            Text(type,
                style: TextStyle(
                    color: isSelected
                        ? context.color.territoryColor
                        : Colors.grey)),
          ],
        ),
      ),
    );
  }
}
