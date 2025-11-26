# Radius & Location Filtering - Complete Explanation

## 🔴 The Problem You Reported

**Issue**: "Still can't see the data after selecting address"

## 🔍 Root Cause Analysis

### Original Flawed API Logic

```dart
// BEFORE (BROKEN):
Map<String, dynamic> parameters = {
  if (radius == null) {
    // Send city, state, country
    'city': city,
    'state': state,
    'country': country,
  } else {
    // ONLY send radius + lat/long (NO city/state/country!)
  },
  if (radius != null) 'radius': radius,
  'latitude': latitude,
  'longitude': longitude,
};
```

**Problem**: This is **mutually exclusive**!
- If `radius` exists → Backend gets ONLY coordinates + radius (no location names)
- If `radius` is null → Backend gets ONLY location names (no radius filtering)

### Your Backend Likely Works Like This

**Backend API Filtering Logic (typical implementation):**

```sql
-- Option 1: Radius-based search (distance from point)
SELECT * FROM items 
WHERE ST_Distance_Sphere(
    POINT(longitude, latitude), 
    POINT(?, ?)  -- user's coordinates
) <= ? * 1000  -- radius in km converted to meters

-- Option 2: Location-based search (city/state match)
SELECT * FROM items 
WHERE city = ? 
  AND state = ? 
  AND country = ?

-- Option 3: HYBRID (what you probably need)
SELECT * FROM items 
WHERE city = ?  -- Narrow down to city first
  AND ST_Distance_Sphere(
      POINT(longitude, latitude), 
      POINT(?, ?)
  ) <= ? * 1000  -- Then filter by radius within city
```

**Most backends expect BOTH**:
- City/State/Country → Narrow down region
- Radius + Lat/Long → Fine-tune within that region

## ✅ The Fix

### New API Logic (FIXED)

```dart
// AFTER (WORKING):
Map<String, dynamic> parameters = {
  // ALWAYS send location data if available
  if (city != null && city != "") 'city': city,
  if (areaId != null && areaId != "") 'area_id': areaId,
  if (country != null && country != "") 'country': country,
  if (state != null && state != "") 'state': state,
  
  // ALSO send radius + coordinates for distance filtering
  if (radius != null && radius != "") 'radius': radius,
  if (latitude != null && latitude != "") 'latitude': latitude,
  if (longitude != null && longitude != "") 'longitude': longitude,
};
```

**Now sends BOTH**:
✅ City, State, Country, Area ID
✅ Radius, Latitude, Longitude

## 📊 API Request Examples

### Scenario 1: Live GPS Mode
```
User at: Mumbai (19.0760, 72.8777)
Radius: 50 km
```

**API Request:**
```json
{
  "city": "Mumbai",
  "state": "Maharashtra", 
  "country": "India",
  "latitude": 19.0760,
  "longitude": 72.8777,
  "radius": 50
}
```

**Backend Response:**
- Items in Mumbai city
- Within 50km of coordinates (19.0760, 72.8777)
- **Result**: Products near your current GPS location ✅

### Scenario 2: Saved Address Mode
```
User physically in: Mumbai
Selected address: Pune (18.5204, 73.8567)
Radius: 50 km
```

**API Request:**
```json
{
  "city": "Pune",
  "state": "Maharashtra",
  "country": "India", 
  "latitude": 18.5204,
  "longitude": 73.8567,
  "radius": 50
}
```

**Backend Response:**
- Items in Pune city
- Within 50km of Pune coordinates
- **Result**: Products in Pune (even though you're in Mumbai) ✅

### Scenario 3: No Radius Set
```
User selected: Delhi
Radius: null (not set)
```

**API Request:**
```json
{
  "city": "Delhi",
  "state": "Delhi",
  "country": "India",
  "latitude": 28.7041,
  "longitude": 77.1025
}
```

**Backend Response:**
- All items in Delhi (no radius filtering)
- **Result**: All Delhi products ✅

## 🎯 How Radius Actually Works

### What is Radius?

**Radius = Distance filter in kilometers**

```
Your Location (Lat/Long)
         |
         | radius = 50 km
         ↓
    [50km circle]
    Items within this circle
```

### Radius Values in Your App

```dart
// Set by user in nearby_location.dart
HiveUtils.setNearbyRadius(50);  // 50 km

// Retrieved everywhere
int radius = HiveUtils.getNearbyRadius();  // Returns 50

// Min/Max from backend settings
Constant.minRadius = "10";  // Minimum 10 km
Constant.maxRadius = "500"; // Maximum 500 km
```

### Default Radius Behavior

**If user never set radius:**
```dart
HiveUtils.getNearbyRadius()  // Returns null or default

// Backend behavior:
if (radius == null) {
  // Show all items in city (no distance filter)
} else {
  // Show items within radius km
}
```

## 🔄 Data Flow with New Fix

### 1. User Selects Address

```
Address Screen
    ↓
selectAddress() called
    ↓
HiveUtils.setLocation(
  city: "Pune",
  latitude: 18.5204,
  longitude: 73.8567
)
    ↓
HiveUtils.setLocationMode("address")
    ↓
Hive listener detects change
    ↓
Home screen refetches
    ↓
FetchHomeScreenCubit.fetch(
  city: "Pune",              ← From address
  state: "Maharashtra",      ← From address
  latitude: 18.5204,         ← From address
  longitude: 73.8567,        ← From address
  radius: 50                 ← From saved preference
)
    ↓
HomeRepository.fetchHome()
    ↓
API Request with ALL parameters:
{
  "city": "Pune",
  "state": "Maharashtra",
  "country": "India",
  "latitude": 18.5204,
  "longitude": 73.8567,
  "radius": 50
}
    ↓
Backend filters:
- Items in Pune
- Within 50km of coordinates
    ↓
Returns products
    ↓
Home screen displays data ✅
```

## 🐛 Debugging Guide

### Check What's Being Sent to API

**Added debug logs in HomeRepository:**

```dart
log('🌐 API Call - fetchHome', name: 'HomeRepository');
log('📍 Parameters: $parameters', name: 'HomeRepository');
```

**In your console/logcat, look for:**
```
[HomeRepository] 🌐 API Call - fetchHome
[HomeRepository] 📍 Parameters: {
  city: Pune, 
  state: Maharashtra, 
  country: India, 
  latitude: 18.5204, 
  longitude: 73.8567, 
  radius: 50
}
```

### Common Issues & Solutions

#### Issue 1: No data showing after selecting address
**Check:**
```
✓ Is city sent in API? 
✓ Is latitude/longitude sent?
✓ Is radius sent?
✓ Are coordinates correct for selected address?
```

**Debug:**
```dart
// In home_screen.dart _onLocationChanged()
log('City: ${HiveUtils.getActiveCityName()}');
log('Lat: ${HiveUtils.getActiveLatitude()}');
log('Long: ${HiveUtils.getActiveLongitude()}');
log('Radius: ${HiveUtils.getNearbyRadius()}');
log('Mode: ${HiveUtils.getLocationMode()}');
```

#### Issue 2: Shows wrong location's data
**Check:**
```
✓ Location mode correct? (GPS vs address)
✓ Coordinates match selected location?
✓ Did Hive listener trigger?
```

**Debug:**
```dart
// Check what location is active
print('Mode: ${HiveUtils.getLocationMode()}');
print('GPS City: ${HiveUtils.getCurrentCityName()}');
print('Address City: ${HiveUtils.getCityName()}');
print('Active City: ${HiveUtils.getActiveCityName()}');
```

#### Issue 3: No radius filtering happening
**Check:**
```
✓ Is radius value set in Hive?
✓ Is radius being passed to API?
✓ Does backend support radius parameter?
```

**Debug:**
```dart
int? radius = HiveUtils.getNearbyRadius();
print('Radius value: $radius');  // Should not be null

// If null, set default:
if (radius == null) {
  HiveUtils.setNearbyRadius(50);  // 50 km default
}
```

## 📱 Testing Checklist

### Test 1: Address Mode with Radius
```
1. Open app
2. Tap location widget
3. Select address in different city
4. Check console logs:
   ✓ city parameter = selected city
   ✓ latitude/longitude = address coordinates
   ✓ radius = user's preference (e.g., 50)
5. Verify products shown are from selected city
```

### Test 2: GPS Mode with Radius
```
1. Open app
2. Tap location widget  
3. Tap "Use Current Location"
4. Check console logs:
   ✓ city parameter = current GPS city
   ✓ latitude/longitude = current GPS coordinates
   ✓ radius = user's preference
5. Verify products shown are near current location
```

### Test 3: Radius Adjustment
```
1. Open Nearby Location screen
2. Adjust radius slider (e.g., 10km to 100km)
3. Save
4. Check home screen updates with new radius
5. Verify fewer/more products based on radius change
```

## 🔧 Modified Files

### 1. `home_repository.dart`
**Changed**: Removed mutually exclusive logic
**Now**: Sends BOTH location names AND radius+coordinates

**Impact**: Backend receives complete information for proper filtering

### Files Using This Repository:
- `FetchHomeScreenCubit` → Home screen sections
- `FetchHomeAllItemsCubit` → All items list
- `FetchSectionItemsCubit` → Section-specific items

## 💡 Backend Integration Notes

### If Backend Doesn't Support Both Parameters

**Option A: Backend prefers radius (distance-based)**
```dart
// Don't send city/state, only coordinates + radius
Map<String, dynamic> parameters = {
  'latitude': latitude,
  'longitude': longitude,
  'radius': radius,
};
```

**Option B: Backend prefers location names**
```dart
// Don't send radius, only city/state/country
Map<String, dynamic> parameters = {
  'city': city,
  'state': state,
  'country': country,
};
```

**Option C: Mode-based (current implementation)**
```dart
// Send everything, let backend decide priority
Map<String, dynamic> parameters = {
  'city': city,
  'state': state,
  'country': country,
  'latitude': latitude,
  'longitude': longitude,
  'radius': radius,
};
```

### Backend Filtering Priority (typical)

```
Priority 1: Radius + Coordinates (most specific)
    ↓ If no results or radius null
Priority 2: City + State (medium specific)
    ↓ If no results
Priority 3: State only (broader)
    ↓ If no results
Priority 4: Country (broadest)
```

## ✅ Success Criteria

After this fix, you should see:

✅ Data loads when selecting address  
✅ Data shows products from selected location (not GPS)  
✅ Radius filtering works correctly  
✅ Console logs show all parameters being sent  
✅ Switching between GPS/Address modes works smoothly  
✅ Products update based on location change  

## 🎓 Key Takeaways

1. **Don't make parameters mutually exclusive** - Send all available data
2. **Radius = distance filter** - Not a replacement for location
3. **Backend needs context** - Both location names AND coordinates
4. **Debug with logs** - Always check what's actually sent to API
5. **Mode matters** - GPS vs Address changes which coordinates to use

## 📞 Still No Data? Check These

1. **Backend API response** - Is it returning empty array?
2. **Coordinates valid?** - Are lat/long actually for selected city?
3. **Radius too small?** - Try increasing to 100km for testing
4. **Backend filtering** - Does your backend actually use these parameters?
5. **Data exists?** - Are there actually items in that city on backend?

**Quick Test:**
```dart
// Temporarily hardcode known good values
context.read<FetchHomeScreenCubit>().fetch(
  city: "Mumbai",
  state: "Maharashtra",
  country: "India",
  latitude: 19.0760,
  longitude: 72.8777,
  radius: 100,  // Large radius
);

// If this shows data → Your coordinates/city names might be wrong
// If this shows no data → Backend might have no items or different API contract
```
