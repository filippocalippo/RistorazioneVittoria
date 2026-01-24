# Authentication Feature

## Login Bottom Sheet

The login screen has been transformed into a bottom sheet for better UX and versatility.

### Usage

#### Direct Usage
```dart
import 'package:your_app/features/auth/auth_utils.dart';

// Show the login bottom sheet
await AuthUtils.showLoginBottomSheet(context);
```

#### With Result Handling
```dart
// Attempt login and get result
bool success = await AuthUtils.attemptLogin(context);
if (success) {
  // Handle successful login
}
```

### Features

- **Bottom Sheet UI**: Modern draggable bottom sheet with smooth animations
- **Responsive Design**: Adapts to different screen sizes
- **Google Sign-In**: Integrated Google authentication
- **Loading States**: Visual feedback during authentication
- **Error Handling**: User-friendly error messages
- **Auto-close**: Automatically closes after successful login

### Implementation Details

- `LoginScreen`: Wrapper screen for backward compatibility with router
- `LoginBottomSheet`: The actual bottom sheet widget
- `AuthUtils`: Utility class for easy access to login functionality

### Integration Points

The login bottom sheet is integrated in:
- Mobile top bar login button
- Desktop navigation bar login button  
- Cart screen authentication prompt
- Router redirect logic (maintains existing flow)

### Styling

- Rounded top corners (20px radius)
- Drag handle for better UX
- Responsive height (40% - 90% of screen)
- Proper padding and spacing
- Theme-aware colors and typography
