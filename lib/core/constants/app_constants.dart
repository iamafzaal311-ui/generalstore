/// Production-ready constants for the entire application
///
/// This file contains all hardcoded strings, numbers, and constants used throughout
/// the application. Centralizing constants makes maintenance and updates easier.

library app_constants;

// ============================================================================
// APPLICATION METADATA & BRANDING
// ============================================================================

const String appName = 'HASNAIN TRADERS';

/// Application version
const String appVersion = '1.0.0';

/// Current environment
enum AppEnvironment { development, staging, production }

const AppEnvironment appEnvironment = AppEnvironment.production;

/// Store Branding
abstract class StoreDetails {
  static const String name = 'حسنین ٹریڈرز';
  static const String nameEnglish = 'HASNAIN TRADERS';
  static const String proprietor = 'علی عباس';
  static const String proprietorEnglish = 'Ali Abbas';
  static const String contact = '0307-4217267';
  static const String address = 'غوثیہ مارکیٹ سکندر چوک پاک پتن';
}

// ============================================================================
// FIREBASE CONFIGURATION
// ============================================================================

/// Firebase collections names
abstract class FirestoreCollections {
  static const String users = 'users';
  static const String products = 'products';
  static const String categories = 'categories';
  static const String suppliers = 'suppliers';
  static const String customers = 'customers';
  static const String purchases = 'purchases';
  static const String sales = 'sales';
  static const String expenses = 'expenses';
  static const String returns = 'returns';
  static const String inventory = 'inventory';
  static const String notifications = 'notifications';
  static const String invoices = 'invoices';
  static const String settings = 'settings';
}

// ============================================================================
// STORAGE KEYS
// ============================================================================

abstract class AppConstants {
  static const String appName = 'HASNAIN TRADERS';
  static const String appNameOld = 'Al-Makkah General Store';
  static const String appVersionOld = '1.0.0';
  static const String themeKey = 'app_theme_mode';
  static const String currentUserKey = 'current_session_user';
  static const String localDbName = 'generalstore_offline_db';
}

// ============================================================================
// ROLE-BASED ACCESS CONTROL
// ============================================================================

abstract class UserRoles {
  static const String admin = 'Admin';
  static const String staff = 'Staff';

  static const List<String> allRoles = [admin, staff];

  static bool isAdmin(String role) => role == admin;
  static bool canSell(String role) => role == admin || role == staff;
  static bool canManageInventory(String role) => role == admin;
  static bool canViewReports(String role) => role == admin;
  static bool canManageUsers(String role) => role == admin;
}

// ============================================================================
// BUSINESS LOGIC CONSTANTS
// ============================================================================

/// Product units
abstract class ProductUnits {
  static const String piece = 'piece';
  static const String kg = 'kg';
  static const String liter = 'liter';
  static const String meter = 'meter';
  static const String pack = 'pack';
  static const String dozen = 'dozen';
  static const String box = 'box';

  static const List<String> all = [piece, kg, liter, meter, pack, dozen, box];
}

/// Payment methods
abstract class PaymentMethods {
  static const String cash = 'cash';
  static const String card = 'card';
  static const String cheque = 'cheque';
  static const String mobileMoney = 'mobile_money';
  static const String bank = 'bank';
  static const String credit = 'credit';

  static const List<String> all = [
    cash,
    card,
    cheque,
    mobileMoney,
    bank,
    credit,
  ];
}

/// Transaction status
abstract class TransactionStatus {
  static const String pending = 'pending';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
  static const String partial = 'partial';

  static const List<String> all = [pending, completed, cancelled, partial];
}

// ============================================================================
// UI/UX CONSTANTS
// ============================================================================

/// Standard spacing values (in pixels)
abstract class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

/// Border radius values
abstract class AppBorderRadius {
  static const double xs = 2.0;
  static const double sm = 4.0;
  static const double md = 8.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
  static const double xxl = 24.0;
  static const double full = 100.0;
}

/// Responsive breakpoints (in logical pixels)
abstract class ResponsiveBreakpoints {
  static const double mobile = 480;
  static const double tablet = 768;
  static const double desktop = 1200;
  static const double largeDesktop = 1920;
}

/// Animation durations
abstract class AppDurations {
  static const Duration veryFast = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration verySlow = Duration(milliseconds: 800);
}

// ============================================================================
// VALIDATION CONSTANTS
// ============================================================================

/// Regular expressions for validation
abstract class ValidationPatterns {
  static const String email =
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  static const String phone = r'^(\+92|0)[0-9]{10}$';
  static const String username = r'^[a-zA-Z0-9_]{3,20}$';
  static const String sku = r'^[A-Z0-9-_]{3,20}$';
  static const String barcode = r'^[0-9]{8,14}$';
}

/// Validation error messages
abstract class ValidationMessages {
  static const String emailInvalid = 'Please enter a valid email address';
  static const String phoneInvalid = 'Please enter a valid phone number';
  static const String usernameInvalid = 'Username must be 3-20 characters';
  static const String passwordWeak = 'Password must be at least 8 characters';
  static const String fieldRequired = 'This field is required';
  static const String skuInvalid = 'Invalid SKU format';
  static const String barcodeInvalid = 'Invalid barcode format';
  static const String priceInvalid = 'Please enter a valid price';
  static const String quantityInvalid = 'Please enter a valid quantity';
}

// ============================================================================
// ERROR MESSAGES
// ============================================================================

abstract class ErrorMessages {
  static const String networkError =
      'Network connection error. Please check your internet.';
  static const String serverError = 'Server error. Please try again later.';
  static const String unauthorizedError = 'Unauthorized. Please login again.';
  static const String notFoundError = 'Resource not found.';
  static const String conflictError = 'This resource already exists.';
  static const String validationError = 'Please check your input.';
  static const String unknownError = 'Something went wrong. Please try again.';
  static const String offlineError =
      'You are offline. Some features may not work.';
  static const String timeoutError = 'Request timed out. Please try again.';
}

// ============================================================================
// SUCCESS MESSAGES
// ============================================================================

abstract class SuccessMessages {
  static const String saveSuccess = 'Saved successfully';
  static const String deleteSuccess = 'Deleted successfully';
  static const String updateSuccess = 'Updated successfully';
  static const String loginSuccess = 'Login successful';
  static const String logoutSuccess = 'Logout successful';
  static const String createSuccess = 'Created successfully';
  static const String backupSuccess = 'Backup completed successfully';
  static const String restoreSuccess = 'Restore completed successfully';
}

// ============================================================================
// PAGINATION
// ============================================================================

abstract class PaginationConstants {
  static const int pageSize = 20;
  static const int initialPage = 1;
  static const int maxRetries = 3;
}

// ============================================================================
// LIMITS & CONSTRAINTS
// ============================================================================

abstract class BusinessLimits {
  static const double maxDiscountPercent = 100.0;
  static const double maxPrice = 999999.99;
  static const int lowStockThreshold = 5;
  static const int maxItemsPerSale = 100;
  static const int maxFileUploadSize = 5 * 1024 * 1024;
  static const int maxBackupFileSize = 50 * 1024 * 1024;
}
