import 'package:Ziepick/data/model/home/home_screen_section.dart';
import 'package:Ziepick/utils/api.dart';
import 'package:Ziepick/data/model/data_output.dart';
import 'package:Ziepick/data/model/item/item_model.dart';
import 'dart:developer';

class HomeRepository {
  Future<List<HomeScreenSection>> fetchHome({
    String? country,
    String? state,
    String? city,
    int? areaId,
    int? radius,
    double? latitude,
    double? longitude,
  }) async {
    try {
      Map<String, dynamic> parameters = {
        // For radius-based search (when lat/long/radius present), skip city to avoid conflicts
        if (radius != null &&
            radius != "" &&
            latitude != null &&
            longitude != null) ...{
          // Use radius-based filtering
          'radius': radius,
          'latitude': latitude,
          'longitude': longitude,
          // Still send state/country for broader context, but not city
          if (country != null && country != "") 'country': country,
          if (state != null && state != "") 'state': state,
        } else ...{
          // Use location-based filtering (no radius)
          if (city != null && city != "") 'city': city,
          if (areaId != null && areaId != "") 'area_id': areaId,
          if (country != null && country != "") 'country': country,
          if (state != null && state != "") 'state': state,
          if (latitude != null && latitude != "") 'latitude': latitude,
          if (longitude != null && longitude != "") 'longitude': longitude,
        }
      };

      log('🌐 API Call - fetchHome', name: 'HomeRepository');
      log('📍 Parameters: $parameters', name: 'HomeRepository');

      Map<String, dynamic> response = await Api.get(
          url: Api.getFeaturedSectionApi, queryParameters: parameters);
      List<HomeScreenSection> homeScreenDataList =
          (response['data'] as List).map((element) {
        return HomeScreenSection.fromJson(element);
      }).toList();

      return homeScreenDataList;
    } catch (e) {
      rethrow;
    }
  }

  Future<DataOutput<ItemModel>> fetchHomeAllItems(
      {required int page,
      String? country,
      String? state,
      String? city,
      double? latitude,
      double? longitude,
      int? areaId,
      int? radius}) async {
    try {
      log('🔍 fetchHomeAllItems INPUT:', name: 'HomeRepository');
      log('   radius: $radius (type: ${radius.runtimeType})',
          name: 'HomeRepository');
      log('   latitude: $latitude', name: 'HomeRepository');
      log('   longitude: $longitude', name: 'HomeRepository');
      log('   city: $city', name: 'HomeRepository');
      log('   areaId: $areaId', name: 'HomeRepository');

      // Check conditions
      final hasRadius = radius != null && radius != 0;
      final hasCoordinates = latitude != null && longitude != null;
      final useRadiusSearch = hasRadius && hasCoordinates;

      log('   hasRadius: $hasRadius', name: 'HomeRepository');
      log('   hasCoordinates: $hasCoordinates', name: 'HomeRepository');
      log('   useRadiusSearch: $useRadiusSearch', name: 'HomeRepository');

      Map<String, dynamic> parameters = {"page": page, "sort_by": "new-to-old"};

      if (useRadiusSearch) {
        // Use radius-based filtering - SKIP city/area_id
        parameters['radius'] = radius;
        parameters['latitude'] = latitude;
        parameters['longitude'] = longitude;
        if (country != null && country != "") parameters['country'] = country;
        if (state != null && state != "") parameters['state'] = state;
        log('   ✅ Using RADIUS-based search', name: 'HomeRepository');
      } else {
        // Use location-based filtering
        if (city != null && city != "") parameters['city'] = city;
        if (areaId != null && areaId != 0) parameters['area_id'] = areaId;
        if (country != null && country != "") parameters['country'] = country;
        if (state != null && state != "") parameters['state'] = state;
        if (latitude != null) parameters['latitude'] = latitude;
        if (longitude != null) parameters['longitude'] = longitude;
        log('   ✅ Using CITY-based search', name: 'HomeRepository');
      }

      log('🌐 API Call - fetchHomeAllItems', name: 'HomeRepository');
      log('📍 Final Parameters: $parameters', name: 'HomeRepository');

      Map<String, dynamic> response =
          await Api.get(url: Api.getItemApi, queryParameters: parameters);
      List<ItemModel> items = (response['data']['data'] as List)
          .map((e) => ItemModel.fromJson(e))
          .toList();

      return DataOutput(
          total: response['data']['total'] ?? 0, modelList: items);
    } catch (error) {
      rethrow;
    }
  }

  Future<DataOutput<ItemModel>> fetchSectionItems({
    required int page,
    required int sectionId,
    String? country,
    String? state,
    String? city,
    int? areaId,
    int? radius,
    double? latitude,
    double? longitude,
  }) async {
    try {
      Map<String, dynamic> parameters = {
        "page": page,
        "featured_section_id": sectionId,
        // For radius-based search (when lat/long/radius present), skip city to avoid conflicts
        if (radius != null &&
            radius != "" &&
            latitude != null &&
            longitude != null) ...{
          // Use radius-based filtering
          'radius': radius,
          'latitude': latitude,
          'longitude': longitude,
          // Still send state/country for broader context, but not city
          if (country != null && country != "") 'country': country,
          if (state != null && state != "") 'state': state,
        } else ...{
          // Use location-based filtering (no radius)
          if (city != null && city != "") 'city': city,
          if (areaId != null && areaId != "") 'area_id': areaId,
          if (country != null && country != "") 'country': country,
          if (state != null && state != "") 'state': state,
          if (latitude != null && latitude != "") 'latitude': latitude,
          if (longitude != null && longitude != "") 'longitude': longitude,
        }
      };

      Map<String, dynamic> response =
          await Api.get(url: Api.getItemApi, queryParameters: parameters);
      List<ItemModel> items = (response['data']['data'] as List)
          .map((e) => ItemModel.fromJson(e))
          .toList();

      return DataOutput(
          total: response['data']['total'] ?? 0, modelList: items);
    } catch (error) {
      rethrow;
    }
  }
}
