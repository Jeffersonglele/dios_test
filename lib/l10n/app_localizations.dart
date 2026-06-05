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

  // ── Clés supplémentaires ──
  String get already_have_account;
  String get signup_title;
  String get signup_subtitle;
  String get login_title;
  String get login_subtitle;
  String get login_failed;
  String get dont_have_account;
  String get firstname;
  String get enter_firstname;
  String get lastname;
  String get enter_lastname;
  String get enter_username;
  String get enter_valid_email;
  String get phone_number;
  String get enter_phone;
  String get benin_phone_format;
  String get new_password;
  String get confirm_password;
  String get confirm_password_required;
  String get passwords_do_not_match;
  String get enter_password;
  String get min_4_chars;
  String get min_6_chars;
  String get max_18_chars;
  String get username_or_email;
  String get user_not_found;
  String get forgotten_password;
  String get forgotten_password_title;
  String get forgotten_password_subtitle;
  String get reset_password;
  String get reset_password_title;
  String get reset_password_subtitle;
  String get no_account_for_email;
  String get reset_code_send_failed;
  String get reset_code_sent;
  String get invalid_or_expired_code;
  String get verify_code;
  String get verify_email;
  String get internet_required;
  String get next;
  String get start;
  String get skip;

  /// Lookup dynamique par clé (pour onboarding entre autres)
  String localized(String key) {
    switch (key) {
      case 'splash_subtitle': return splash_subtitle;
      case 'splash_loading': return splash_loading;
      case 'onboarding_step_1_title': return onboarding_step_1_title;
      case 'onboarding_step_1_body': return onboarding_step_1_body;
      case 'onboarding_step_2_title': return onboarding_step_2_title;
      case 'onboarding_step_2_body': return onboarding_step_2_body;
      case 'onboarding_step_3_title': return onboarding_step_3_title;
      case 'onboarding_step_3_body': return onboarding_step_3_body;
      case 'start': return start;
      case 'skip': return skip;
      case 'next': return next;
      case 'login': return login;
      case 'login_title': return login_title;
      case 'login_subtitle': return login_subtitle;
      case 'login_failed': return login_failed;
      case 'signup': return signup;
      case 'signup_title': return signup_title;
      case 'signup_subtitle': return signup_subtitle;
      case 'dont_have_account': return dont_have_account;
      case 'firstname': return firstname;
      case 'enter_firstname': return enter_firstname;
      case 'lastname': return lastname;
      case 'enter_lastname': return enter_lastname;
      case 'username': return username;
      case 'enter_username': return enter_username;
      case 'email': return email;
      case 'enter_valid_email': return enter_valid_email;
      case 'phone_number': return phone_number;
      case 'enter_phone': return enter_phone;
      case 'benin_phone_format': return benin_phone_format;
      case 'password': return password;
      case 'new_password': return new_password;
      case 'confirm_password': return confirm_password;
      case 'confirm_password_required': return confirm_password_required;
      case 'passwords_do_not_match': return passwords_do_not_match;
      case 'enter_password': return enter_password;
      case 'min_4_chars': return min_4_chars;
      case 'min_6_chars': return min_6_chars;
      case 'max_18_chars': return max_18_chars;
      case 'username_or_email': return username_or_email;
      case 'user_not_found': return user_not_found;
      case 'forgotten_password': return forgotten_password;
      case 'forgotten_password_title': return forgotten_password_title;
      case 'forgotten_password_subtitle': return forgotten_password_subtitle;
      case 'reset_password': return reset_password;
      case 'reset_password_title': return reset_password_title;
      case 'reset_password_subtitle': return reset_password_subtitle;
      case 'already_have_account': return already_have_account;
      case 'no_account_for_email': return no_account_for_email;
      case 'reset_code_send_failed': return reset_code_send_failed;
      case 'reset_code_sent': return reset_code_sent;
      case 'invalid_or_expired_code': return invalid_or_expired_code;
      case 'verify_code': return verify_code;
      case 'verify_email': return verify_email;
      case 'internet_required': return internet_required;
      default: return key;
    }
  }
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
