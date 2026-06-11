import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @helloWorld.
  ///
  /// In en, this message translates to:
  /// **'Hello World!'**
  String get helloWorld;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Dios Délices'**
  String get appTitle;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get welcome;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your account has been created.\nDiscover the best homemade dishes near you.'**
  String get welcomeSubtitle;

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @modify.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get modify;

  /// No description provided for @validate.
  ///
  /// In en, this message translates to:
  /// **'Validate'**
  String get validate;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @cart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @mySpace.
  ///
  /// In en, this message translates to:
  /// **'My Space'**
  String get mySpace;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @boutique.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get boutique;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @signup.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signup;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get lastName;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get loginFailed;

  /// No description provided for @loginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Logged in successfully'**
  String get loginSuccess;

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get logoutConfirm;

  /// No description provided for @verificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get verificationCode;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCode;

  /// No description provided for @connectError.
  ///
  /// In en, this message translates to:
  /// **'Connection error. Check your network.'**
  String get connectError;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit my information'**
  String get editProfile;

  /// No description provided for @editProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit my profile'**
  String get editProfileTitle;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @allFieldsRequired.
  ///
  /// In en, this message translates to:
  /// **'All fields are required'**
  String get allFieldsRequired;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMinLength;

  /// No description provided for @passwordsNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsNotMatch;

  /// No description provided for @incorrectCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect current password'**
  String get incorrectCurrentPassword;

  /// No description provided for @passwordChangedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully'**
  String get passwordChangedSuccess;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhoto;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// No description provided for @enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @testNotifications.
  ///
  /// In en, this message translates to:
  /// **'Test notifications'**
  String get testNotifications;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'This action is irreversible. All your personal data and orders will be permanently deleted.\n\nAre you sure you want to continue?'**
  String get deleteAccountWarning;

  /// No description provided for @softDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account will be deactivated now and permanently deleted in 30 days. Your restaurants, dishes and orders will be hidden.'**
  String get softDeleteMessage;

  /// No description provided for @legalInfo.
  ///
  /// In en, this message translates to:
  /// **'Legal information'**
  String get legalInfo;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of service'**
  String get termsOfService;

  /// No description provided for @legalNotice.
  ///
  /// In en, this message translates to:
  /// **'Legal notice'**
  String get legalNotice;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @myRestaurant.
  ///
  /// In en, this message translates to:
  /// **'My restaurant'**
  String get myRestaurant;

  /// No description provided for @createRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Create my restaurant'**
  String get createRestaurant;

  /// No description provided for @restaurantName.
  ///
  /// In en, this message translates to:
  /// **'Restaurant name'**
  String get restaurantName;

  /// No description provided for @restaurantDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get restaurantDescription;

  /// No description provided for @restaurantAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get restaurantAddress;

  /// No description provided for @openingHours.
  ///
  /// In en, this message translates to:
  /// **'Opening hours'**
  String get openingHours;

  /// No description provided for @openingDays.
  ///
  /// In en, this message translates to:
  /// **'Opening days'**
  String get openingDays;

  /// No description provided for @deliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee'**
  String get deliveryFee;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhoto;

  /// No description provided for @pendingValidation.
  ///
  /// In en, this message translates to:
  /// **'Pending validation'**
  String get pendingValidation;

  /// No description provided for @validated.
  ///
  /// In en, this message translates to:
  /// **'Validated'**
  String get validated;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @becomeRestaurateur.
  ///
  /// In en, this message translates to:
  /// **'Become a home chef'**
  String get becomeRestaurateur;

  /// No description provided for @recoveryModes.
  ///
  /// In en, this message translates to:
  /// **'Recovery modes'**
  String get recoveryModes;

  /// No description provided for @delivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get delivery;

  /// No description provided for @pickup.
  ///
  /// In en, this message translates to:
  /// **'Pick & Collect'**
  String get pickup;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// No description provided for @restaurantPendingBanner.
  ///
  /// In en, this message translates to:
  /// **'Your restaurant is being reviewed by our administrators. You will be able to manage your restaurant, add dishes and receive orders once it is validated.'**
  String get restaurantPendingBanner;

  /// No description provided for @noRestaurant.
  ///
  /// In en, this message translates to:
  /// **'No restaurant'**
  String get noRestaurant;

  /// No description provided for @createRestaurantPrompt.
  ///
  /// In en, this message translates to:
  /// **'Create your restaurant to start selling your dishes.'**
  String get createRestaurantPrompt;

  /// No description provided for @addDish.
  ///
  /// In en, this message translates to:
  /// **'Add dish'**
  String get addDish;

  /// No description provided for @dishName.
  ///
  /// In en, this message translates to:
  /// **'Dish name'**
  String get dishName;

  /// No description provided for @dishDescription.
  ///
  /// In en, this message translates to:
  /// **'Dish description'**
  String get dishDescription;

  /// No description provided for @dishPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get dishPrice;

  /// No description provided for @servings.
  ///
  /// In en, this message translates to:
  /// **'Servings'**
  String get servings;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @addOption.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get addOption;

  /// No description provided for @options.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get options;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @mainPhoto.
  ///
  /// In en, this message translates to:
  /// **'Main photo'**
  String get mainPhoto;

  /// No description provided for @secondaryPhoto.
  ///
  /// In en, this message translates to:
  /// **'Secondary photo'**
  String get secondaryPhoto;

  /// No description provided for @noOptions.
  ///
  /// In en, this message translates to:
  /// **'No options'**
  String get noOptions;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @myOrders.
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get myOrders;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmed;

  /// No description provided for @delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get delivered;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @orderConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Order confirmed'**
  String get orderConfirmed;

  /// No description provided for @noOrders.
  ///
  /// In en, this message translates to:
  /// **'No orders'**
  String get noOrders;

  /// No description provided for @noOrderReceived.
  ///
  /// In en, this message translates to:
  /// **'No orders received.'**
  String get noOrderReceived;

  /// No description provided for @noOrderFound.
  ///
  /// In en, this message translates to:
  /// **'No orders found.'**
  String get noOrderFound;

  /// No description provided for @users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get users;

  /// No description provided for @restaurants.
  ///
  /// In en, this message translates to:
  /// **'Restaurants'**
  String get restaurants;

  /// No description provided for @livreurs.
  ///
  /// In en, this message translates to:
  /// **'Drivers'**
  String get livreurs;

  /// No description provided for @administrators.
  ///
  /// In en, this message translates to:
  /// **'Administrators'**
  String get administrators;

  /// No description provided for @auditLog.
  ///
  /// In en, this message translates to:
  /// **'Audit Log'**
  String get auditLog;

  /// No description provided for @supportChat.
  ///
  /// In en, this message translates to:
  /// **'Support Messaging'**
  String get supportChat;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @stats.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get stats;

  /// No description provided for @revenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenue;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get quickActions;

  /// No description provided for @management.
  ///
  /// In en, this message translates to:
  /// **'Management'**
  String get management;

  /// No description provided for @chatWithUsers.
  ///
  /// In en, this message translates to:
  /// **'Chat with users'**
  String get chatWithUsers;

  /// No description provided for @auditTrail.
  ///
  /// In en, this message translates to:
  /// **'Action trail'**
  String get auditTrail;

  /// No description provided for @addUser.
  ///
  /// In en, this message translates to:
  /// **'Add user'**
  String get addUser;

  /// No description provided for @addAdmin.
  ///
  /// In en, this message translates to:
  /// **'Add administrator'**
  String get addAdmin;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @rejectReason.
  ///
  /// In en, this message translates to:
  /// **'Reject reason'**
  String get rejectReason;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get contact;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @noConversation.
  ///
  /// In en, this message translates to:
  /// **'No conversation'**
  String get noConversation;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @yourMessage.
  ///
  /// In en, this message translates to:
  /// **'Your message...'**
  String get yourMessage;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @session.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get session;

  /// No description provided for @noInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noInternet;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @demandReceived.
  ///
  /// In en, this message translates to:
  /// **'Request sent!'**
  String get demandReceived;

  /// No description provided for @demandSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your restaurant request has been received.'**
  String get demandSubtitle;

  /// No description provided for @comeBackHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get comeBackHome;

  /// No description provided for @refreshStatus.
  ///
  /// In en, this message translates to:
  /// **'Refresh status'**
  String get refreshStatus;

  /// No description provided for @mySales.
  ///
  /// In en, this message translates to:
  /// **'My sales'**
  String get mySales;

  /// No description provided for @myProducts.
  ///
  /// In en, this message translates to:
  /// **'My products'**
  String get myProducts;

  /// No description provided for @myDeliveries.
  ///
  /// In en, this message translates to:
  /// **'My deliveries'**
  String get myDeliveries;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @comment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get comment;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @thankYou.
  ///
  /// In en, this message translates to:
  /// **'Thank you!'**
  String get thankYou;

  /// No description provided for @restaurantDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted restaurant'**
  String get restaurantDeleted;

  /// No description provided for @accountDeactivated.
  ///
  /// In en, this message translates to:
  /// **'Account deactivated. Permanent deletion in 30 days.'**
  String get accountDeactivated;

  /// No description provided for @accountBeingDeleted.
  ///
  /// In en, this message translates to:
  /// **'This account is being deleted.'**
  String get accountBeingDeleted;

  /// No description provided for @splash_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Homemade dishes, delivered to you'**
  String get splash_subtitle;

  /// No description provided for @splash_loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get splash_loading;

  /// No description provided for @onboarding_step_1_title.
  ///
  /// In en, this message translates to:
  /// **'Discover homemade flavors near you'**
  String get onboarding_step_1_title;

  /// No description provided for @onboarding_step_1_body.
  ///
  /// In en, this message translates to:
  /// **'Discover the best homemade dishes near you, prepared with passion.'**
  String get onboarding_step_1_body;

  /// No description provided for @onboarding_step_2_title.
  ///
  /// In en, this message translates to:
  /// **'Order easily, wherever you are'**
  String get onboarding_step_2_title;

  /// No description provided for @onboarding_step_2_body.
  ///
  /// In en, this message translates to:
  /// **'Browse menus, track your cart, and quickly find your favorite dishes.'**
  String get onboarding_step_2_body;

  /// No description provided for @onboarding_step_3_title.
  ///
  /// In en, this message translates to:
  /// **'Sell your dishes with confidence'**
  String get onboarding_step_3_title;

  /// No description provided for @onboarding_step_3_body.
  ///
  /// In en, this message translates to:
  /// **'Create your restaurant space, publish your dishes, and manage orders from the app.'**
  String get onboarding_step_3_body;

  /// No description provided for @already_have_account.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get already_have_account;

  /// No description provided for @signup_title.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signup_title;

  /// No description provided for @signup_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account, discover restaurants near you and launch your business with greater peace of mind.'**
  String get signup_subtitle;

  /// No description provided for @login_title.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login_title;

  /// No description provided for @login_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Find your space, your orders and your restaurant in seconds.'**
  String get login_subtitle;

  /// No description provided for @login_failed.
  ///
  /// In en, this message translates to:
  /// **'Invalid credentials'**
  String get login_failed;

  /// No description provided for @dont_have_account.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account ? Sign up'**
  String get dont_have_account;

  /// No description provided for @firstname.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstname;

  /// No description provided for @enter_firstname.
  ///
  /// In en, this message translates to:
  /// **'Enter your first name'**
  String get enter_firstname;

  /// No description provided for @lastname.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastname;

  /// No description provided for @enter_lastname.
  ///
  /// In en, this message translates to:
  /// **'Enter your last name'**
  String get enter_lastname;

  /// No description provided for @enter_username.
  ///
  /// In en, this message translates to:
  /// **'Enter your username'**
  String get enter_username;

  /// No description provided for @enter_valid_email.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get enter_valid_email;

  /// No description provided for @phone_number.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phone_number;

  /// No description provided for @enter_phone.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get enter_phone;

  /// No description provided for @benin_phone_format.
  ///
  /// In en, this message translates to:
  /// **'Format: 8 digits'**
  String get benin_phone_format;

  /// No description provided for @new_password.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get new_password;

  /// No description provided for @confirm_password.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirm_password;

  /// No description provided for @confirm_password_required.
  ///
  /// In en, this message translates to:
  /// **'Confirmation required'**
  String get confirm_password_required;

  /// No description provided for @passwords_do_not_match.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwords_do_not_match;

  /// No description provided for @enter_password.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enter_password;

  /// No description provided for @min_4_chars.
  ///
  /// In en, this message translates to:
  /// **'Min 4 characters'**
  String get min_4_chars;

  /// No description provided for @min_6_chars.
  ///
  /// In en, this message translates to:
  /// **'Min 6 characters'**
  String get min_6_chars;

  /// No description provided for @max_18_chars.
  ///
  /// In en, this message translates to:
  /// **'Max 18 characters'**
  String get max_18_chars;

  /// No description provided for @username_or_email.
  ///
  /// In en, this message translates to:
  /// **'Username or email'**
  String get username_or_email;

  /// No description provided for @user_not_found.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get user_not_found;

  /// No description provided for @forgotten_password.
  ///
  /// In en, this message translates to:
  /// **'Forgot password ?'**
  String get forgotten_password;

  /// No description provided for @forgotten_password_title.
  ///
  /// In en, this message translates to:
  /// **'Forgot password'**
  String get forgotten_password_title;

  /// No description provided for @forgotten_password_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to receive a code'**
  String get forgotten_password_subtitle;

  /// No description provided for @reset_password.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get reset_password;

  /// No description provided for @reset_password_title.
  ///
  /// In en, this message translates to:
  /// **'Forgot password'**
  String get reset_password_title;

  /// No description provided for @reset_password_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to reset'**
  String get reset_password_subtitle;

  /// No description provided for @no_account_for_email.
  ///
  /// In en, this message translates to:
  /// **'No account for this email'**
  String get no_account_for_email;

  /// No description provided for @reset_code_send_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send code'**
  String get reset_code_send_failed;

  /// No description provided for @reset_code_sent.
  ///
  /// In en, this message translates to:
  /// **'Code sent!'**
  String get reset_code_sent;

  /// No description provided for @invalid_or_expired_code.
  ///
  /// In en, this message translates to:
  /// **'Invalid or expired code'**
  String get invalid_or_expired_code;

  /// No description provided for @verify_code.
  ///
  /// In en, this message translates to:
  /// **'Verify code'**
  String get verify_code;

  /// No description provided for @verify_email.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get verify_email;

  /// No description provided for @password_requirement_hint.
  ///
  /// In en, this message translates to:
  /// **'Min 8 chars, 1 upper, 1 digit, 1 special'**
  String get password_requirement_hint;

  /// No description provided for @min_8_chars.
  ///
  /// In en, this message translates to:
  /// **'8 chars min.'**
  String get min_8_chars;

  /// No description provided for @require_uppercase.
  ///
  /// In en, this message translates to:
  /// **'1 uppercase'**
  String get require_uppercase;

  /// No description provided for @require_3_digits.
  ///
  /// In en, this message translates to:
  /// **'3 digits'**
  String get require_3_digits;

  /// No description provided for @require_special.
  ///
  /// In en, this message translates to:
  /// **'1 special char'**
  String get require_special;

  /// No description provided for @internet_required.
  ///
  /// In en, this message translates to:
  /// **'Internet connection required'**
  String get internet_required;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @cart_title.
  ///
  /// In en, this message translates to:
  /// **'Your Cart'**
  String get cart_title;

  /// No description provided for @cart_empty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get cart_empty;

  /// No description provided for @cart_empty_hint.
  ///
  /// In en, this message translates to:
  /// **'Add homemade dishes!'**
  String get cart_empty_hint;

  /// No description provided for @cart_delivery_option_delivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get cart_delivery_option_delivery;

  /// No description provided for @cart_delivery_option_takeaway.
  ///
  /// In en, this message translates to:
  /// **'Takeaway'**
  String get cart_delivery_option_takeaway;

  /// No description provided for @cart_delivery_section.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get cart_delivery_section;

  /// No description provided for @cart_change_address.
  ///
  /// In en, this message translates to:
  /// **'Change address'**
  String get cart_change_address;

  /// No description provided for @cart_choose_address.
  ///
  /// In en, this message translates to:
  /// **'Choose address'**
  String get cart_choose_address;

  /// No description provided for @cart_promo_section.
  ///
  /// In en, this message translates to:
  /// **'Promo code'**
  String get cart_promo_section;

  /// No description provided for @cart_promo_hint.
  ///
  /// In en, this message translates to:
  /// **'Ex: WELCOME10'**
  String get cart_promo_hint;

  /// No description provided for @cart_promo_apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get cart_promo_apply;

  /// No description provided for @cart_promo_invalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid promo code.'**
  String get cart_promo_invalid;

  /// No description provided for @cart_promo_applied.
  ///
  /// In en, this message translates to:
  /// **'Promo code applied: {description}'**
  String cart_promo_applied(Object description);

  /// No description provided for @cart_summary_section.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get cart_summary_section;

  /// No description provided for @cart_discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get cart_discount;

  /// No description provided for @cart_payment_section.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get cart_payment_section;

  /// No description provided for @cart_payment_cod.
  ///
  /// In en, this message translates to:
  /// **'Cash on delivery'**
  String get cart_payment_cod;

  /// No description provided for @cart_payment_fedapay.
  ///
  /// In en, this message translates to:
  /// **'Mobile Money (CinetPay)'**
  String get cart_payment_fedapay;

  /// No description provided for @cart_processing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get cart_processing;

  /// No description provided for @cart_order_button.
  ///
  /// In en, this message translates to:
  /// **'Order · {amount}'**
  String cart_order_button(Object amount);

  /// No description provided for @cart_choose_address_warning.
  ///
  /// In en, this message translates to:
  /// **'Please choose an address.'**
  String get cart_choose_address_warning;

  /// No description provided for @cart_order_confirm_message.
  ///
  /// In en, this message translates to:
  /// **'Order confirmed!'**
  String get cart_order_confirm_message;

  /// No description provided for @cart_order_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create order.'**
  String get cart_order_failed;

  /// No description provided for @cart_order_error_retry.
  ///
  /// In en, this message translates to:
  /// **'Error. Please retry.'**
  String get cart_order_error_retry;

  /// No description provided for @cart_payment_url_error.
  ///
  /// In en, this message translates to:
  /// **'Error: Payment URL not found.'**
  String get cart_payment_url_error;

  /// No description provided for @cart_payment_fedapay_error.
  ///
  /// In en, this message translates to:
  /// **'Online payment error'**
  String get cart_payment_fedapay_error;

  /// No description provided for @cart_payment_online_error.
  ///
  /// In en, this message translates to:
  /// **'Online payment error. Please try again or choose another payment method.'**
  String get cart_payment_online_error;

  /// No description provided for @cart_payment_error.
  ///
  /// In en, this message translates to:
  /// **'Payment error.'**
  String get cart_payment_error;

  /// No description provided for @cart_order_confirmed_message.
  ///
  /// In en, this message translates to:
  /// **'Your order #{orderId} has been placed successfully.'**
  String cart_order_confirmed_message(Object orderId);

  /// No description provided for @cart_track_order.
  ///
  /// In en, this message translates to:
  /// **'Track my order'**
  String get cart_track_order;

  /// No description provided for @cart_address_not_found.
  ///
  /// In en, this message translates to:
  /// **'Address not found.'**
  String get cart_address_not_found;

  /// No description provided for @cart_address_saved.
  ///
  /// In en, this message translates to:
  /// **'Address saved!'**
  String get cart_address_saved;

  /// No description provided for @cart_address_invalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid address.'**
  String get cart_address_invalid;

  /// No description provided for @cart_address_delete_forbidden.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete main address.'**
  String get cart_address_delete_forbidden;

  /// No description provided for @cart_address_deleted.
  ///
  /// In en, this message translates to:
  /// **'Address deleted.'**
  String get cart_address_deleted;

  /// No description provided for @cart_address_delete_error.
  ///
  /// In en, this message translates to:
  /// **'Deletion error.'**
  String get cart_address_delete_error;

  /// No description provided for @cart_your_addresses.
  ///
  /// In en, this message translates to:
  /// **'Your addresses'**
  String get cart_your_addresses;

  /// No description provided for @cart_new_address.
  ///
  /// In en, this message translates to:
  /// **'New address'**
  String get cart_new_address;

  /// No description provided for @cart_item_deleted.
  ///
  /// In en, this message translates to:
  /// **'{mealName} removed'**
  String cart_item_deleted(Object mealName);

  /// No description provided for @street.
  ///
  /// In en, this message translates to:
  /// **'Street'**
  String get street;

  /// No description provided for @postal_code.
  ///
  /// In en, this message translates to:
  /// **'Postal code'**
  String get postal_code;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @address_selection_hint.
  ///
  /// In en, this message translates to:
  /// **'Select an address'**
  String get address_selection_hint;

  /// No description provided for @home_category_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get home_category_all;

  /// No description provided for @home_top_picks.
  ///
  /// In en, this message translates to:
  /// **'Top picks near you'**
  String get home_top_picks;

  /// No description provided for @home_see_all.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get home_see_all;

  /// No description provided for @home_meals_nearby.
  ///
  /// In en, this message translates to:
  /// **'Meals near you'**
  String get home_meals_nearby;

  /// No description provided for @home_deliver_to.
  ///
  /// In en, this message translates to:
  /// **'Deliver to'**
  String get home_deliver_to;

  /// No description provided for @home_nearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get home_nearby;

  /// No description provided for @home_welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get home_welcome;

  /// No description provided for @home_tagline.
  ///
  /// In en, this message translates to:
  /// **'Neighborhood cuisine, delivered.'**
  String get home_tagline;

  /// No description provided for @home_subtagline.
  ///
  /// In en, this message translates to:
  /// **'Home cooking · Local chefs · Fresh daily'**
  String get home_subtagline;

  /// No description provided for @home_categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get home_categories;

  /// No description provided for @home_delivery_fee_label.
  ///
  /// In en, this message translates to:
  /// **'{fee} € delivery'**
  String home_delivery_fee_label(Object fee);

  /// No description provided for @home_rated.
  ///
  /// In en, this message translates to:
  /// **'Rated'**
  String get home_rated;

  /// No description provided for @home_contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get home_contact;

  /// No description provided for @home_no_restaurants.
  ///
  /// In en, this message translates to:
  /// **'No restaurants nearby'**
  String get home_no_restaurants;

  /// No description provided for @home_no_restaurants_hint.
  ///
  /// In en, this message translates to:
  /// **'Expand your area or come back later.'**
  String get home_no_restaurants_hint;

  /// No description provided for @home_explore_categories.
  ///
  /// In en, this message translates to:
  /// **'Explore all categories'**
  String get home_explore_categories;

  /// No description provided for @dish_added_to_cart.
  ///
  /// In en, this message translates to:
  /// **'Added to cart!'**
  String get dish_added_to_cart;

  /// No description provided for @dish_cannot_mix_restaurants.
  ///
  /// In en, this message translates to:
  /// **'You cannot order from two different restaurants.'**
  String get dish_cannot_mix_restaurants;

  /// No description provided for @dish_add_error.
  ///
  /// In en, this message translates to:
  /// **'Error adding to cart.'**
  String get dish_add_error;

  /// No description provided for @dish_popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get dish_popular;

  /// No description provided for @dish_servings_available.
  ///
  /// In en, this message translates to:
  /// **'{count} servings available'**
  String dish_servings_available(Object count);

  /// No description provided for @dish_photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get dish_photos;

  /// No description provided for @dish_quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get dish_quantity;

  /// No description provided for @dish_options.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get dish_options;

  /// No description provided for @dish_reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get dish_reviews;

  /// No description provided for @dish_add_to_cart.
  ///
  /// In en, this message translates to:
  /// **'Add to cart · {price}'**
  String dish_add_to_cart(Object price);

  /// No description provided for @store_my_earnings.
  ///
  /// In en, this message translates to:
  /// **'My earnings'**
  String get store_my_earnings;

  /// No description provided for @store_delivery_radius.
  ///
  /// In en, this message translates to:
  /// **'Delivery radius'**
  String get store_delivery_radius;

  /// No description provided for @store_become_seller.
  ///
  /// In en, this message translates to:
  /// **'Become a seller'**
  String get store_become_seller;

  /// No description provided for @store_my_orders.
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get store_my_orders;

  /// No description provided for @store_contact_us.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get store_contact_us;

  /// No description provided for @store_my_restaurant.
  ///
  /// In en, this message translates to:
  /// **'My restaurant'**
  String get store_my_restaurant;

  /// No description provided for @store_continue_request.
  ///
  /// In en, this message translates to:
  /// **'Continue my request'**
  String get store_continue_request;

  /// No description provided for @store_cancel_request.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get store_cancel_request;

  /// No description provided for @store_edit_restaurant.
  ///
  /// In en, this message translates to:
  /// **'Edit my restaurant'**
  String get store_edit_restaurant;

  /// No description provided for @store_become_pro.
  ///
  /// In en, this message translates to:
  /// **'Become Pro'**
  String get store_become_pro;

  /// No description provided for @store_no_restaurant_data.
  ///
  /// In en, this message translates to:
  /// **'No restaurant data.'**
  String get store_no_restaurant_data;

  /// No description provided for @store_become_restaurateur_title.
  ///
  /// In en, this message translates to:
  /// **'Become a home chef'**
  String get store_become_restaurateur_title;

  /// No description provided for @store_become_restaurateur_body.
  ///
  /// In en, this message translates to:
  /// **'By becoming a home chef, you will be able to publish your dishes and sell them directly to customers. Would you like to continue?'**
  String get store_become_restaurateur_body;

  /// No description provided for @store_yes_sell.
  ///
  /// In en, this message translates to:
  /// **'Yes, I want to sell my dishes'**
  String get store_yes_sell;

  /// No description provided for @store_cancel_request_title.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get store_cancel_request_title;

  /// No description provided for @store_cancel_request_body.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel your restaurant creation request? All entered information will be lost.'**
  String get store_cancel_request_body;

  /// No description provided for @store_yes_cancel.
  ///
  /// In en, this message translates to:
  /// **'Yes, cancel'**
  String get store_yes_cancel;

  /// No description provided for @store_request_cancelled.
  ///
  /// In en, this message translates to:
  /// **'Request cancelled.'**
  String get store_request_cancelled;

  /// No description provided for @store_max_distance.
  ///
  /// In en, this message translates to:
  /// **'Maximum distance: {distance} km'**
  String store_max_distance(Object distance);

  /// No description provided for @store_max_distance_limit.
  ///
  /// In en, this message translates to:
  /// **'Limited to 10 km maximum'**
  String get store_max_distance_limit;

  /// No description provided for @store_radius_updated.
  ///
  /// In en, this message translates to:
  /// **'Radius updated: {distance} km'**
  String store_radius_updated(Object distance);

  /// No description provided for @store_update_error.
  ///
  /// In en, this message translates to:
  /// **'Update error'**
  String get store_update_error;

  /// No description provided for @admin_dashboard_title.
  ///
  /// In en, this message translates to:
  /// **'Administration'**
  String get admin_dashboard_title;

  /// No description provided for @admin_greeting.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String admin_greeting(Object name);

  /// No description provided for @admin_validation_alert.
  ///
  /// In en, this message translates to:
  /// **'{count} restaurant(s) pending'**
  String admin_validation_alert(Object count);

  /// No description provided for @admin_validation_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Action required · Validate or reject below'**
  String get admin_validation_subtitle;

  /// No description provided for @admin_validation_section.
  ///
  /// In en, this message translates to:
  /// **'Restaurant validation'**
  String get admin_validation_section;

  /// No description provided for @admin_quick_actions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get admin_quick_actions;

  /// No description provided for @admin_management.
  ///
  /// In en, this message translates to:
  /// **'Management'**
  String get admin_management;

  /// No description provided for @admin_categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get admin_categories;

  /// No description provided for @admin_promotions.
  ///
  /// In en, this message translates to:
  /// **'Promotions'**
  String get admin_promotions;

  /// No description provided for @admin_referral.
  ///
  /// In en, this message translates to:
  /// **'Referral'**
  String get admin_referral;

  /// No description provided for @admin_scheduled_deletions.
  ///
  /// In en, this message translates to:
  /// **'Scheduled deletions'**
  String get admin_scheduled_deletions;

  /// No description provided for @admin_search_hint.
  ///
  /// In en, this message translates to:
  /// **'User or restaurant…'**
  String get admin_search_hint;

  /// No description provided for @admin_export_title.
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get admin_export_title;

  /// No description provided for @admin_export_orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get admin_export_orders;

  /// No description provided for @admin_export_full_report.
  ///
  /// In en, this message translates to:
  /// **'Full report'**
  String get admin_export_full_report;

  /// No description provided for @admin_add_admin_title.
  ///
  /// In en, this message translates to:
  /// **'Add administrator'**
  String get admin_add_admin_title;

  /// No description provided for @admin_add_admin_info.
  ///
  /// In en, this message translates to:
  /// **'A temporary password will be sent by email.'**
  String get admin_add_admin_info;

  /// No description provided for @admin_admin_created.
  ///
  /// In en, this message translates to:
  /// **'Administrator created. An email has been sent to them.'**
  String get admin_admin_created;

  /// No description provided for @admin_validate.
  ///
  /// In en, this message translates to:
  /// **'Validate'**
  String get admin_validate;

  /// No description provided for @admin_reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get admin_reject;

  /// No description provided for @admin_restaurant_validated.
  ///
  /// In en, this message translates to:
  /// **'{name} validated ✓'**
  String admin_restaurant_validated(Object name);

  /// No description provided for @admin_restaurant_rejected.
  ///
  /// In en, this message translates to:
  /// **'{name} rejected'**
  String admin_restaurant_rejected(Object name);

  /// No description provided for @admin_rejection_reason_hint.
  ///
  /// In en, this message translates to:
  /// **'Rejection reason…'**
  String get admin_rejection_reason_hint;

  /// No description provided for @admin_pro_requests.
  ///
  /// In en, this message translates to:
  /// **'Pro Requests'**
  String get admin_pro_requests;

  /// No description provided for @admin_pro_requests_pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get admin_pro_requests_pending;

  /// No description provided for @admin_pro_requests_validated.
  ///
  /// In en, this message translates to:
  /// **'Validated'**
  String get admin_pro_requests_validated;

  /// No description provided for @admin_pro_requests_rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get admin_pro_requests_rejected;

  /// No description provided for @admin_pro_validate.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get admin_pro_validate;

  /// No description provided for @admin_pro_reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get admin_pro_reject;

  /// No description provided for @admin_pro_validated.
  ///
  /// In en, this message translates to:
  /// **'{name} approved ✓'**
  String admin_pro_validated(Object name);

  /// No description provided for @admin_pro_rejected.
  ///
  /// In en, this message translates to:
  /// **'{name} rejected'**
  String admin_pro_rejected(Object name);

  /// No description provided for @admin_pro_no_requests.
  ///
  /// In en, this message translates to:
  /// **'No Pro requests.'**
  String get admin_pro_no_requests;

  /// No description provided for @admin_pro_status_pending.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get admin_pro_status_pending;

  /// No description provided for @admin_pro_status_validated.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get admin_pro_status_validated;

  /// No description provided for @admin_pro_status_rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get admin_pro_status_rejected;

  /// No description provided for @admin_pro_remark_hint.
  ///
  /// In en, this message translates to:
  /// **'Reason for rejection…'**
  String get admin_pro_remark_hint;

  /// No description provided for @admin_pro_documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get admin_pro_documents;

  /// No description provided for @admin_pro_view_document.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get admin_pro_view_document;

  /// No description provided for @admin_pro_description.
  ///
  /// In en, this message translates to:
  /// **'Request description'**
  String get admin_pro_description;

  /// No description provided for @admin_pro_no_description.
  ///
  /// In en, this message translates to:
  /// **'No description provided.'**
  String get admin_pro_no_description;

  /// No description provided for @admin_delivery_requests.
  ///
  /// In en, this message translates to:
  /// **'Driver Requests'**
  String get admin_delivery_requests;

  /// No description provided for @admin_delivery_requests_pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get admin_delivery_requests_pending;

  /// No description provided for @admin_delivery_requests_validated.
  ///
  /// In en, this message translates to:
  /// **'Validated'**
  String get admin_delivery_requests_validated;

  /// No description provided for @admin_delivery_requests_rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get admin_delivery_requests_rejected;

  /// No description provided for @admin_delivery_validate.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get admin_delivery_validate;

  /// No description provided for @admin_delivery_reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get admin_delivery_reject;

  /// No description provided for @admin_delivery_no_requests.
  ///
  /// In en, this message translates to:
  /// **'No driver requests.'**
  String get admin_delivery_no_requests;

  /// No description provided for @admin_delivery_status_pending.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get admin_delivery_status_pending;

  /// No description provided for @admin_delivery_status_validated.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get admin_delivery_status_validated;

  /// No description provided for @admin_delivery_status_rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get admin_delivery_status_rejected;

  /// No description provided for @admin_delivery_remark_hint.
  ///
  /// In en, this message translates to:
  /// **'Reason for rejection…'**
  String get admin_delivery_remark_hint;

  /// No description provided for @admin_delivery_documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get admin_delivery_documents;

  /// No description provided for @admin_delivery_view_document.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get admin_delivery_view_document;

  /// No description provided for @admin_delivery_description.
  ///
  /// In en, this message translates to:
  /// **'Request description'**
  String get admin_delivery_description;

  /// No description provided for @admin_delivery_id_card.
  ///
  /// In en, this message translates to:
  /// **'ID card'**
  String get admin_delivery_id_card;

  /// No description provided for @admin_delivery_license.
  ///
  /// In en, this message translates to:
  /// **'Driver\'s license'**
  String get admin_delivery_license;

  /// No description provided for @superAdminDashboard.
  ///
  /// In en, this message translates to:
  /// **'Super Admin Dashboard'**
  String get superAdminDashboard;

  /// No description provided for @superAdminWeeklyCommissions.
  ///
  /// In en, this message translates to:
  /// **'Weekly Commissions'**
  String get superAdminWeeklyCommissions;

  /// No description provided for @superAdminPaymentsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed Payments'**
  String get superAdminPaymentsCompleted;

  /// No description provided for @superAdminPaymentsPending.
  ///
  /// In en, this message translates to:
  /// **'Pending Payments'**
  String get superAdminPaymentsPending;

  /// No description provided for @superAdminDisputesOpen.
  ///
  /// In en, this message translates to:
  /// **'Open Disputes'**
  String get superAdminDisputesOpen;

  /// No description provided for @superAdminDisputesInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress Disputes'**
  String get superAdminDisputesInProgress;

  /// No description provided for @superAdminDisputesResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved Disputes'**
  String get superAdminDisputesResolved;

  /// No description provided for @superAdminDisputeRate.
  ///
  /// In en, this message translates to:
  /// **'Dispute Rate'**
  String get superAdminDisputeRate;

  /// Indicates a field is optional
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get optional;

  /// No description provided for @admin_delivery_validated.
  ///
  /// In en, this message translates to:
  /// **'{name} approved ✓'**
  String admin_delivery_validated(Object name);

  /// No description provided for @admin_delivery_rejected.
  ///
  /// In en, this message translates to:
  /// **'{name} rejected'**
  String admin_delivery_rejected(Object name);

  /// No description provided for @delivery_status_assigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get delivery_status_assigned;

  /// No description provided for @delivery_status_picked_up.
  ///
  /// In en, this message translates to:
  /// **'Picked up'**
  String get delivery_status_picked_up;

  /// No description provided for @delivery_status_in_transit.
  ///
  /// In en, this message translates to:
  /// **'In transit'**
  String get delivery_status_in_transit;

  /// No description provided for @delivery_status_delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get delivery_status_delivered;

  /// No description provided for @delivery_abandon_confirm.
  ///
  /// In en, this message translates to:
  /// **'Abandon this delivery?'**
  String get delivery_abandon_confirm;

  /// No description provided for @delivery_abandon_body.
  ///
  /// In en, this message translates to:
  /// **'The order will be made available to other drivers.'**
  String get delivery_abandon_body;

  /// No description provided for @delivery_abandon.
  ///
  /// In en, this message translates to:
  /// **'Abandon'**
  String get delivery_abandon;

  /// No description provided for @delivery_abandoned.
  ///
  /// In en, this message translates to:
  /// **'Delivery abandoned'**
  String get delivery_abandoned;

  /// No description provided for @delivery_abandon_error.
  ///
  /// In en, this message translates to:
  /// **'Error abandoning delivery'**
  String get delivery_abandon_error;

  /// No description provided for @delivery_online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get delivery_online;

  /// No description provided for @delivery_offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get delivery_offline;

  /// No description provided for @delivery_toggle_online.
  ///
  /// In en, this message translates to:
  /// **'✅ Online'**
  String get delivery_toggle_online;

  /// No description provided for @delivery_toggle_offline.
  ///
  /// In en, this message translates to:
  /// **'⛔ Offline'**
  String get delivery_toggle_offline;

  /// No description provided for @delivery_earnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings {period}'**
  String delivery_earnings(Object period);

  /// No description provided for @delivery_today.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get delivery_today;

  /// No description provided for @delivery_this_week.
  ///
  /// In en, this message translates to:
  /// **'this week'**
  String get delivery_this_week;

  /// No description provided for @delivery_this_month.
  ///
  /// In en, this message translates to:
  /// **'this month'**
  String get delivery_this_month;

  /// No description provided for @delivery_period_7days.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get delivery_period_7days;

  /// No description provided for @delivery_period_30days.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get delivery_period_30days;

  /// No description provided for @delivery_evolution.
  ///
  /// In en, this message translates to:
  /// **'Evolution'**
  String get delivery_evolution;

  /// No description provided for @delivery_no_data.
  ///
  /// In en, this message translates to:
  /// **'No data for this period'**
  String get delivery_no_data;

  /// No description provided for @delivery_tracking_steps_preparation.
  ///
  /// In en, this message translates to:
  /// **'Preparation'**
  String get delivery_tracking_steps_preparation;

  /// No description provided for @delivery_tracking_steps_picked.
  ///
  /// In en, this message translates to:
  /// **'Picked up'**
  String get delivery_tracking_steps_picked;

  /// No description provided for @delivery_tracking_steps_transit.
  ///
  /// In en, this message translates to:
  /// **'In transit'**
  String get delivery_tracking_steps_transit;

  /// No description provided for @delivery_tracking_steps_delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get delivery_tracking_steps_delivered;

  /// No description provided for @livreur_fiche_title.
  ///
  /// In en, this message translates to:
  /// **'Driver profile'**
  String get livreur_fiche_title;

  /// No description provided for @livreur_not_found.
  ///
  /// In en, this message translates to:
  /// **'Driver not found'**
  String get livreur_not_found;

  /// No description provided for @livreur_stats.
  ///
  /// In en, this message translates to:
  /// **'Delivery statistics'**
  String get livreur_stats;

  /// No description provided for @livreur_documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get livreur_documents;

  /// No description provided for @livreur_license.
  ///
  /// In en, this message translates to:
  /// **'Driver\'s license'**
  String get livreur_license;

  /// No description provided for @livreur_id_card.
  ///
  /// In en, this message translates to:
  /// **'ID card'**
  String get livreur_id_card;

  /// No description provided for @livreur_validated.
  ///
  /// In en, this message translates to:
  /// **'Validated'**
  String get livreur_validated;

  /// No description provided for @livreur_pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get livreur_pending;

  /// No description provided for @livreur_not_provided.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get livreur_not_provided;

  /// No description provided for @livreur_validation_actions.
  ///
  /// In en, this message translates to:
  /// **'Validation actions'**
  String get livreur_validation_actions;

  /// No description provided for @livreur_document_reject_title.
  ///
  /// In en, this message translates to:
  /// **'Reject document'**
  String get livreur_document_reject_title;

  /// No description provided for @livreur_document_reject_hint.
  ///
  /// In en, this message translates to:
  /// **'Add a remark for the driver:'**
  String get livreur_document_reject_hint;

  /// No description provided for @livreur_document_rejected.
  ///
  /// In en, this message translates to:
  /// **'Document rejected'**
  String get livreur_document_rejected;

  /// No description provided for @livreur_document_reject_error.
  ///
  /// In en, this message translates to:
  /// **'Error rejecting document'**
  String get livreur_document_reject_error;

  /// No description provided for @livreur_document_validated.
  ///
  /// In en, this message translates to:
  /// **'Document validated successfully'**
  String get livreur_document_validated;

  /// No description provided for @livreur_document_validate_error.
  ///
  /// In en, this message translates to:
  /// **'Error validating document'**
  String get livreur_document_validate_error;

  /// No description provided for @livreur_upload_title.
  ///
  /// In en, this message translates to:
  /// **'Driver documents'**
  String get livreur_upload_title;

  /// No description provided for @livreur_upload_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Required documents for delivery'**
  String get livreur_upload_subtitle;

  /// No description provided for @livreur_upload_success.
  ///
  /// In en, this message translates to:
  /// **'Documents sent successfully.'**
  String get livreur_upload_success;

  /// No description provided for @livreur_upload_error.
  ///
  /// In en, this message translates to:
  /// **'Error sending documents.'**
  String get livreur_upload_error;

  /// No description provided for @livreur_management_title.
  ///
  /// In en, this message translates to:
  /// **'Driver management'**
  String get livreur_management_title;

  /// No description provided for @livreur_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search drivers...'**
  String get livreur_search_hint;

  /// No description provided for @livreur_filter_online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get livreur_filter_online;

  /// No description provided for @livreur_filter_offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get livreur_filter_offline;

  /// No description provided for @livreur_filter_license_valid.
  ///
  /// In en, this message translates to:
  /// **'License ✓'**
  String get livreur_filter_license_valid;

  /// No description provided for @livreur_filter_license_pending.
  ///
  /// In en, this message translates to:
  /// **'License ?'**
  String get livreur_filter_license_pending;

  /// No description provided for @livreur_filter_license_validated.
  ///
  /// In en, this message translates to:
  /// **'License validated'**
  String get livreur_filter_license_validated;

  /// No description provided for @livreur_filter_license_waiting.
  ///
  /// In en, this message translates to:
  /// **'License pending'**
  String get livreur_filter_license_waiting;

  /// No description provided for @livreur_no_results.
  ///
  /// In en, this message translates to:
  /// **'No drivers found'**
  String get livreur_no_results;

  /// No description provided for @livreur_validate_license.
  ///
  /// In en, this message translates to:
  /// **'Validate license'**
  String get livreur_validate_license;

  /// No description provided for @livreur_validate_license_confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm license validation for {firstname} {lastname} ?'**
  String livreur_validate_license_confirm(Object firstname, Object lastname);

  /// No description provided for @livreur_license_validated.
  ///
  /// In en, this message translates to:
  /// **'License for {firstname} validated'**
  String livreur_license_validated(Object firstname);

  /// No description provided for @livreur_validate_error.
  ///
  /// In en, this message translates to:
  /// **'Error during validation'**
  String get livreur_validate_error;

  /// No description provided for @livreur_vehicle_moto.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle'**
  String get livreur_vehicle_moto;

  /// No description provided for @livreur_vehicle_bike.
  ///
  /// In en, this message translates to:
  /// **'Bicycle'**
  String get livreur_vehicle_bike;

  /// No description provided for @livreur_vehicle_car.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get livreur_vehicle_car;

  /// No description provided for @livreur_vehicle_unspecified.
  ///
  /// In en, this message translates to:
  /// **'Unspecified'**
  String get livreur_vehicle_unspecified;

  /// No description provided for @livreur_map_title.
  ///
  /// In en, this message translates to:
  /// **'Available orders ({count})'**
  String livreur_map_title(Object count);

  /// No description provided for @livreur_map_no_orders.
  ///
  /// In en, this message translates to:
  /// **'No orders available at the moment.'**
  String get livreur_map_no_orders;

  /// No description provided for @livreur_map_position_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Position unavailable'**
  String get livreur_map_position_unavailable;

  /// No description provided for @livreur_map_accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get livreur_map_accept;

  /// No description provided for @livreur_order_accepted.
  ///
  /// In en, this message translates to:
  /// **'Order #{id} accepted'**
  String livreur_order_accepted(Object id);

  /// No description provided for @livreur_order_already_in_progress.
  ///
  /// In en, this message translates to:
  /// **'Cannot accept: you already have an order in progress'**
  String get livreur_order_already_in_progress;

  /// No description provided for @restaurant_form_title_create.
  ///
  /// In en, this message translates to:
  /// **'Create my restaurant'**
  String get restaurant_form_title_create;

  /// No description provided for @restaurant_form_title_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit my restaurant'**
  String get restaurant_form_title_edit;

  /// No description provided for @restaurant_form_section_restaurant.
  ///
  /// In en, this message translates to:
  /// **'Your restaurant'**
  String get restaurant_form_section_restaurant;

  /// No description provided for @restaurant_form_name_hint.
  ///
  /// In en, this message translates to:
  /// **'Restaurant name'**
  String get restaurant_form_name_hint;

  /// No description provided for @restaurant_form_name_required.
  ///
  /// In en, this message translates to:
  /// **'Enter the restaurant name'**
  String get restaurant_form_name_required;

  /// No description provided for @restaurant_form_name_min_length.
  ///
  /// In en, this message translates to:
  /// **'At least 4 characters'**
  String get restaurant_form_name_min_length;

  /// No description provided for @restaurant_form_desc_hint.
  ///
  /// In en, this message translates to:
  /// **'Restaurant description'**
  String get restaurant_form_desc_hint;

  /// No description provided for @restaurant_form_desc_required.
  ///
  /// In en, this message translates to:
  /// **'Enter a description'**
  String get restaurant_form_desc_required;

  /// No description provided for @restaurant_form_address_hint.
  ///
  /// In en, this message translates to:
  /// **'Restaurant address'**
  String get restaurant_form_address_hint;

  /// No description provided for @restaurant_form_address_required.
  ///
  /// In en, this message translates to:
  /// **'Enter the address'**
  String get restaurant_form_address_required;

  /// No description provided for @restaurant_form_detect_position.
  ///
  /// In en, this message translates to:
  /// **'Detect my position'**
  String get restaurant_form_detect_position;

  /// No description provided for @restaurant_form_opening_days.
  ///
  /// In en, this message translates to:
  /// **'Opening days'**
  String get restaurant_form_opening_days;

  /// No description provided for @restaurant_form_opening_hours.
  ///
  /// In en, this message translates to:
  /// **'Opening hours'**
  String get restaurant_form_opening_hours;

  /// No description provided for @restaurant_form_pickup_mode.
  ///
  /// In en, this message translates to:
  /// **'Pickup mode'**
  String get restaurant_form_pickup_mode;

  /// No description provided for @restaurant_form_mode_takeaway.
  ///
  /// In en, this message translates to:
  /// **'Takeaway'**
  String get restaurant_form_mode_takeaway;

  /// No description provided for @restaurant_form_mode_both.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get restaurant_form_mode_both;

  /// No description provided for @restaurant_form_no_image.
  ///
  /// In en, this message translates to:
  /// **'No image selected'**
  String get restaurant_form_no_image;

  /// No description provided for @restaurant_form_select_image.
  ///
  /// In en, this message translates to:
  /// **'Select an image'**
  String get restaurant_form_select_image;

  /// No description provided for @restaurant_form_fix_errors.
  ///
  /// In en, this message translates to:
  /// **'Please correct the fields in red.'**
  String get restaurant_form_fix_errors;

  /// No description provided for @restaurant_form_address_invalid.
  ///
  /// In en, this message translates to:
  /// **'The address is not valid or does not match your country.'**
  String get restaurant_form_address_invalid;

  /// No description provided for @restaurant_form_user_not_connected.
  ///
  /// In en, this message translates to:
  /// **'User not connected.'**
  String get restaurant_form_user_not_connected;

  /// No description provided for @restaurant_form_saved.
  ///
  /// In en, this message translates to:
  /// **'Restaurant saved successfully!'**
  String get restaurant_form_saved;

  /// No description provided for @restaurant_form_update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get restaurant_form_update;

  /// No description provided for @restaurant_form_delivery_fee_hint.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee'**
  String get restaurant_form_delivery_fee_hint;

  /// No description provided for @restaurant_form_opening_hours_hint.
  ///
  /// In en, this message translates to:
  /// **'Opening hours (e.g. 09:00 - 20:00)'**
  String get restaurant_form_opening_hours_hint;

  /// No description provided for @restaurant_form_open_now.
  ///
  /// In en, this message translates to:
  /// **'Restaurant currently open'**
  String get restaurant_form_open_now;

  /// No description provided for @restaurant_details_menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get restaurant_details_menu;

  /// No description provided for @restaurant_details_dish_count.
  ///
  /// In en, this message translates to:
  /// **'{count} dishes'**
  String restaurant_details_dish_count(Object count);

  /// No description provided for @restaurant_details_reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get restaurant_details_reviews;

  /// No description provided for @restaurant_details_mode_delivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery + Takeaway'**
  String get restaurant_details_mode_delivery;

  /// No description provided for @restaurant_details_mode_takeaway.
  ///
  /// In en, this message translates to:
  /// **'Takeaway'**
  String get restaurant_details_mode_takeaway;

  /// No description provided for @restaurant_details_mode_delivery_only.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get restaurant_details_mode_delivery_only;

  /// No description provided for @restaurant_list_title.
  ///
  /// In en, this message translates to:
  /// **'Restaurants · {country}'**
  String restaurant_list_title(Object country);

  /// No description provided for @restaurant_list_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search restaurants...'**
  String get restaurant_list_search_hint;

  /// No description provided for @restaurant_list_filter_pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get restaurant_list_filter_pending;

  /// No description provided for @restaurant_list_filter_validated.
  ///
  /// In en, this message translates to:
  /// **'Validated'**
  String get restaurant_list_filter_validated;

  /// No description provided for @restaurant_list_filter_rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get restaurant_list_filter_rejected;

  /// No description provided for @restaurant_list_no_results.
  ///
  /// In en, this message translates to:
  /// **'No restaurants found'**
  String get restaurant_list_no_results;

  /// No description provided for @restaurant_list_reject_title.
  ///
  /// In en, this message translates to:
  /// **'Reject restaurant'**
  String get restaurant_list_reject_title;

  /// No description provided for @restaurant_list_reject_hint.
  ///
  /// In en, this message translates to:
  /// **'Rejection reason for \"{name}\":'**
  String restaurant_list_reject_hint(Object name);

  /// No description provided for @restaurant_list_validated_toast.
  ///
  /// In en, this message translates to:
  /// **'Restaurant {name} has been validated{emailSent}'**
  String restaurant_list_validated_toast(Object name, Object emailSent);

  /// No description provided for @restaurant_list_rejected_toast.
  ///
  /// In en, this message translates to:
  /// **'Restaurant {name} has been rejected{emailSent}'**
  String restaurant_list_rejected_toast(Object name, Object emailSent);

  /// No description provided for @near_restaurants_title.
  ///
  /// In en, this message translates to:
  /// **'Restaurants nearby'**
  String get near_restaurants_title;

  /// No description provided for @near_restaurants_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search restaurant or cuisine'**
  String get near_restaurants_search_hint;

  /// No description provided for @near_restaurants_open_now.
  ///
  /// In en, this message translates to:
  /// **'Open now'**
  String get near_restaurants_open_now;

  /// No description provided for @near_restaurants_no_results.
  ///
  /// In en, this message translates to:
  /// **'No restaurants found with these filters.'**
  String get near_restaurants_no_results;

  /// No description provided for @verification_select_status.
  ///
  /// In en, this message translates to:
  /// **'Select your status'**
  String get verification_select_status;

  /// No description provided for @verification_individual.
  ///
  /// In en, this message translates to:
  /// **'Individual'**
  String get verification_individual;

  /// No description provided for @verification_restaurateur.
  ///
  /// In en, this message translates to:
  /// **'Restaurateur'**
  String get verification_restaurateur;

  /// No description provided for @verification_user_not_found.
  ///
  /// In en, this message translates to:
  /// **'User not found. Please reconnect.'**
  String get verification_user_not_found;

  /// No description provided for @verification_code_sent.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent by email.'**
  String get verification_code_sent;

  /// No description provided for @verification_code_send_error.
  ///
  /// In en, this message translates to:
  /// **'Cannot send email code.'**
  String get verification_code_send_error;

  /// No description provided for @verification_success.
  ///
  /// In en, this message translates to:
  /// **'Verification successful'**
  String get verification_success;

  /// No description provided for @verification_verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verification_verify;

  /// No description provided for @verification_resend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get verification_resend;

  /// No description provided for @verification_code_hint.
  ///
  /// In en, this message translates to:
  /// **'Enter the code sent by email to {email}'**
  String verification_code_hint(Object email);

  /// No description provided for @verification_spam_hint.
  ///
  /// In en, this message translates to:
  /// **'If you can\'t find the email, check your spam folder.'**
  String get verification_spam_hint;

  /// No description provided for @verification_enter_code.
  ///
  /// In en, this message translates to:
  /// **'Please enter the code.'**
  String get verification_enter_code;

  /// No description provided for @verification_account_error.
  ///
  /// In en, this message translates to:
  /// **'Error validating account.'**
  String get verification_account_error;

  /// No description provided for @verification_code_invalid.
  ///
  /// In en, this message translates to:
  /// **'Error: invalid email code.'**
  String get verification_code_invalid;

  /// No description provided for @verification_new_code_sent.
  ///
  /// In en, this message translates to:
  /// **'New code sent by email.'**
  String get verification_new_code_sent;

  /// No description provided for @verification_new_code_error.
  ///
  /// In en, this message translates to:
  /// **'Cannot send code.'**
  String get verification_new_code_error;

  /// No description provided for @verification_resend_cooldown.
  ///
  /// In en, this message translates to:
  /// **'Resend code ({seconds} s)'**
  String verification_resend_cooldown(Object seconds);

  /// No description provided for @identity_title.
  ///
  /// In en, this message translates to:
  /// **'My identity'**
  String get identity_title;

  /// No description provided for @identity_your_photo.
  ///
  /// In en, this message translates to:
  /// **'Your photo'**
  String get identity_your_photo;

  /// No description provided for @identity_no_photo.
  ///
  /// In en, this message translates to:
  /// **'No photo taken'**
  String get identity_no_photo;

  /// No description provided for @identity_add_photo.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get identity_add_photo;

  /// No description provided for @identity_id_document.
  ///
  /// In en, this message translates to:
  /// **'ID document (image or PDF)'**
  String get identity_id_document;

  /// No description provided for @identity_no_file.
  ///
  /// In en, this message translates to:
  /// **'No file selected'**
  String get identity_no_file;

  /// No description provided for @identity_add_document.
  ///
  /// In en, this message translates to:
  /// **'Add an ID document'**
  String get identity_add_document;

  /// No description provided for @identity_provide_both.
  ///
  /// In en, this message translates to:
  /// **'Please provide a photo and an ID document'**
  String get identity_provide_both;

  /// No description provided for @identity_take_photo.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get identity_take_photo;

  /// No description provided for @identity_choose_gallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get identity_choose_gallery;

  /// No description provided for @identity_choose_file.
  ///
  /// In en, this message translates to:
  /// **'Choose an image file'**
  String get identity_choose_file;

  /// No description provided for @identity_choose_gallery_option.
  ///
  /// In en, this message translates to:
  /// **'Choose an image from gallery'**
  String get identity_choose_gallery_option;

  /// No description provided for @identity_choose_files_option.
  ///
  /// In en, this message translates to:
  /// **'Choose from files'**
  String get identity_choose_files_option;

  /// No description provided for @identity_format_hint.
  ///
  /// In en, this message translates to:
  /// **'Image or PDF'**
  String get identity_format_hint;

  /// No description provided for @identity_camera_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera is not available on this simulator. Use a real device to take a photo.'**
  String get identity_camera_unavailable;

  /// No description provided for @identity_camera_error.
  ///
  /// In en, this message translates to:
  /// **'Cannot open camera. Check camera permission.'**
  String get identity_camera_error;

  /// No description provided for @identity_gallery_error.
  ///
  /// In en, this message translates to:
  /// **'Cannot open gallery.'**
  String get identity_gallery_error;

  /// No description provided for @identity_pending_title.
  ///
  /// In en, this message translates to:
  /// **'New identity pending verification'**
  String get identity_pending_title;

  /// No description provided for @identity_pending_body.
  ///
  /// In en, this message translates to:
  /// **'Log in to validate or reject the user.'**
  String get identity_pending_body;

  /// No description provided for @confirmation_request_taken.
  ///
  /// In en, this message translates to:
  /// **'Your request has been received.'**
  String get confirmation_request_taken;

  /// No description provided for @confirmation_wait_contact.
  ///
  /// In en, this message translates to:
  /// **'You will be contacted if your restaurant idea is accepted.'**
  String get confirmation_wait_contact;

  /// No description provided for @confirmation_wait_email.
  ///
  /// In en, this message translates to:
  /// **'You will receive an email when our administrators have reviewed your information.'**
  String get confirmation_wait_email;

  /// No description provided for @confirmation_back_home.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get confirmation_back_home;

  /// No description provided for @start_address_instructions.
  ///
  /// In en, this message translates to:
  /// **'We will save your address: follow the instructions until the end'**
  String get start_address_instructions;

  /// No description provided for @start_identity_instructions.
  ///
  /// In en, this message translates to:
  /// **'Last step: we will verify your identity'**
  String get start_identity_instructions;

  /// No description provided for @start_begin.
  ///
  /// In en, this message translates to:
  /// **'Start >'**
  String get start_begin;

  /// No description provided for @start_cancel_return.
  ///
  /// In en, this message translates to:
  /// **'Cancel (return to login)'**
  String get start_cancel_return;

  /// No description provided for @user_orders_received.
  ///
  /// In en, this message translates to:
  /// **'Received orders'**
  String get user_orders_received;

  /// No description provided for @user_orders_my.
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get user_orders_my;

  /// No description provided for @user_orders_confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get user_orders_confirm;

  /// No description provided for @user_orders_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get user_orders_cancel;

  /// No description provided for @user_orders_see_detail.
  ///
  /// In en, this message translates to:
  /// **'See details'**
  String get user_orders_see_detail;

  /// No description provided for @user_orders_rate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get user_orders_rate;

  /// No description provided for @user_orders_rate_driver.
  ///
  /// In en, this message translates to:
  /// **'Rate driver'**
  String get user_orders_rate_driver;

  /// No description provided for @user_orders_confirm_prompt.
  ///
  /// In en, this message translates to:
  /// **'Confirm order #{id}?'**
  String user_orders_confirm_prompt(Object id);

  /// No description provided for @user_orders_cancel_prompt.
  ///
  /// In en, this message translates to:
  /// **'Cancel order #{id}?'**
  String user_orders_cancel_prompt(Object id);

  /// No description provided for @user_orders_yes_confirm.
  ///
  /// In en, this message translates to:
  /// **'Yes, confirm'**
  String get user_orders_yes_confirm;

  /// No description provided for @user_orders_yes_cancel.
  ///
  /// In en, this message translates to:
  /// **'Yes, cancel'**
  String get user_orders_yes_cancel;

  /// No description provided for @user_orders_assign_driver.
  ///
  /// In en, this message translates to:
  /// **'Assign a driver'**
  String get user_orders_assign_driver;

  /// No description provided for @user_orders_driver_assigned.
  ///
  /// In en, this message translates to:
  /// **'Driver assigned'**
  String get user_orders_driver_assigned;

  /// No description provided for @user_orders_mark_assigned.
  ///
  /// In en, this message translates to:
  /// **'Mark as assigned'**
  String get user_orders_mark_assigned;

  /// No description provided for @user_orders_thanks_review.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your review!'**
  String get user_orders_thanks_review;

  /// No description provided for @user_orders_thanks_review_driver.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your driver review!'**
  String get user_orders_thanks_review_driver;

  /// No description provided for @user_orders_tap_to_enlarge.
  ///
  /// In en, this message translates to:
  /// **'Tap to enlarge'**
  String get user_orders_tap_to_enlarge;

  /// No description provided for @user_orders_no_driver.
  ///
  /// In en, this message translates to:
  /// **'No driver available online in the distance area.'**
  String get user_orders_no_driver;

  /// No description provided for @commande_details_title.
  ///
  /// In en, this message translates to:
  /// **'Order details'**
  String get commande_details_title;

  /// No description provided for @commande_details_confirm_order.
  ///
  /// In en, this message translates to:
  /// **'Confirm order'**
  String get commande_details_confirm_order;

  /// No description provided for @commande_details_cancel_order.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get commande_details_cancel_order;

  /// No description provided for @commande_details_information.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get commande_details_information;

  /// No description provided for @commande_details_restaurant.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get commande_details_restaurant;

  /// No description provided for @commande_details_client.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get commande_details_client;

  /// No description provided for @commande_details_payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get commande_details_payment;

  /// No description provided for @commande_details_cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get commande_details_cash;

  /// No description provided for @commande_details_card.
  ///
  /// In en, this message translates to:
  /// **'Credit card'**
  String get commande_details_card;

  /// No description provided for @commande_details_om.
  ///
  /// In en, this message translates to:
  /// **'Orange Money'**
  String get commande_details_om;

  /// No description provided for @commande_details_wave.
  ///
  /// In en, this message translates to:
  /// **'Wave'**
  String get commande_details_wave;

  /// No description provided for @commande_details_cinetpay.
  ///
  /// In en, this message translates to:
  /// **'Mobile Money (CinetPay)'**
  String get commande_details_cinetpay;

  /// No description provided for @commande_details_items.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get commande_details_items;

  /// No description provided for @commande_details_no_items.
  ///
  /// In en, this message translates to:
  /// **'No items'**
  String get commande_details_no_items;

  /// No description provided for @commande_details_address.
  ///
  /// In en, this message translates to:
  /// **'Delivery address'**
  String get commande_details_address;

  /// No description provided for @commande_details_driver_position.
  ///
  /// In en, this message translates to:
  /// **'Driver position'**
  String get commande_details_driver_position;

  /// No description provided for @commande_details_status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get commande_details_status;

  /// No description provided for @commande_details_message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get commande_details_message;

  /// No description provided for @commande_details_rate_restaurant.
  ///
  /// In en, this message translates to:
  /// **'Rate the restaurant'**
  String get commande_details_rate_restaurant;

  /// No description provided for @commande_details_rate_driver.
  ///
  /// In en, this message translates to:
  /// **'Rate the driver'**
  String get commande_details_rate_driver;

  /// No description provided for @commande_details_waiting_assign.
  ///
  /// In en, this message translates to:
  /// **'Waiting for assignment'**
  String get commande_details_waiting_assign;

  /// No description provided for @commande_details_ordered.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get commande_details_ordered;

  /// No description provided for @commande_details_confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get commande_details_confirmed;

  /// No description provided for @commande_details_delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get commande_details_delivered;

  /// No description provided for @commande_details_cancelled.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled'**
  String get commande_details_cancelled;

  /// No description provided for @sales_title.
  ///
  /// In en, this message translates to:
  /// **'My sales'**
  String get sales_title;

  /// No description provided for @sales_no_sales.
  ///
  /// In en, this message translates to:
  /// **'No sales.'**
  String get sales_no_sales;

  /// No description provided for @sales_revenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get sales_revenue;

  /// No description provided for @sales_delivery_fees.
  ///
  /// In en, this message translates to:
  /// **'Delivery fees: '**
  String get sales_delivery_fees;

  /// No description provided for @my_products_title.
  ///
  /// In en, this message translates to:
  /// **'My dishes'**
  String get my_products_title;

  /// No description provided for @my_products_no_products.
  ///
  /// In en, this message translates to:
  /// **'No dishes.'**
  String get my_products_no_products;

  /// No description provided for @my_products_add.
  ///
  /// In en, this message translates to:
  /// **'Add a dish'**
  String get my_products_add;

  /// No description provided for @menu_no_dishes.
  ///
  /// In en, this message translates to:
  /// **'No dishes in your menu.'**
  String get menu_no_dishes;

  /// No description provided for @menu_add_first_dish.
  ///
  /// In en, this message translates to:
  /// **'Add your first dish!'**
  String get menu_add_first_dish;

  /// No description provided for @contact_need_help.
  ///
  /// In en, this message translates to:
  /// **'Need help?'**
  String get contact_need_help;

  /// No description provided for @contact_description.
  ///
  /// In en, this message translates to:
  /// **'Contact us for any questions or changes to your information.'**
  String get contact_description;

  /// No description provided for @contact_chat_hours.
  ///
  /// In en, this message translates to:
  /// **'Available from 9am to 6pm'**
  String get contact_chat_hours;

  /// No description provided for @contact_chat_soon.
  ///
  /// In en, this message translates to:
  /// **'Chat coming soon!'**
  String get contact_chat_soon;

  /// No description provided for @chat_no_conversations.
  ///
  /// In en, this message translates to:
  /// **'No conversations.'**
  String get chat_no_conversations;

  /// No description provided for @chat_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Your exchanges will appear here.'**
  String get chat_placeholder;

  /// No description provided for @chat_unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get chat_unknown;

  /// No description provided for @chat_first_message.
  ///
  /// In en, this message translates to:
  /// **'Send a first message!'**
  String get chat_first_message;

  /// No description provided for @explore_title.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore_title;

  /// No description provided for @explore_no_dishes.
  ///
  /// In en, this message translates to:
  /// **'No dishes available.'**
  String get explore_no_dishes;

  /// No description provided for @near_meals_title.
  ///
  /// In en, this message translates to:
  /// **'Meals nearby'**
  String get near_meals_title;

  /// No description provided for @near_meals_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search for a dish or restaurant'**
  String get near_meals_search_hint;

  /// No description provided for @near_meals_filter_open.
  ///
  /// In en, this message translates to:
  /// **'Open restaurants'**
  String get near_meals_filter_open;

  /// No description provided for @near_meals_no_results.
  ///
  /// In en, this message translates to:
  /// **'No dishes found with these filters.'**
  String get near_meals_no_results;

  /// No description provided for @food_categories_title.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get food_categories_title;

  /// No description provided for @promo_create_title.
  ///
  /// In en, this message translates to:
  /// **'Create promo code'**
  String get promo_create_title;

  /// No description provided for @promo_code_label.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get promo_code_label;

  /// No description provided for @promo_required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get promo_required;

  /// No description provided for @promo_discount_type.
  ///
  /// In en, this message translates to:
  /// **'Discount type'**
  String get promo_discount_type;

  /// No description provided for @promo_percentage.
  ///
  /// In en, this message translates to:
  /// **'Percentage (%)'**
  String get promo_percentage;

  /// No description provided for @promo_fixed_amount.
  ///
  /// In en, this message translates to:
  /// **'Fixed amount (€)'**
  String get promo_fixed_amount;

  /// No description provided for @promo_value_percent.
  ///
  /// In en, this message translates to:
  /// **'Value (%)'**
  String get promo_value_percent;

  /// No description provided for @promo_value_fixed.
  ///
  /// In en, this message translates to:
  /// **'Value (€)'**
  String get promo_value_fixed;

  /// No description provided for @promo_min_order.
  ///
  /// In en, this message translates to:
  /// **'Minimum order amount (€)'**
  String get promo_min_order;

  /// No description provided for @promo_valid_from.
  ///
  /// In en, this message translates to:
  /// **'Valid from'**
  String get promo_valid_from;

  /// No description provided for @promo_valid_until.
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get promo_valid_until;

  /// No description provided for @promo_select_date.
  ///
  /// In en, this message translates to:
  /// **'Select a date'**
  String get promo_select_date;

  /// No description provided for @promo_max_uses.
  ///
  /// In en, this message translates to:
  /// **'Max uses (optional)'**
  String get promo_max_uses;

  /// No description provided for @promo_description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get promo_description;

  /// No description provided for @promo_created.
  ///
  /// In en, this message translates to:
  /// **'Promo code created!'**
  String get promo_created;

  /// No description provided for @promo_submit.
  ///
  /// In en, this message translates to:
  /// **'Create promo code'**
  String get promo_submit;

  /// No description provided for @promo_title.
  ///
  /// In en, this message translates to:
  /// **'Promotions & Promo Codes'**
  String get promo_title;

  /// No description provided for @promo_empty.
  ///
  /// In en, this message translates to:
  /// **'No promo codes'**
  String get promo_empty;

  /// No description provided for @promo_empty_hint.
  ///
  /// In en, this message translates to:
  /// **'Add your first promo code'**
  String get promo_empty_hint;

  /// No description provided for @promo_create_code.
  ///
  /// In en, this message translates to:
  /// **'Create a code'**
  String get promo_create_code;

  /// No description provided for @promo_active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get promo_active;

  /// No description provided for @promo_inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get promo_inactive;

  /// No description provided for @category_manage_title.
  ///
  /// In en, this message translates to:
  /// **'Manage categories'**
  String get category_manage_title;

  /// No description provided for @category_name_required.
  ///
  /// In en, this message translates to:
  /// **'Please enter a category name.'**
  String get category_name_required;

  /// No description provided for @category_added.
  ///
  /// In en, this message translates to:
  /// **'Category added.'**
  String get category_added;

  /// No description provided for @category_add_error.
  ///
  /// In en, this message translates to:
  /// **'Error adding category.'**
  String get category_add_error;

  /// No description provided for @category_delete_confirm.
  ///
  /// In en, this message translates to:
  /// **'Delete category \"{name}\"?'**
  String category_delete_confirm(Object name);

  /// No description provided for @category_deleted.
  ///
  /// In en, this message translates to:
  /// **'Category deleted.'**
  String get category_deleted;

  /// No description provided for @category_delete_error.
  ///
  /// In en, this message translates to:
  /// **'Error deleting category.'**
  String get category_delete_error;

  /// No description provided for @category_new_hint.
  ///
  /// In en, this message translates to:
  /// **'New category...'**
  String get category_new_hint;

  /// No description provided for @category_add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get category_add;

  /// No description provided for @category_empty.
  ///
  /// In en, this message translates to:
  /// **'No categories.'**
  String get category_empty;

  /// No description provided for @category_delete_title.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get category_delete_title;

  /// No description provided for @scheduled_deletions_title.
  ///
  /// In en, this message translates to:
  /// **'Scheduled deletions'**
  String get scheduled_deletions_title;

  /// No description provided for @scheduled_deletions_empty.
  ///
  /// In en, this message translates to:
  /// **'No scheduled deletions'**
  String get scheduled_deletions_empty;

  /// No description provided for @scheduled_deletions_all_active.
  ///
  /// In en, this message translates to:
  /// **'All accounts are active for {country}'**
  String scheduled_deletions_all_active(Object country);

  /// No description provided for @scheduled_deletions_restore_title.
  ///
  /// In en, this message translates to:
  /// **'Restore user'**
  String get scheduled_deletions_restore_title;

  /// No description provided for @scheduled_deletions_restore_confirm.
  ///
  /// In en, this message translates to:
  /// **'Do you want to restore \"{firstname} {lastname}\"?\n\nTheir account will be reactivated with \"active\" status.'**
  String scheduled_deletions_restore_confirm(Object firstname, Object lastname);

  /// No description provided for @scheduled_deletions_restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get scheduled_deletions_restore;

  /// No description provided for @scheduled_deletions_restored.
  ///
  /// In en, this message translates to:
  /// **'{firstname} {lastname} restored ✓'**
  String scheduled_deletions_restored(Object firstname, Object lastname);

  /// No description provided for @scheduled_deletions_permanent_title.
  ///
  /// In en, this message translates to:
  /// **'Permanent deletion'**
  String get scheduled_deletions_permanent_title;

  /// No description provided for @scheduled_deletions_permanent_confirm.
  ///
  /// In en, this message translates to:
  /// **'Do you want to permanently delete \"{firstname} {lastname}\"?\n\nThis action is irreversible. All associated data will be lost.'**
  String scheduled_deletions_permanent_confirm(
      Object firstname, Object lastname);

  /// No description provided for @scheduled_deletions_permanent_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get scheduled_deletions_permanent_delete;

  /// No description provided for @scheduled_deletions_deleted.
  ///
  /// In en, this message translates to:
  /// **'{firstname} {lastname} permanently deleted'**
  String scheduled_deletions_deleted(Object firstname, Object lastname);

  /// No description provided for @scheduled_deletions_pending.
  ///
  /// In en, this message translates to:
  /// **'{count} deletion(s) pending'**
  String scheduled_deletions_pending(Object count);

  /// No description provided for @scheduled_deletions_period.
  ///
  /// In en, this message translates to:
  /// **'Period of {days}d'**
  String scheduled_deletions_period(Object days);

  /// No description provided for @scheduled_deletions_requested_on.
  ///
  /// In en, this message translates to:
  /// **'Requested on {date}'**
  String scheduled_deletions_requested_on(Object date);

  /// No description provided for @scheduled_deletions_last_day.
  ///
  /// In en, this message translates to:
  /// **'Last day'**
  String get scheduled_deletions_last_day;

  /// No description provided for @scheduled_deletions_days_elapsed.
  ///
  /// In en, this message translates to:
  /// **'{days}d elapsed'**
  String scheduled_deletions_days_elapsed(Object days);

  /// No description provided for @scheduled_deletions_days_remaining.
  ///
  /// In en, this message translates to:
  /// **'{days}d remaining'**
  String scheduled_deletions_days_remaining(Object days);

  /// No description provided for @audit_log_title.
  ///
  /// In en, this message translates to:
  /// **'Audit Log — {country}'**
  String audit_log_title(Object country);

  /// No description provided for @audit_log_empty.
  ///
  /// In en, this message translates to:
  /// **'No logs for this country.'**
  String get audit_log_empty;

  /// No description provided for @support_chat_title.
  ///
  /// In en, this message translates to:
  /// **'Support Messaging — {country}'**
  String support_chat_title(Object country);

  /// No description provided for @support_chat_search_hint.
  ///
  /// In en, this message translates to:
  /// **'Search users…'**
  String get support_chat_search_hint;

  /// No description provided for @support_chat_no_results.
  ///
  /// In en, this message translates to:
  /// **'No users found.'**
  String get support_chat_no_results;

  /// No description provided for @referral_title.
  ///
  /// In en, this message translates to:
  /// **'Referral'**
  String get referral_title;

  /// No description provided for @referral_godchildren.
  ///
  /// In en, this message translates to:
  /// **'Godchildren'**
  String get referral_godchildren;

  /// No description provided for @referral_active_codes.
  ///
  /// In en, this message translates to:
  /// **'Active codes'**
  String get referral_active_codes;

  /// No description provided for @referral_rewards.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get referral_rewards;

  /// No description provided for @referral_codes_section.
  ///
  /// In en, this message translates to:
  /// **'Referral codes'**
  String get referral_codes_section;

  /// No description provided for @referral_empty.
  ///
  /// In en, this message translates to:
  /// **'No referral codes'**
  String get referral_empty;

  /// No description provided for @referral_empty_hint.
  ///
  /// In en, this message translates to:
  /// **'Referral codes will appear here when users create them.'**
  String get referral_empty_hint;

  /// No description provided for @wait_identity_title.
  ///
  /// In en, this message translates to:
  /// **'Your identity has not been validated yet.'**
  String get wait_identity_title;

  /// No description provided for @wait_identity_body.
  ///
  /// In en, this message translates to:
  /// **'You will receive an email when our administrators have reviewed your information.'**
  String get wait_identity_body;

  /// No description provided for @wait_restaurant_title.
  ///
  /// In en, this message translates to:
  /// **'Your restaurant has not been validated yet.'**
  String get wait_restaurant_title;

  /// No description provided for @wait_restaurant_body.
  ///
  /// In en, this message translates to:
  /// **'You will receive an email if your restaurant idea is accepted.'**
  String get wait_restaurant_body;

  /// No description provided for @verification_email_missing.
  ///
  /// In en, this message translates to:
  /// **'Email address not found. Please reconnect.'**
  String get verification_email_missing;

  /// No description provided for @verification_sending.
  ///
  /// In en, this message translates to:
  /// **'Sending verification code...'**
  String get verification_sending;

  /// No description provided for @verification_reconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get verification_reconnect;

  /// No description provided for @dishes.
  ///
  /// In en, this message translates to:
  /// **'Dishes'**
  String get dishes;

  /// No description provided for @identity_naming_error.
  ///
  /// In en, this message translates to:
  /// **'Error: check that your file names follow naming conventions.'**
  String get identity_naming_error;

  /// No description provided for @orderCancelled.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled'**
  String get orderCancelled;

  /// No description provided for @user_orders_new_orders_hint.
  ///
  /// In en, this message translates to:
  /// **'New orders will appear here in real time.'**
  String get user_orders_new_orders_hint;

  /// No description provided for @user_orders_past_orders_hint.
  ///
  /// In en, this message translates to:
  /// **'Your past orders will appear here.'**
  String get user_orders_past_orders_hint;

  /// No description provided for @user_orders_pending_title.
  ///
  /// In en, this message translates to:
  /// **'Restaurant pending validation'**
  String get user_orders_pending_title;

  /// No description provided for @user_orders_pending_body.
  ///
  /// In en, this message translates to:
  /// **'Your restaurant is being reviewed by our administrators. You will be able to receive orders once it is validated.'**
  String get user_orders_pending_body;

  /// No description provided for @user_orders_notified_email.
  ///
  /// In en, this message translates to:
  /// **'You will be notified by email'**
  String get user_orders_notified_email;

  /// No description provided for @user_orders_receive_orders.
  ///
  /// In en, this message translates to:
  /// **'And receive orders'**
  String get user_orders_receive_orders;

  /// No description provided for @commande_details_load_error.
  ///
  /// In en, this message translates to:
  /// **'Unable to load details'**
  String get commande_details_load_error;

  /// No description provided for @commande_details_actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get commande_details_actions;

  /// No description provided for @commande_details_tracking.
  ///
  /// In en, this message translates to:
  /// **'Order tracking'**
  String get commande_details_tracking;

  /// No description provided for @commande_details_item_count.
  ///
  /// In en, this message translates to:
  /// **'{count} item(s)'**
  String commande_details_item_count(Object count);

  /// No description provided for @commande_details_rating_label.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get commande_details_rating_label;

  /// No description provided for @commande_details_livraison.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get commande_details_livraison;

  /// No description provided for @commande_details_reduction.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get commande_details_reduction;

  /// No description provided for @delivery_status_pending_assign.
  ///
  /// In en, this message translates to:
  /// **'Awaiting assignment'**
  String get delivery_status_pending_assign;

  /// No description provided for @store_pending_validation.
  ///
  /// In en, this message translates to:
  /// **'Pending validation'**
  String get store_pending_validation;

  /// No description provided for @store_pending_validation_body.
  ///
  /// In en, this message translates to:
  /// **'Your restaurant is being reviewed. You will be able to manage your restaurant, add dishes, and receive orders once it is validated.'**
  String get store_pending_validation_body;

  /// No description provided for @delivery_livraison_label.
  ///
  /// In en, this message translates to:
  /// **'Delivery: {amount}'**
  String delivery_livraison_label(Object amount);

  /// No description provided for @tracking_paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get tracking_paid;

  /// No description provided for @tracking_confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get tracking_confirmed;

  /// No description provided for @tracking_pending_label.
  ///
  /// In en, this message translates to:
  /// **'Order created, awaiting confirmation.'**
  String get tracking_pending_label;

  /// No description provided for @tracking_paid_label.
  ///
  /// In en, this message translates to:
  /// **'Payment confirmed, the restaurant is processing the order.'**
  String get tracking_paid_label;

  /// No description provided for @tracking_confirmed_label.
  ///
  /// In en, this message translates to:
  /// **'Order confirmed, being prepared.'**
  String get tracking_confirmed_label;

  /// No description provided for @tracking_cancelled_label.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled.'**
  String get tracking_cancelled_label;

  /// No description provided for @country_select_hint.
  ///
  /// In en, this message translates to:
  /// **'Select a country'**
  String get country_select_hint;

  /// No description provided for @error_with_message.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String error_with_message(Object message);

  /// No description provided for @favorites_title.
  ///
  /// In en, this message translates to:
  /// **'My favorites'**
  String get favorites_title;

  /// No description provided for @favorites_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Find your favorite restaurants and dishes.'**
  String get favorites_subtitle;

  /// No description provided for @favorites_empty_restaurants.
  ///
  /// In en, this message translates to:
  /// **'No favorite restaurants.'**
  String get favorites_empty_restaurants;

  /// No description provided for @favorites_empty_dishes.
  ///
  /// In en, this message translates to:
  /// **'No favorite dishes.'**
  String get favorites_empty_dishes;

  /// No description provided for @favorites_restaurants_tab.
  ///
  /// In en, this message translates to:
  /// **'Restaurants'**
  String get favorites_restaurants_tab;

  /// No description provided for @favorites_dishes_tab.
  ///
  /// In en, this message translates to:
  /// **'Dishes'**
  String get favorites_dishes_tab;

  /// No description provided for @guest_title.
  ///
  /// In en, this message translates to:
  /// **'Dios Délices'**
  String get guest_title;

  /// No description provided for @guest_login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get guest_login;

  /// No description provided for @guest_no_restaurants.
  ///
  /// In en, this message translates to:
  /// **'No restaurants available.'**
  String get guest_no_restaurants;

  /// No description provided for @guest_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get guest_all;

  /// No description provided for @location_disabled.
  ///
  /// In en, this message translates to:
  /// **'Location disabled. Enable it in settings.'**
  String get location_disabled;

  /// No description provided for @location_detect_failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to detect location.'**
  String get location_detect_failed;

  /// No description provided for @location_my_address.
  ///
  /// In en, this message translates to:
  /// **'My address'**
  String get location_my_address;

  /// No description provided for @location_instruction.
  ///
  /// In en, this message translates to:
  /// **'Enter your address to receive your orders.'**
  String get location_instruction;

  /// No description provided for @location_get.
  ///
  /// In en, this message translates to:
  /// **'Get my location'**
  String get location_get;

  /// No description provided for @location_locating.
  ///
  /// In en, this message translates to:
  /// **'Locating...'**
  String get location_locating;

  /// No description provided for @search_no_results.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String search_no_results(Object query);

  /// No description provided for @search_restaurants.
  ///
  /// In en, this message translates to:
  /// **'Restaurants'**
  String get search_restaurants;

  /// No description provided for @search_dishes.
  ///
  /// In en, this message translates to:
  /// **'Dishes'**
  String get search_dishes;

  /// No description provided for @search_input_hint.
  ///
  /// In en, this message translates to:
  /// **'Search for dishes, restaurants...'**
  String get search_input_hint;

  /// No description provided for @country_title.
  ///
  /// In en, this message translates to:
  /// **'Manage {title}'**
  String country_title(Object title);

  /// No description provided for @country_view.
  ///
  /// In en, this message translates to:
  /// **'View {title} in {name}'**
  String country_view(Object title, Object name);

  /// No description provided for @order_tracking_paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get order_tracking_paid;

  /// No description provided for @order_tracking_confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get order_tracking_confirmed;

  /// No description provided for @order_tracking_cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get order_tracking_cancelled;

  /// No description provided for @pro_request_title.
  ///
  /// In en, this message translates to:
  /// **'Become Pro'**
  String get pro_request_title;

  /// No description provided for @pro_request_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Submit your documents to upgrade to a professional account.'**
  String get pro_request_subtitle;

  /// No description provided for @pro_request_description_label.
  ///
  /// In en, this message translates to:
  /// **'Your request'**
  String get pro_request_description_label;

  /// No description provided for @pro_request_description_hint.
  ///
  /// In en, this message translates to:
  /// **'Tell us who you are, what you do, and why you want to become a Pro...'**
  String get pro_request_description_hint;

  /// No description provided for @pro_request_identity_doc.
  ///
  /// In en, this message translates to:
  /// **'Identity document'**
  String get pro_request_identity_doc;

  /// No description provided for @pro_request_pro_doc.
  ///
  /// In en, this message translates to:
  /// **'Professional document'**
  String get pro_request_pro_doc;

  /// No description provided for @pro_request_pick_file.
  ///
  /// In en, this message translates to:
  /// **'Select a file'**
  String get pro_request_pick_file;

  /// No description provided for @pro_request_file_selected.
  ///
  /// In en, this message translates to:
  /// **'File selected'**
  String get pro_request_file_selected;

  /// No description provided for @pro_request_no_file.
  ///
  /// In en, this message translates to:
  /// **'No file selected'**
  String get pro_request_no_file;

  /// No description provided for @pro_request_submit.
  ///
  /// In en, this message translates to:
  /// **'Send my request'**
  String get pro_request_submit;

  /// No description provided for @pro_request_success.
  ///
  /// In en, this message translates to:
  /// **'Your request has been sent. We will review it shortly.'**
  String get pro_request_success;

  /// No description provided for @pro_request_error_description.
  ///
  /// In en, this message translates to:
  /// **'Please write a description of your request.'**
  String get pro_request_error_description;

  /// No description provided for @pro_request_error_identity.
  ///
  /// In en, this message translates to:
  /// **'Please attach your identity document.'**
  String get pro_request_error_identity;

  /// No description provided for @pro_request_error_pro_doc.
  ///
  /// In en, this message translates to:
  /// **'Please attach a professional document.'**
  String get pro_request_error_pro_doc;

  /// No description provided for @promo_activate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get promo_activate;

  /// No description provided for @promo_deactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get promo_deactivate;

  /// No description provided for @promo_delete_confirm.
  ///
  /// In en, this message translates to:
  /// **'Delete promo code?'**
  String get promo_delete_confirm;

  /// No description provided for @promo_edit_title.
  ///
  /// In en, this message translates to:
  /// **'Edit promo'**
  String get promo_edit_title;

  /// No description provided for @role_admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get role_admin;

  /// No description provided for @role_client.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get role_client;

  /// No description provided for @role_restaurateur.
  ///
  /// In en, this message translates to:
  /// **'Chef'**
  String get role_restaurateur;

  /// No description provided for @role_livreur.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get role_livreur;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @verification_email_exists.
  ///
  /// In en, this message translates to:
  /// **'This email is already in use.'**
  String get verification_email_exists;

  /// No description provided for @home_add_address_banner.
  ///
  /// In en, this message translates to:
  /// **'Add your address to see restaurants near you.'**
  String get home_add_address_banner;

  /// No description provided for @welcome_title.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Dios Délices'**
  String get welcome_title;

  /// No description provided for @welcome_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your account has been created.'**
  String get welcome_subtitle;

  /// No description provided for @welcome_discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get welcome_discover;

  /// No description provided for @store_unverified_title.
  ///
  /// In en, this message translates to:
  /// **'Account not verified'**
  String get store_unverified_title;

  /// No description provided for @store_unverified_body.
  ///
  /// In en, this message translates to:
  /// **'Your account has not been verified yet. Our team will review it shortly.\n\nYou can contact the administrators for more information.'**
  String get store_unverified_body;

  /// No description provided for @test_notification_sent.
  ///
  /// In en, this message translates to:
  /// **'Test notification sent!'**
  String get test_notification_sent;

  /// No description provided for @notif_orders_title.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get notif_orders_title;

  /// No description provided for @notif_orders_desc.
  ///
  /// In en, this message translates to:
  /// **'Order status notifications'**
  String get notif_orders_desc;

  /// No description provided for @notif_promos_title.
  ///
  /// In en, this message translates to:
  /// **'Promotions'**
  String get notif_promos_title;

  /// No description provided for @notif_promos_desc.
  ///
  /// In en, this message translates to:
  /// **'Special offers and discounts'**
  String get notif_promos_desc;

  /// No description provided for @notif_chat_title.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get notif_chat_title;

  /// No description provided for @notif_chat_desc.
  ///
  /// In en, this message translates to:
  /// **'New chat messages'**
  String get notif_chat_desc;

  /// No description provided for @delivery_preferences.
  ///
  /// In en, this message translates to:
  /// **'Delivery preferences'**
  String get delivery_preferences;

  /// No description provided for @max_delivery_distance.
  ///
  /// In en, this message translates to:
  /// **'Max delivery distance'**
  String get max_delivery_distance;

  /// No description provided for @max_delivery_distance_desc.
  ///
  /// In en, this message translates to:
  /// **'Maximum distance for your deliveries: {distance} km'**
  String max_delivery_distance_desc(Object distance);

  /// No description provided for @sell_your_dishes.
  ///
  /// In en, this message translates to:
  /// **'Sell your dishes'**
  String get sell_your_dishes;

  /// No description provided for @app_tagline.
  ///
  /// In en, this message translates to:
  /// **'Neighborhood cuisine, warmer and simpler.'**
  String get app_tagline;

  /// No description provided for @delete_account_understand_hint.
  ///
  /// In en, this message translates to:
  /// **'I understand my data will be deleted after 30 days. If I want to recover my account before then, I must contact the administrators.'**
  String get delete_account_understand_hint;

  /// No description provided for @delete_account_recovery_hint.
  ///
  /// In en, this message translates to:
  /// **'If you wish to recover your account before this deadline, contact the administrators.'**
  String get delete_account_recovery_hint;

  /// No description provided for @confirm_your_email.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email'**
  String get confirm_your_email;

  /// No description provided for @identity_validated_email_subject.
  ///
  /// In en, this message translates to:
  /// **'🎉 Welcome to Dios Délices - Your profile is validated!'**
  String get identity_validated_email_subject;

  /// No description provided for @identity_rejected_email_subject.
  ///
  /// In en, this message translates to:
  /// **'❌ Update: Your profile validation on Dios Délices'**
  String get identity_rejected_email_subject;

  /// No description provided for @identity_validated_email_body.
  ///
  /// In en, this message translates to:
  /// **'Hello {firstname},\n\nWe are delighted to inform you that your profile on Dios Délices has been validated. You can now fully enjoy all the features of the application.\n\nWelcome aboard!\n\nThe Dios Délices team'**
  String identity_validated_email_body(Object firstname);

  /// No description provided for @identity_rejected_email_body.
  ///
  /// In en, this message translates to:
  /// **'Hello {firstname},\n\nWe regret to inform you that your profile on Dios Délices could not be validated at this time.\n\nReason: {reason}\n\nYou can modify your information and resubmit your request from the application.\n\nThe Dios Délices team'**
  String identity_rejected_email_body(Object firstname, Object reason);

  /// No description provided for @address_detected.
  ///
  /// In en, this message translates to:
  /// **'Detected address'**
  String get address_detected;

  /// No description provided for @address_detected_label.
  ///
  /// In en, this message translates to:
  /// **'Detected address:'**
  String get address_detected_label;

  /// No description provided for @address_manual_label.
  ///
  /// In en, this message translates to:
  /// **'Manual address:'**
  String get address_manual_label;

  /// No description provided for @which_address_use.
  ///
  /// In en, this message translates to:
  /// **'Which address to use?'**
  String get which_address_use;

  /// No description provided for @manual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manual;

  /// No description provided for @detected.
  ///
  /// In en, this message translates to:
  /// **'Detected'**
  String get detected;

  /// No description provided for @save_address.
  ///
  /// In en, this message translates to:
  /// **'Save address'**
  String get save_address;

  /// No description provided for @address_already_saved.
  ///
  /// In en, this message translates to:
  /// **'Address already saved.'**
  String get address_already_saved;

  /// No description provided for @address_saved_success.
  ///
  /// In en, this message translates to:
  /// **'Address saved successfully!'**
  String get address_saved_success;

  /// No description provided for @address_fill_city_and_address.
  ///
  /// In en, this message translates to:
  /// **'Please fill in at least the city and full address.'**
  String get address_fill_city_and_address;

  /// No description provided for @address_not_found_check.
  ///
  /// In en, this message translates to:
  /// **'Address not found. Please verify accuracy.'**
  String get address_not_found_check;

  /// No description provided for @address_not_found_verify.
  ///
  /// In en, this message translates to:
  /// **'Address not found, please verify the information.'**
  String get address_not_found_verify;

  /// No description provided for @address_not_match_country.
  ///
  /// In en, this message translates to:
  /// **'Your address ({address}) does not match your country. Please check.'**
  String address_not_match_country(Object address);

  /// No description provided for @enter_address_manually.
  ///
  /// In en, this message translates to:
  /// **'Enter my address manually'**
  String get enter_address_manually;

  /// No description provided for @hide_form.
  ///
  /// In en, this message translates to:
  /// **'Hide form'**
  String get hide_form;

  /// No description provided for @full_address_hint.
  ///
  /// In en, this message translates to:
  /// **'Full address (street, building, directions...)'**
  String get full_address_hint;

  /// No description provided for @district.
  ///
  /// In en, this message translates to:
  /// **'District / Borough'**
  String get district;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @enter_or_detect_address.
  ///
  /// In en, this message translates to:
  /// **'Please enter or detect an address.'**
  String get enter_or_detect_address;

  /// No description provided for @pending_orders.
  ///
  /// In en, this message translates to:
  /// **'Pending orders'**
  String get pending_orders;

  /// No description provided for @to_process.
  ///
  /// In en, this message translates to:
  /// **'To process'**
  String get to_process;

  /// No description provided for @cancelled_orders.
  ///
  /// In en, this message translates to:
  /// **'Cancelled orders'**
  String get cancelled_orders;

  /// No description provided for @available_dishes.
  ///
  /// In en, this message translates to:
  /// **'Available dishes'**
  String get available_dishes;

  /// No description provided for @servings_sold.
  ///
  /// In en, this message translates to:
  /// **'Servings sold'**
  String get servings_sold;

  /// No description provided for @unavailable_dishes_num.
  ///
  /// In en, this message translates to:
  /// **'{count} unavailable'**
  String unavailable_dishes_num(Object count);

  /// No description provided for @available_servings_of.
  ///
  /// In en, this message translates to:
  /// **'/ {total} available'**
  String available_servings_of(Object total);

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @last_orders.
  ///
  /// In en, this message translates to:
  /// **'Last orders'**
  String get last_orders;

  /// No description provided for @see_all.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get see_all;

  /// No description provided for @no_order_received_yet.
  ///
  /// In en, this message translates to:
  /// **'No order received yet.'**
  String get no_order_received_yet;

  /// No description provided for @dishes_and_servings.
  ///
  /// In en, this message translates to:
  /// **'Dishes & servings'**
  String get dishes_and_servings;

  /// No description provided for @activate_deactivate_dishes.
  ///
  /// In en, this message translates to:
  /// **'Activate or deactivate your dishes'**
  String get activate_deactivate_dishes;

  /// No description provided for @no_dish_registered.
  ///
  /// In en, this message translates to:
  /// **'No dishes registered.'**
  String get no_dish_registered;

  /// No description provided for @no_restaurant_available.
  ///
  /// In en, this message translates to:
  /// **'No restaurant available'**
  String get no_restaurant_available;

  /// No description provided for @owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get owner;

  /// No description provided for @pro_badge.
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get pro_badge;

  /// No description provided for @owner_info.
  ///
  /// In en, this message translates to:
  /// **'Owner: {firstname} · {email}'**
  String owner_info(Object firstname, Object email);

  /// No description provided for @user_details_information.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get user_details_information;

  /// No description provided for @user_details_firstname.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get user_details_firstname;

  /// No description provided for @user_details_lastname.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get user_details_lastname;

  /// No description provided for @user_details_email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get user_details_email;

  /// No description provided for @user_details_phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get user_details_phone;

  /// No description provided for @user_details_country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get user_details_country;

  /// No description provided for @user_details_profile_type.
  ///
  /// In en, this message translates to:
  /// **'Profile type'**
  String get user_details_profile_type;

  /// No description provided for @user_details_identity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get user_details_identity;

  /// No description provided for @user_details_required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get user_details_required;

  /// No description provided for @force_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get force_delete;

  /// No description provided for @force_delete_desc.
  ///
  /// In en, this message translates to:
  /// **'Restaurant, dishes, orders, addresses, documents…'**
  String get force_delete_desc;

  /// No description provided for @identity_document_label.
  ///
  /// In en, this message translates to:
  /// **'Identity document'**
  String get identity_document_label;

  /// No description provided for @pdf_document.
  ///
  /// In en, this message translates to:
  /// **'PDF Document'**
  String get pdf_document;

  /// No description provided for @tap_to_open.
  ///
  /// In en, this message translates to:
  /// **'Tap to open'**
  String get tap_to_open;

  /// No description provided for @validation.
  ///
  /// In en, this message translates to:
  /// **'Validation'**
  String get validation;

  /// No description provided for @reject_profile.
  ///
  /// In en, this message translates to:
  /// **'Reject profile'**
  String get reject_profile;

  /// No description provided for @reject_profile_remark_hint.
  ///
  /// In en, this message translates to:
  /// **'Add a remark for the user:'**
  String get reject_profile_remark_hint;

  /// No description provided for @type_your_remark_hint.
  ///
  /// In en, this message translates to:
  /// **'Type your remark here...'**
  String get type_your_remark_hint;

  /// No description provided for @delete_permanently.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get delete_permanently;

  /// No description provided for @delete_confirm_message.
  ///
  /// In en, this message translates to:
  /// **'This will delete ALL data:\n• Restaurant & dishes\n• Addresses\n• Payment methods\n• Orders & lines\n• Comments\n• Documents\n• Messages\n• Reports\n\nIRREVERSIBLE.'**
  String get delete_confirm_message;

  /// No description provided for @type_delete_to_confirm.
  ///
  /// In en, this message translates to:
  /// **'Type \"DELETE\" to confirm'**
  String get type_delete_to_confirm;

  /// No description provided for @must_type_delete.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE to confirm'**
  String get must_type_delete;

  /// No description provided for @user_deleted.
  ///
  /// In en, this message translates to:
  /// **'{firstname} deleted.'**
  String user_deleted(Object firstname);

  /// No description provided for @force_delete_button.
  ///
  /// In en, this message translates to:
  /// **'DELETE ALL'**
  String get force_delete_button;

  /// No description provided for @profile_validated_email_sent.
  ///
  /// In en, this message translates to:
  /// **'{firstname} {lastname}\'s profile has been validated and an email has been sent.'**
  String profile_validated_email_sent(Object firstname, Object lastname);

  /// No description provided for @profile_validated_email_error.
  ///
  /// In en, this message translates to:
  /// **'Profile validated but error sending email.'**
  String get profile_validated_email_error;

  /// No description provided for @profile_rejected_email_sent.
  ///
  /// In en, this message translates to:
  /// **'{firstname} {lastname}\'s profile has been rejected and an email has been sent.'**
  String profile_rejected_email_sent(Object firstname, Object lastname);

  /// No description provided for @profile_rejected_email_error.
  ///
  /// In en, this message translates to:
  /// **'Profile rejected but error sending email.'**
  String get profile_rejected_email_error;

  /// No description provided for @view_existing_file.
  ///
  /// In en, this message translates to:
  /// **'View existing file'**
  String get view_existing_file;

  /// No description provided for @no_photo_available.
  ///
  /// In en, this message translates to:
  /// **'No photo available'**
  String get no_photo_available;

  /// No description provided for @add_a_photo.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get add_a_photo;

  /// No description provided for @add_identity_document.
  ///
  /// In en, this message translates to:
  /// **'Add an ID document'**
  String get add_identity_document;

  /// No description provided for @validate_caps.
  ///
  /// In en, this message translates to:
  /// **'VALIDATE'**
  String get validate_caps;

  /// No description provided for @restaurant_associated.
  ///
  /// In en, this message translates to:
  /// **'Associated restaurant'**
  String get restaurant_associated;

  /// No description provided for @no_file_selected.
  ///
  /// In en, this message translates to:
  /// **'No file selected'**
  String get no_file_selected;

  /// No description provided for @choose_from_files.
  ///
  /// In en, this message translates to:
  /// **'Choose from files'**
  String get choose_from_files;

  /// No description provided for @image_or_pdf.
  ///
  /// In en, this message translates to:
  /// **'Image or PDF'**
  String get image_or_pdf;

  /// No description provided for @pdf_preview.
  ///
  /// In en, this message translates to:
  /// **'PDF Preview'**
  String get pdf_preview;

  /// No description provided for @image_preview.
  ///
  /// In en, this message translates to:
  /// **'Image Preview'**
  String get image_preview;

  /// No description provided for @take_a_photo.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get take_a_photo;

  /// No description provided for @choose_from_gallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get choose_from_gallery;

  /// No description provided for @choose_image_file.
  ///
  /// In en, this message translates to:
  /// **'Choose an image file'**
  String get choose_image_file;

  /// No description provided for @choose_image_from_gallery.
  ///
  /// In en, this message translates to:
  /// **'Choose an image from gallery'**
  String get choose_image_from_gallery;

  /// No description provided for @users_list_title.
  ///
  /// In en, this message translates to:
  /// **'Users · {country}'**
  String users_list_title(Object country);

  /// No description provided for @search_name_email_phone.
  ///
  /// In en, this message translates to:
  /// **'Search name, email, phone...'**
  String get search_name_email_phone;

  /// No description provided for @all_filter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all_filter;

  /// No description provided for @pending_filter.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending_filter;

  /// No description provided for @validated_filter.
  ///
  /// In en, this message translates to:
  /// **'Validated'**
  String get validated_filter;

  /// No description provided for @rejected_filter.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected_filter;

  /// No description provided for @users_count.
  ///
  /// In en, this message translates to:
  /// **'{displayed} / {total} user(s)'**
  String users_count(Object displayed, Object total);

  /// No description provided for @pending_count.
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String pending_count(Object count);

  /// No description provided for @validated_count.
  ///
  /// In en, this message translates to:
  /// **'{count} validated'**
  String validated_count(Object count);

  /// No description provided for @no_user_found.
  ///
  /// In en, this message translates to:
  /// **'No user found'**
  String get no_user_found;

  /// No description provided for @super_admin.
  ///
  /// In en, this message translates to:
  /// **'Super Admin'**
  String get super_admin;

  /// No description provided for @profile_rejected.
  ///
  /// In en, this message translates to:
  /// **'Profile rejected'**
  String get profile_rejected;

  /// No description provided for @profile_validated.
  ///
  /// In en, this message translates to:
  /// **'Profile validated'**
  String get profile_validated;

  /// No description provided for @profile_pending.
  ///
  /// In en, this message translates to:
  /// **'Profile pending'**
  String get profile_pending;

  /// No description provided for @favorites_my.
  ///
  /// In en, this message translates to:
  /// **'My favorites'**
  String get favorites_my;

  /// No description provided for @no_dishes.
  ///
  /// In en, this message translates to:
  /// **'No dishes.'**
  String get no_dishes;

  /// No description provided for @rate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rate;

  /// No description provided for @user_not_connected.
  ///
  /// In en, this message translates to:
  /// **'User not connected'**
  String get user_not_connected;

  /// No description provided for @ordered_dishes.
  ///
  /// In en, this message translates to:
  /// **'Ordered dishes'**
  String get ordered_dishes;

  /// No description provided for @dish_num.
  ///
  /// In en, this message translates to:
  /// **'Dish #{id}'**
  String dish_num(Object id);

  /// No description provided for @features.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get features;

  /// No description provided for @your_review.
  ///
  /// In en, this message translates to:
  /// **'Your review'**
  String get your_review;

  /// No description provided for @share_experience_hint.
  ///
  /// In en, this message translates to:
  /// **'Share your experience in a few words…'**
  String get share_experience_hint;

  /// No description provided for @no_reviews_yet.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet.'**
  String get no_reviews_yet;

  /// No description provided for @reviews_count.
  ///
  /// In en, this message translates to:
  /// **'{count} avis'**
  String reviews_count(int count);

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @order_tracking_title.
  ///
  /// In en, this message translates to:
  /// **'Order tracking'**
  String get order_tracking_title;

  /// No description provided for @order_num.
  ///
  /// In en, this message translates to:
  /// **'Order #{id}'**
  String order_num(Object id);

  /// No description provided for @delivery_cost.
  ///
  /// In en, this message translates to:
  /// **'Delivery {amount}'**
  String delivery_cost(Object amount);

  /// No description provided for @discount_amount.
  ///
  /// In en, this message translates to:
  /// **'Discount {amount}'**
  String discount_amount(Object amount);

  /// No description provided for @validate_this_image.
  ///
  /// In en, this message translates to:
  /// **'Validate this image'**
  String get validate_this_image;

  /// No description provided for @test_notification_title.
  ///
  /// In en, this message translates to:
  /// **'Test Notification'**
  String get test_notification_title;

  /// No description provided for @test_notification_body.
  ///
  /// In en, this message translates to:
  /// **'This is a test notification'**
  String get test_notification_body;

  /// No description provided for @new_order_title.
  ///
  /// In en, this message translates to:
  /// **'New order!'**
  String get new_order_title;

  /// No description provided for @new_order_body.
  ///
  /// In en, this message translates to:
  /// **'Order of {amount} {currency} from {restaurant}'**
  String new_order_body(Object amount, Object currency, Object restaurant);

  /// No description provided for @modify_dish.
  ///
  /// In en, this message translates to:
  /// **'Modify dish'**
  String get modify_dish;

  /// No description provided for @add_dish_title.
  ///
  /// In en, this message translates to:
  /// **'Add dish'**
  String get add_dish_title;

  /// No description provided for @no_options_available.
  ///
  /// In en, this message translates to:
  /// **'No options'**
  String get no_options_available;

  /// No description provided for @add_option_button.
  ///
  /// In en, this message translates to:
  /// **'Add an option'**
  String get add_option_button;

  /// No description provided for @add_option_count.
  ///
  /// In en, this message translates to:
  /// **'Add an option ({count}/3)'**
  String add_option_count(Object count);

  /// No description provided for @main_photo_badge.
  ///
  /// In en, this message translates to:
  /// **'Main'**
  String get main_photo_badge;

  /// No description provided for @option_name.
  ///
  /// In en, this message translates to:
  /// **'Option name'**
  String get option_name;

  /// No description provided for @option_price_hint.
  ///
  /// In en, this message translates to:
  /// **'Option price (required, e.g. 2.50)'**
  String get option_price_hint;

  /// No description provided for @admin_role_label.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin_role_label;

  /// No description provided for @super_admin_role_label.
  ///
  /// In en, this message translates to:
  /// **'Super Admin'**
  String get super_admin_role_label;

  /// No description provided for @resto_role_label.
  ///
  /// In en, this message translates to:
  /// **'Resto'**
  String get resto_role_label;

  /// No description provided for @livreur_role_label.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get livreur_role_label;

  /// No description provided for @individual_role_label.
  ///
  /// In en, this message translates to:
  /// **'Individual'**
  String get individual_role_label;

  /// No description provided for @restaurateur_role_label.
  ///
  /// In en, this message translates to:
  /// **'Restaurateur'**
  String get restaurateur_role_label;

  /// No description provided for @change_password_title_dialog.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get change_password_title_dialog;

  /// No description provided for @current_password_label.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get current_password_label;

  /// No description provided for @new_password_label.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get new_password_label;

  /// No description provided for @confirm_password_label.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirm_password_label;

  /// No description provided for @become_restaurateur_dialog_title.
  ///
  /// In en, this message translates to:
  /// **'Become a home chef'**
  String get become_restaurateur_dialog_title;

  /// No description provided for @become_restaurateur_dialog_body.
  ///
  /// In en, this message translates to:
  /// **'By becoming a home chef, you will be able to publish your dishes and sell them directly to customers. Would you like to continue?'**
  String get become_restaurateur_dialog_body;

  /// No description provided for @yes_sell_my_dishes.
  ///
  /// In en, this message translates to:
  /// **'Yes, I want to sell my dishes'**
  String get yes_sell_my_dishes;

  /// No description provided for @delete_account_dialog_title.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get delete_account_dialog_title;

  /// No description provided for @delete_account_dialog_warning.
  ///
  /// In en, this message translates to:
  /// **'This action is irreversible. Your personal data will be deleted after 30 days.'**
  String get delete_account_dialog_warning;

  /// No description provided for @notifications_switch_orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get notifications_switch_orders;

  /// No description provided for @notifications_switch_promos.
  ///
  /// In en, this message translates to:
  /// **'Promotions'**
  String get notifications_switch_promos;

  /// No description provided for @notifications_switch_messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get notifications_switch_messages;

  /// No description provided for @add_your_address.
  ///
  /// In en, this message translates to:
  /// **'Add your address'**
  String get add_your_address;

  /// No description provided for @my_orders_button.
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get my_orders_button;

  /// No description provided for @search_no_results_for.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String search_no_results_for(Object query);

  /// No description provided for @restaurants_section.
  ///
  /// In en, this message translates to:
  /// **'Restaurants'**
  String get restaurants_section;

  /// No description provided for @dishes_section.
  ///
  /// In en, this message translates to:
  /// **'Dishes'**
  String get dishes_section;

  /// No description provided for @search_hint_input.
  ///
  /// In en, this message translates to:
  /// **'Search for dishes, restaurants...'**
  String get search_hint_input;

  /// No description provided for @password_reset_code_hint.
  ///
  /// In en, this message translates to:
  /// **'Please enter a 6-digit code'**
  String get password_reset_code_hint;

  /// No description provided for @verification_code_title.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get verification_code_title;

  /// No description provided for @code_sent_to_email.
  ///
  /// In en, this message translates to:
  /// **'A code was sent to {email}'**
  String code_sent_to_email(Object email);

  /// No description provided for @verification_enter_new_password.
  ///
  /// In en, this message translates to:
  /// **'Enter your new password'**
  String get verification_enter_new_password;

  /// No description provided for @return_button.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get return_button;

  /// No description provided for @first_login_title.
  ///
  /// In en, this message translates to:
  /// **'Password change'**
  String get first_login_title;

  /// No description provided for @first_login_subtitle.
  ///
  /// In en, this message translates to:
  /// **'For security reasons, please choose a new password.'**
  String get first_login_subtitle;

  /// No description provided for @change_password_button.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get change_password_button;

  /// No description provided for @password_reset_success_title.
  ///
  /// In en, this message translates to:
  /// **'Password reset!'**
  String get password_reset_success_title;

  /// No description provided for @password_reset_success_body.
  ///
  /// In en, this message translates to:
  /// **'Your password has been changed successfully. You can now log in.'**
  String get password_reset_success_body;

  /// No description provided for @enable_notifications_title.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications'**
  String get enable_notifications_title;

  /// No description provided for @enable_notifications_body.
  ///
  /// In en, this message translates to:
  /// **'Receive updates on your orders, promotions, and messages from our team.\n\nYou can change this setting in the settings.'**
  String get enable_notifications_body;

  /// No description provided for @enable_button.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable_button;

  /// No description provided for @onboarding_splash_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Neighbourhood\ncooking.'**
  String get onboarding_splash_subtitle;

  /// No description provided for @admin_welcome_title.
  ///
  /// In en, this message translates to:
  /// **'Welcome Admin!'**
  String get admin_welcome_title;

  /// No description provided for @admin_welcome_body.
  ///
  /// In en, this message translates to:
  /// **'Your administrator account has been created successfully.\nYou can now manage the platform.'**
  String get admin_welcome_body;

  /// No description provided for @identity_section_label.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get identity_section_label;

  /// No description provided for @contact_section_label.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact_section_label;

  /// No description provided for @security_section_label.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security_section_label;

  /// No description provided for @accept_terms_warning.
  ///
  /// In en, this message translates to:
  /// **'Please accept the terms.'**
  String get accept_terms_warning;

  /// No description provided for @too_long_max_80.
  ///
  /// In en, this message translates to:
  /// **'Too long (max 80 characters)'**
  String get too_long_max_80;

  /// No description provided for @position_not_available.
  ///
  /// In en, this message translates to:
  /// **'Position not available'**
  String get position_not_available;

  /// No description provided for @save_profile.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save_profile;

  /// No description provided for @cgv_title.
  ///
  /// In en, this message translates to:
  /// **'Terms and Conditions of Sale'**
  String get cgv_title;

  /// No description provided for @cgv_last_update.
  ///
  /// In en, this message translates to:
  /// **'Last updated: June 2026'**
  String get cgv_last_update;

  /// No description provided for @legal_notice_title.
  ///
  /// In en, this message translates to:
  /// **'Legal Notice'**
  String get legal_notice_title;

  /// No description provided for @privacy_policy_title.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacy_policy_title;

  /// No description provided for @promo_edit_title_key.
  ///
  /// In en, this message translates to:
  /// **'Edit {code}'**
  String promo_edit_title_key(Object code);

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @version_admin.
  ///
  /// In en, this message translates to:
  /// **'v1.0.0 · Administration'**
  String get version_admin;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @please_modify_a_file.
  ///
  /// In en, this message translates to:
  /// **'Please modify one of the files.'**
  String get please_modify_a_file;

  /// No description provided for @delivery_config_title.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee configuration'**
  String get delivery_config_title;

  /// No description provided for @delivery_config_current.
  ///
  /// In en, this message translates to:
  /// **'Current values'**
  String get delivery_config_current;

  /// No description provided for @delivery_config_base_fee.
  ///
  /// In en, this message translates to:
  /// **'Base fee (CDF)'**
  String get delivery_config_base_fee;

  /// No description provided for @delivery_config_per_km.
  ///
  /// In en, this message translates to:
  /// **'Rate per km (CDF)'**
  String get delivery_config_per_km;

  /// No description provided for @delivery_config_currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get delivery_config_currency;

  /// No description provided for @delivery_config_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get delivery_config_save;

  /// No description provided for @delivery_config_saved.
  ///
  /// In en, this message translates to:
  /// **'Configuration updated successfully'**
  String get delivery_config_saved;

  /// No description provided for @delivery_config_error.
  ///
  /// In en, this message translates to:
  /// **'Error updating configuration'**
  String get delivery_config_error;

  /// No description provided for @delivery_config_loading.
  ///
  /// In en, this message translates to:
  /// **'Loading configuration...'**
  String get delivery_config_loading;

  /// No description provided for @delivery_config_admin_nav.
  ///
  /// In en, this message translates to:
  /// **'Delivery fees'**
  String get delivery_config_admin_nav;

  /// No description provided for @delivery_config_distance.
  ///
  /// In en, this message translates to:
  /// **'Estimated distance'**
  String get delivery_config_distance;

  /// No description provided for @delivery_config_total_fee.
  ///
  /// In en, this message translates to:
  /// **'Estimated fee'**
  String get delivery_config_total_fee;

  /// No description provided for @delivery_config_commission_rate.
  ///
  /// In en, this message translates to:
  /// **'Platform commission (%)'**
  String get delivery_config_commission_rate;

  /// No description provided for @delivery_config_commission_label.
  ///
  /// In en, this message translates to:
  /// **'Platform commission'**
  String get delivery_config_commission_label;

  /// No description provided for @delivery_config_commission_formula.
  ///
  /// In en, this message translates to:
  /// **'Subtotal × @pct%'**
  String get delivery_config_commission_formula;

  /// No description provided for @delivery_config_deliverer_section.
  ///
  /// In en, this message translates to:
  /// **'Deliverer pay'**
  String get delivery_config_deliverer_section;

  /// No description provided for @delivery_config_deliverer_base.
  ///
  /// In en, this message translates to:
  /// **'Base per delivery (CDF)'**
  String get delivery_config_deliverer_base;

  /// No description provided for @delivery_config_deliverer_per_km.
  ///
  /// In en, this message translates to:
  /// **'Rate per km (CDF)'**
  String get delivery_config_deliverer_per_km;

  /// No description provided for @cart_address_out_of_zone.
  ///
  /// In en, this message translates to:
  /// **'Area not covered yet'**
  String get cart_address_out_of_zone;

  /// No description provided for @cart_address_out_of_zone_detail.
  ///
  /// In en, this message translates to:
  /// **'This address is outside our delivery zone. We currently deliver only in active delivery zones.'**
  String get cart_address_out_of_zone_detail;

  /// No description provided for @cart_address_zone_checking.
  ///
  /// In en, this message translates to:
  /// **'Checking delivery zone...'**
  String get cart_address_zone_checking;

  /// No description provided for @restaurant_form_payment_method.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get restaurant_form_payment_method;

  /// No description provided for @restaurant_form_payment_mobile_money.
  ///
  /// In en, this message translates to:
  /// **'Mobile Money'**
  String get restaurant_form_payment_mobile_money;

  /// No description provided for @restaurant_form_payment_bank.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get restaurant_form_payment_bank;

  /// No description provided for @restaurant_form_payment_phone.
  ///
  /// In en, this message translates to:
  /// **'Mobile Money phone'**
  String get restaurant_form_payment_phone;

  /// No description provided for @restaurant_form_payment_phone_required.
  ///
  /// In en, this message translates to:
  /// **'Phone number required for payouts'**
  String get restaurant_form_payment_phone_required;

  /// No description provided for @restaurant_form_payment_iban.
  ///
  /// In en, this message translates to:
  /// **'IBAN'**
  String get restaurant_form_payment_iban;

  /// No description provided for @restaurant_form_payment_iban_required.
  ///
  /// In en, this message translates to:
  /// **'IBAN required for bank transfer'**
  String get restaurant_form_payment_iban_required;

  /// No description provided for @restaurant_form_payment_bank_name.
  ///
  /// In en, this message translates to:
  /// **'Bank name'**
  String get restaurant_form_payment_bank_name;

  /// No description provided for @restaurant_form_payment_bank_name_required.
  ///
  /// In en, this message translates to:
  /// **'Bank name required'**
  String get restaurant_form_payment_bank_name_required;

  /// No description provided for @restaurant_form_payment_account_holder.
  ///
  /// In en, this message translates to:
  /// **'Account holder'**
  String get restaurant_form_payment_account_holder;

  /// No description provided for @restaurant_form_payment_account_holder_required.
  ///
  /// In en, this message translates to:
  /// **'Account holder name required'**
  String get restaurant_form_payment_account_holder_required;

  /// No description provided for @age_confirm_label.
  ///
  /// In en, this message translates to:
  /// **'I confirm I am 18 or older'**
  String get age_confirm_label;

  /// No description provided for @age_confirm_warning.
  ///
  /// In en, this message translates to:
  /// **'You must confirm you are 18 or older to sign up'**
  String get age_confirm_warning;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
