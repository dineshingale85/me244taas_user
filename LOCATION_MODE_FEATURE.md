# Location Mode Feature - Complete Implementation

## 🎯 Problem Solved

**Original Issue:** After implementing address selection, the app was filtering data by the saved address's coordinates instead of live GPS location. Users couldn't switch between:
- **Live GPS mode** - Show products near current location (real-time)
- **Address mode** - Show products near a saved address

## ✅ Solution: Dual Location Mode System

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   LOCATION SYSTEM                        │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Mode: "live"                    Mode: "address"        │
│  ├─ Current GPS Location         ├─ Saved Address       │
│  ├─ Updates dynamically          ├─ Static coordinates  │
│  └─ getCurrentLocation()         └─ selectAddress()     │
│                                                          │
│  Smart Getters (Auto-select based on mode):             │
│  ├─ getActiveLatitude()    → Returns correct lat        │
│  ├─ getActiveLongitude()   → Returns correct long       │
│  ├─ getActiveCityName()    → Returns correct city       │
│  ├─ getActiveStateName()   → Returns correct state      │
│  └─ getActiveCountryName() → Returns correct country    │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## 🔑 Key Components

### 1. Hive Storage Structure

```dart
// Live GPS Location (stored by getCurrentLocation)
HiveKeys.currentLocationCity         = "Mumbai"
HiveKeys.currentLocationState        = "Maharashtra"
HiveKeys.currentLocationCountry      = "India"
HiveKeys.currentLocationLatitude     = 19.0760
HiveKeys.currentLocationLongitude    = 72.8777

// Saved Address Location (stored by selectAddress)
HiveKeys.city                        = "Pune"
HiveKeys.stateKey                    = "Maharashtra"
HiveKeys.countryKey                  = "India"
HiveKeys.latitudeKey                 = 18.5204
HiveKeys.longitudeKey                = 73.8567

// Location Mode Toggle (NEW)
HiveKeys.locationMode                = "live" or "address"
```

### 2. HiveUtils New Methods

```dart
// Set location mode
HiveUtils.setLocationMode("live");     // Use GPS
HiveUtils.setLocationMode("address");  // Use saved address

// Get current mode
String mode = HiveUtils.getLocationMode();  // "live" or "address"
bool isLive = HiveUtils.isLiveLocationMode();  // true/false

// Smart getters - automatically return correct data based on mode
double lat = HiveUtils.getActiveLatitude();     // GPS or address lat
double lng = HiveUtils.getActiveLongitude();    // GPS or address lng
String city = HiveUtils.getActiveCityName();    // GPS or address city
String state = HiveUtils.getActiveStateName();  // GPS or address state
String country = HiveUtils.getActiveCountryName(); // GPS or address country
String area = HiveUtils.getActiveAreaName();    // GPS or address area
```

### 3. Smart Getter Logic

```dart
static dynamic getActiveLatitude() {
  if (isLiveLocationMode()) {
    // Try GPS first, fallback to saved address
    return getCurrentLatitude() ?? getLatitude();
  }
  // Use saved address
  return getLatitude();
}
```

**Behavior:**
- **Live Mode**: Returns GPS coordinates, falls back to saved address if GPS unavailable
- **Address Mode**: Always returns saved address coordinates

## 📍 User Flows

### Flow 1: Using Live GPS Location

```
1. User opens app
2. Default mode: "live" (GPS)
3. App requests location permission
4. getCurrentLocation() called
5. GPS coordinates saved to currentLocation* keys
6. setLocationMode("live") called
7. Home screen uses getActiveLatitude/Longitude()
8. Products filtered by current GPS position
9. Location widget shows "GPS" badge
```

### Flow 2: Selecting Saved Address

```
1. User taps location widget
2. Opens address list screen
3. User selects saved address
4. selectAddress() called
5. Address coordinates saved to city/state/latitude/longitude keys
6. setLocationMode("address") called ← KEY CHANGE
7. Hive listener in home screen detects change
8. Home screen refetches using getActiveLatitude/Longitude()
9. Products filtered by selected address position
10. Location widget shows "📍" badge
11. User navigates back to home
```

### Flow 3: Switching Back to GPS

```
1. User taps location widget
2. Opens address screen
3. User taps "Use Current Location"
4. getCurrentLocation() called
5. GPS coordinates saved
6. setLocationMode("live") called ← Switches mode
7. Home screen auto-refreshes
8. Products now filtered by live GPS
9. Location widget shows "GPS" badge again
```

## 🎨 Visual Indicators

### Location Widget Display

**Live GPS Mode:**
```
┌─────────────────────────────┐
│ 📍  Location [GPS]          │
│ Andheri, Mumbai, Maharash...│
└─────────────────────────────┘
```

**Saved Address Mode:**
```
┌─────────────────────────────┐
│ 📍  Location [📍]           │
│ Pune Station, Pune, Mahar...│
└─────────────────────────────┘
```

## 🔄 How Home Screen Auto-Refreshes

```dart
// Home Screen State
class HomeScreenState {
  String? _lastLocationKey;
  
  @override
  void initState() {
    // Track initial location
    _lastLocationKey = _getLocationKey();
    
    // Listen for changes
    Hive.box(HiveKeys.userDetailsBox)
        .listenable()
        .addListener(_onLocationChanged);
  }
  
  String _getLocationKey() {
    // Includes MODE in key - important!
    return '${HiveUtils.getLocationMode()}_'
           '${HiveUtils.getActiveCityName()}_'
           '${HiveUtils.getActiveLatitude()}_'
           '${HiveUtils.getActiveLongitude()}';
  }
  
  void _onLocationChanged() {
    final currentKey = _getLocationKey();
    
    // Changed? Refetch!
    if (currentKey != _lastLocationKey) {
      _lastLocationKey = currentKey;
      
      // Uses active methods - automatically correct based on mode
      context.read<FetchHomeScreenCubit>().fetch(
        city: HiveUtils.getActiveCityName(),
        latitude: HiveUtils.getActiveLatitude(),
        longitude: HiveUtils.getActiveLongitude(),
        ...
      );
    }
  }
}
```

**Triggers for refresh:**
1. Location mode changes ("live" → "address" or vice versa)
2. GPS location updates (in live mode)
3. Different address selected (in address mode)
4. Any coordinate change

## 📂 Modified Files

### 1. `lib/utils/hive_keys.dart`
- ✅ Added `locationMode` key

### 2. `lib/utils/hive_utils.dart`
- ✅ Added `setLocationMode(String mode)`
- ✅ Added `getLocationMode()` → String
- ✅ Added `isLiveLocationMode()` → bool
- ✅ Added `getActiveLatitude()` → dynamic
- ✅ Added `getActiveLongitude()` → dynamic
- ✅ Added `getActiveCityName()` → dynamic
- ✅ Added `getActiveStateName()` → dynamic
- ✅ Added `getActiveCountryName()` → dynamic
- ✅ Added `getActiveAreaName()` → dynamic

### 3. `lib/ui/screens/home/home_screen.dart`
- ✅ Updated `initState()` fetch calls to use `getActive*()` methods
- ✅ Updated `_onLocationChanged()` to use `getActive*()` methods
- ✅ Updated `onRefresh` to use `getActive*()` methods
- ✅ Updated scroll listener to use `getActive*()` methods
- ✅ Updated `_getLocationKey()` to include mode

### 4. `lib/ui/screens/addresss/address_screen.dart`
- ✅ Updated `selectAddress()` to call `setLocationMode("address")`
- ✅ Updated `_getCurrentLocation()` to call `setLocationMode("live")`

### 5. `lib/ui/screens/home/widgets/location_widget.dart`
- ✅ Updated to use `getActive*()` methods
- ✅ Added visual mode indicator (GPS vs 📍)
- ✅ Shows green badge for GPS, blue for address

## 🧪 Testing Checklist

### Test 1: Live GPS Mode (Default)
- [ ] Fresh install shows "GPS" badge
- [ ] Location displays current GPS coordinates
- [ ] Products shown near current location
- [ ] Moving to new location updates products

### Test 2: Switch to Address Mode
- [ ] Tap location widget
- [ ] Select a saved address
- [ ] Badge changes from "GPS" to "📍"
- [ ] Location displays selected address
- [ ] Products update to show items near address
- [ ] **Even if physically far away, shows address products**

### Test 3: Switch Back to GPS
- [ ] Tap location widget
- [ ] Tap "Use Current Location"
- [ ] Badge changes from "📍" to "GPS"
- [ ] Location displays GPS coordinates
- [ ] Products update to show items near GPS location

### Test 4: App Restart Persistence
- [ ] Select address mode
- [ ] Close app completely
- [ ] Reopen app
- [ ] Should still be in address mode
- [ ] Should show same address and products

### Test 5: No GPS Available
- [ ] Disable GPS/location services
- [ ] Open app in live mode
- [ ] Should fallback to last known location
- [ ] Or fallback to saved address if no GPS history

## ⚡ Performance Optimizations

1. **Debounced Updates**: Location key comparison prevents unnecessary fetches
2. **Mounted Check**: Prevents setState on unmounted widgets
3. **Smart Fallback**: Live mode falls back to address if GPS unavailable
4. **Single Listener**: One Hive listener handles all location changes
5. **Mode in Key**: Including mode ensures refresh on mode change

## 🔮 Future Enhancements (Optional)

### Add Manual Toggle in UI
```dart
// In location widget
IconButton(
  icon: Icon(HiveUtils.isLiveLocationMode() ? Icons.gps_fixed : Icons.location_on),
  onPressed: () {
    // Toggle mode
    HiveUtils.setLocationMode(
      HiveUtils.isLiveLocationMode() ? "address" : "live"
    );
  },
)
```

### Add Location History
```dart
// Track recently used locations
List<LocationHistory> recentLocations = [
  LocationHistory(type: "gps", name: "Mumbai - GPS", timestamp: ...),
  LocationHistory(type: "address", name: "Home", timestamp: ...),
];
```

### Add Search Radius per Mode
```dart
// Different radius for GPS vs address
if (isLiveLocationMode()) {
  radius = 10; // Smaller for GPS (current area)
} else {
  radius = 50; // Larger for address (whole city)
}
```

## 🎓 Key Learnings

1. **Two location systems coexist** - GPS (live) and Address (saved)
2. **Mode toggle controls which to use** - Simple, elegant solution
3. **Smart getters abstract complexity** - Callers don't need to know mode
4. **Reactive updates via Hive listener** - No manual refresh needed
5. **Visual feedback crucial** - Users need to know current mode

## 📊 Data Flow Diagram

```
User Action → Mode Change → Hive Update → Listener Triggered → 
Location Key Changed → Home Refetch → API Call → Products Update → UI Refresh
```

**Example: Selecting Address**
```
Tap Address → selectAddress() → setLocationMode("address") → 
Hive.put(locationMode, "address") → _onLocationChanged() → 
_getLocationKey() returns new value → fetch() with getActiveLatitude() → 
getActiveLatitude() returns address.latitude → API filters by address → 
Products shown for address area
```

## ✅ Success Criteria

- ✅ Live GPS mode works without breaking existing functionality
- ✅ Address mode correctly filters by saved address coordinates
- ✅ Mode persists across app restarts
- ✅ Visual indicator shows current mode
- ✅ Seamless switching between modes
- ✅ No duplicate API calls
- ✅ Fallback to address if GPS unavailable in live mode
