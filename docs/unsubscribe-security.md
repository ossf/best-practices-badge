# Unsubscribe Feature Security Documentation

## Overview

The unsubscribe feature provides a secure way for users to opt out of email notifications. This implementation follows security best practices to prevent abuse and protect user privacy. The system now includes time-based validation with issued dates and uses a dedicated secret key for enhanced security.

## Security Features

### 1. Authentication & Authorization

- **HMAC-based tokens**: Uses HMAC-SHA256 with dedicated `BADGEAPP_UNSUBSCRIBE_KEYS` environment variable
- **Time-based validation**: Tokens include issued date and expire after configurable period (default 30 days)
- **Constant-time comparison**: Prevents timing attacks when validating tokens
- **Token binding**: Tokens are bound to user ID, email, and issued date
- **No user enumeration**: Doesn't reveal whether an email exists in the system
- **Easy key rotation**: The `BADGEAPP_UNSUBSCRIBE_KEYS` environment variable supports multiple (comma-separated) keys.
- **CSRF protection**: Requires valid CSRF tokens for form submissions

### 2. Input Validation

- **Email format validation**: Simplistic validation for email addresses. More isn't necessary, since only valid email addresses will have an effect. It does limit length to prevent DoS.
- **Token format validation**: Ensures tokens contain only safe characters
- **Date format validation**: Strict YYYY-MM-DD format validation with range checks
- **Length limits**: Prevents DoS attacks with oversized inputs
- **Parameter sanitization**: Strips HTML and dangerous characters

### 3. Time-Based Security

- **Issued date validation**: Links must include valid issued date in YYYY-MM-DD format
- **Expiration handling**: Tokens expire after configurable period (BADGEAPP_UNSUBSCRIBE_DAYS)
- **Future date prevention**: Rejects tokens with future issued dates

### 4. Privacy Protection

- **No PII in logs**: Logs only user IDs and domains, not email addresses

### 5. Error Handling

- **Secure error messages**: Doesn't leak sensitive information
- **Comprehensive logging**: Security events logged for monitoring
- **Safe defaults**: Fails securely when validation fails

## Environment Variables

### Configuration

- `BADGEAPP_UNSUBSCRIBE_KEYS`: 1+ Secret key for HMAC token generation (should be unique and cryptographically random), comma-separated. Uses `Rails.application.secret_key_base` if that is not available.
- `BADGEAPP_UNSUBSCRIBE_DAYS`: Number of days tokens remain valid (default: 30)

### Example Configuration

```bash
# Generate a random 64-character hex key
BADGEAPP_UNSUBSCRIBE_KEYS=$(rails secret | head -c64)
BADGEAPP_UNSUBSCRIBE_DAYS=30
```

## Implementation Components

### Routes

```ruby
# Within scope '(:locale)', locale: LEGAL_LOCALE block
get 'unsubscribe' => 'unsubscribe#edit'
post 'unsubscribe' => 'unsubscribe#create'
```

**Locale Support**:

- **With locale**: `/en/unsubscribe` - works directly in English locale
- **Without locale**: `/unsubscribe` - redirects to user's preferred locale (e.g., `/en/unsubscribe`)
- **Email links**: Commonly include locale for immediate localized experience
- **Browser detection**: When no locale provided, uses browser language preferences

### Controller: `UnsubscribeController`

- Handles both GET (form display) and POST (processing) requests
- Validates issued date parameter for time-based security
- Implements comprehensive input validation and security checks
- Uses database transactions for data consistency

### View: `app/views/unsubscribe/edit.html.erb`

- Displays read-only fields email, issued date, and first characters of token
- CSRF-protected form with client-side validation

### Helper: `UnsubscribeHelper`

- Time-based token generation and verification utilities
- URL generation with issued date for email templates
- Privacy-preserving logging functions
- Date validation and parsing utilities

### Database Migration

- Backwards-compatible with existing data
- Adds `notification_emails` boolean field to users table, which will be
  used from here on.
- Stops using and stops displaying `project.disabled_reminders`.
  It does not *remove* the data, in case we need that data in the future.
- Safe default values. If a user has *any* project with disabled_reminders,
  then the user's `notification_emails` will be false (else true).

### Email Integration: `ReportMailer`

- Modified to check user notification preferences. That way, even if it
  accidentally is called to send a notification, it won't do so.
- Includes new easier-to-use unsubscribe links in reminder emails
- Uses helper methods for secure token generation

## Testing

Comprehensive test suite includes:

- Valid and invalid token testing with issued dates
- Time-based validation (expired/future dates)
- Input validation testing
- Rate limiting verification
- SQL injection prevention
- XSS protection validation
- CSRF protection testing
- Secure header verification
- Notification preference checking

## Security Considerations

1. **Secret Key Management**: Store `BADGEAPP_UNSUBSCRIBE_KEYS` securely and rotate it periodically. You can store more than one as a comma-separated list; the first one is used to generate new tokens. To rotate, add a new one at the end, and eventually remove old keys.
2. **Time Window Configuration**: Balance security vs usability when setting expiration period
3. **Clock Synchronization**: Ensure server clocks are synchronized to prevent time-based issues
4. **Monitoring**: Log analysis should monitor for:
   - Unusual numbers of failed unsubscribe attempts
   - Rate limit violations
   - Invalid token patterns
   - Expired token usage attempts

5. **GDPR Compliance**: The unsubscribe feature supports data subject rights by allowing users to control their email preferences. Users can easily unsubscribe directly by clicking on an email without logging in. Users can easily control their subscription setting by logging in, where they can enable or disable it as part of their profile.

6. **Backup Security**: Even if some tokens are compromised, attackers can only unsubscribe those users, and only until the time runs out. No privilege escalation possible. If a server unsubscribe secret key is exposed, attackers could unsubscribe arbitrary users, but they can't do anything else, and the key is easily rotated.

## Maintenance

- Rotate unsubscribe secret key periodically

Here's one way to add a key while retaining old keys:

~~~~sh
    heroku run --app staging-bestpractices bash

    BADGEAPP_UNSUBSCRIBE_KEYS="$(rails secret | head -c64),$BADGEAPP_UNSUBSCRIBE_KEYS"
~~~~

Here's one way to remove all old keys (do later):

~~~~sh
    heroku run --app staging-bestpractices bash

    BADGEAPP_UNSUBSCRIBE_KEYS="${BADGEAPP_UNSUBSCRIBE_KEYS%%,*}"
~~~~

After either one logout and restart:

~~~~sh
    heroku restart --app staging-bestpractices
~~~~
