# Checkout System Integration Guide

## Overview

This guide explains how to integrate the newly created checkout system into your existing Flutter eFlowers app. The checkout system implements the 3-step web checkout flow adapted for Flutter.

---

## File Structure

### New Files Created

```
lib/
├── models/
│   └── checkout.dart                    ✨ NEW - Data models
├── services/
│   └── checkout_service.dart            ✨ NEW - API service layer
├── providers/
│   └── checkout_provider.dart           ✨ NEW - State management
├── screens/
│   └── checkout/
│       ├── checkout_step1.dart          ✨ NEW - Address & time selection
│       ├── checkout_step2.dart          ✨ NEW - Order review & QR codes
│       ├── checkout_step3.dart          ✨ NEW - Payment proof upload
│       ├── checkout_modal.dart          ✨ NEW - Main checkout dialog
│       └── checkout_success.dart        ✨ NEW - Success confirmation
```

### Existing Files to Modify

- `lib/screens/cart/cart_screen.dart` - Add checkout button integration
- `pubspec.yaml` - Add dependencies
- Platform-specific: AndroidManifest.xml, Info.plist - Add permissions

---

## Step 1: Add Dependencies

Update `pubspec.yaml`:

```yaml
dependencies:
  # Existing dependencies...
  
  # Checkout dependencies
  image_picker: ^1.0.0          # Camera/gallery access
  cloudinary_flutter: ^1.0.0    # Cloudinary image upload (if using)
  table_calendar: ^3.0.0        # Calendar widget (optional, for date picker)
```

Run: `flutter pub get`

---

## Step 2: Platform-Specific Setup

### Android Setup

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

### iOS Setup

Add to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to take payment proof screenshots</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to select payment proofs</string>
```

---

## Step 3: Register Provider

In your main app file or provider setup (e.g., `lib/main.dart`):

```dart
import 'package:provider/provider.dart';
import 'providers/checkout_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Existing providers...
        ChangeNotifierProvider(create: (_) => CheckoutProvider()),
      ],
      child: MaterialApp(
        // ... rest of config
      ),
    );
  }
}
```

---

## Step 4: Integrate Cart Checkout Button

Update `lib/screens/cart/cart_screen.dart`:

```dart
import 'screens/checkout/checkout_modal.dart';  // ADD THIS

class CartScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Shopping Cart')),
      body: Column(
        children: [
          // ... existing cart items display ...
          
          // REPLACE YOUR EXISTING CHECKOUT BUTTON WITH:
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _proceedToCheckout,
              child: Text('Proceed to Checkout'),
            ),
          ),
        ],
      ),
    );
  }

  void _proceedToCheckout(BuildContext context) {
    // Gather required data
    // TODO: Replace these with your actual data sources
    final addresses = []; // Get from user profile/API
    final selectedItems = []; // Get selected cart items
    
    // Show checkout modal
    showCheckoutModal(
      context,
      addresses: addresses,
      selectedItems: selectedItems,
      onComplete: () {
        // Handle post-checkout actions
        // - Clear cart
        // - Navigate to orders
        // - Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Thanks for your order!')),
        );
      },
    );
  }
}
```

---

## Step 5: API Endpoint Configuration

Ensure your `CheckoutService` is configured with correct base URL:

In `lib/services/checkout_service.dart`, verify:

```dart
const String _baseUrl = 'YOUR_API_BASE_URL';  // Update this

// Example endpoints that should exist on backend:
// POST   /checkout/validate
// POST   /checkout/upload-proof
// POST   /checkout/create-orders
// PUT    /checkout/cart/items/{id}/toggle
```

---

## Step 6: Data Model Integration

### Address Model

Your `Address` model should match:

```dart
class Address {
  final int? id;
  final String street;
  final String municipality;
  final String barangay;
  final double latitude;
  final double longitude;
}
```

If your existing Address model is different, adapt the `checkout.dart` model to match your schema.

### Cart Item Model

Your `CartItem` should have at minimum:

```dart
class CartItem {
  final int id;
  final int storeId;
  final int productId;
  final String variantId;
  final int quantity;
  final double price;
  final bool isSelected;
}
```

---

## Step 7: Test the Integration

### Test Scenarios

1. **Happy Path**
   - Open cart
   - Select items
   - Click checkout
   - Fill address, date, time
   - Review order (verify per-store breakdown)
   - Upload payment proof
   - Confirm success

2. **Error Scenarios**
   - Network error during validation
   - Unsupported delivery address (should show error)
   - Image upload failure
   - Backend validation errors

3. **Multi-Store Scenario**
   - Add items from multiple stores to cart
   - Verify they create separate orders
   - Check per-store QR codes display

---

## Data Flow Diagram

```
CartScreen
    ↓
    └─→ showCheckoutModal()
        ↓
        └─→ CheckoutModal (Dialog)
            ├─→ CheckoutStep1 (Address & Time)
            │   ├─ User selects address
            │   ├─ User picks delivery date/time
            │   └─ Calls provider.validateCheckout()
            │       ├─ CheckoutProvider
            │       └─→ CheckoutService.validateCheckout()
            │           └─→ POST /checkout/validate
            │
            ├─→ CheckoutStep2 (Review Orders)
            │   ├─ Display validation response
            │   ├─ Show per-store breakdown
            │   └─ Display QR codes
            │
            ├─→ CheckoutStep3 (Payment Proof)
            │   ├─ User picks image
            │   ├─ Calls CheckoutService.uploadPaymentProof()
            │   │   └─→ POST /checkout/upload-proof
            │   └─ Calls provider.createOrders()
            │       └─→ CheckoutService.createOrders()
            │           └─→ POST /checkout/create-orders
            │
            └─→ CheckoutSuccess (Confirmation)
                └─ Shows order numbers and next steps
                └─ User returns to shopping
```

---

## API Contract

### Step 1: Validation

**Request:**
```json
POST /checkout/validate
{
  "address_id": 123,
  "delivery_notes": "Optional notes",
  "delivery_date": "2024-01-15",
  "delivery_time_slot": "08:00-12:00"
}
```

**Response:**
```json
{
  "success": true,
  "store_order_totals": [
    {
      "store_id": 1,
      "store_name": "Flower Shop A",
      "subtotal": 1500.00,
      "delivery_fee": 0.00,
      "total": 1500.00,
      "distance_km": 1.2,
      "can_deliver": true,
      "qr_images": ["https://...qr1.png"],
      "instructions": "Send to GCash number..."
    }
  ],
  "grand_total": 1500.00,
  "warnings": []
}
```

### Step 2: Upload Proof

**Request:** Multipart form data
```
POST /checkout/upload-proof
{
  "proof_image": <file>  // Binary file
}
```

**Response:**
```json
{
  "secure_url": "https://res.cloudinary.com/...",
  "public_id": "uploads/xyz123"
}
```

### Step 3: Create Orders

**Request:**
```json
POST /checkout/create-orders
{
  "address_id": 123,
  "delivery_notes": "...",
  "delivery_date": "2024-01-15",
  "delivery_time_slot": "08:00-12:00",
  "payment_proof_url": "https://...",
  "payment_proof_public_id": "uploads/xyz123"
}
```

**Response:**
```json
{
  "orders": [
    {
      "id": 9001,
      "customer_id": 42,
      "store_id": 1,
      "status": "pending",
      "payment_status": "pending_verification",
      "subtotal_amount": 1500.00,
      "delivery_fee": 0.00,
      "total_amount": 1500.00,
      "requested_delivery_date": "2024-01-15",
      "requested_delivery_time": "08:00-12:00",
      "payment_proof_url": "https://...",
      "payment_proof_public_id": "uploads/xyz123"
    }
  ]
}
```

---

## Customization Points

### 1. Styling

All screens use Theme colors. Customize by updating your app's theme:

```dart
MaterialApp(
  theme: ThemeData(
    primaryColor: Color(0xFFFF1493),  // Your brand color
    // ... other theme config
  ),
)
```

### 2. Time Slots

To change available time slots, edit `CheckoutService`:

```dart
static List<String> getAvailableTimeSlots() {
  return [
    "08:00-12:00",  // Modify these
    "12:00-15:00",
    "15:00-18:00",
  ];
}
```

### 3. Available Dates

To change available delivery dates, edit `CheckoutService`:

```dart
static List<String> getAvailableDeliveryDates() {
  final now = DateTime.now();
  // Modify logic here to return your desired dates
  return ['Today', 'Tomorrow', 'Jan 16'];
}
```

### 4. Image Upload Service

If not using Cloudinary, replace in `checkout_step3.dart`:

```dart
final uploadResponse = await CheckoutService.uploadPaymentProof(
  imagePath: _selectedImage!.path,
  onProgress: (progress) => setState(() => _uploadProgress = progress),
);
```

---

## Troubleshooting

### Issue: "Image Picker not working"
**Solution:** Ensure permissions added to AndroidManifest.xml and Info.plist

### Issue: "Validation returns empty response"
**Solution:** Verify API endpoint returns correct JSON structure

### Issue: "QR codes not showing"
**Solution:** Check that QR image URLs are accessible and image network timeout is sufficient

### Issue: "Provider not updating"
**Solution:** Ensure CheckoutProvider is added to MultiProvider at app root

### Issue: "State lost after navigation"
**Solution:** Use `ChangeNotifierProvider.value()` instead of `create()` in details screens

---

## Performance Considerations

- **Image Upload**: Consider compressing images before upload
- **Validation**: Add loading indicator while waiting for response
- **QR Rendering**: Images are fetched from URLs, ensure stable connection
- **State Management**: Provider automatically handles rebuilds, avoid excessive notifyListeners()

---

## Security Considerations

- Payment proof URLs should be HTTPS
- Cloudinary API key/secret should be server-side only
- Validate address coordinates on backend
- Implement rate limiting on checkout endpoints
- Sanitize delivery notes input

---

## Next Features to Consider

1. **Saved Addresses**: Let users manage multiple delivery addresses
2. **Promo Codes**: Add discount/coupon application
3. **Payment Status Polling**: Check payment verification status
4. **Order Tracking**: Real-time order status updates
5. **Receipt Generation**: PDF receipt functionality
6. **Retry Logic**: Allow resubmitting failed transactions

---

## Support & Debugging

Enable verbose logging:

```dart
import 'dart:developer' as developer;

// In CheckoutService methods:
developer.log('Validating checkout: $requestBody');

// In CheckoutProvider methods:
debugPrint('Current step: $currentStep');
```

---

**Version:** 1.0  
**Last Updated:** January 2024  
**Status:** ✅ Ready for Integration
