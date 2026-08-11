#!/usr/bin/python3
# Modify www.bestpractices.dev project entries via API

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

"""
This program programmatically modifies BadgeApp projects.

An example of using this on the command line is
docs/best_practices_modify.py -S 1 '{"test_status": "Met"}'
which modifies project 1 on the staging site.
To modify the *production* site data, use -P instead of -S.
Updates use JSON format; remember to use double-quotes around all strings
in the JSON format. Typically the JSON will modify criteria data; for
a CRITERION, the status value is in field CRITERION_status
and the corresponding text justification is in CRITERION_justification.
A CRITERION_status can be Met, Unmnet, ?, or N/A.

Note: For modification to work, you need to authenticate to the BadgeApp
and provide that data to this program. Here's how.

First, use your web browser to log into
the BadgeApp and get the value of the session cookie `_BadgeApp_session`.
In Chrome, go to
More Tools => Developer Tools => Application => Cookies,
select the site, and select the _BadgeApp_session cookie.
In Firefox, go to Web Developer => Storage Inspector => Cookies.
No matter what, select JUST the value of cookie `_BadgeApp_session`
and copy it.

One you have the cookie value copied into your clipboard,
the recommended approach is to set the environment variable _BadgeApp_session
to it. E.g., in sh:
export _BadgeApp_session='VALUE_FROM_CLIPBOARD'

Alternatively, you can pass the session value on the command line, by
using the -C argument (-C *session_cookie_value*).

Note that a given login cookie is good for 48 hours, and then expires.

When used as a library, the two functions to use are
best_practices_modify.write_to_project()
and best_practices_modify.patch_project().
In addition, these string constants may be useful:
best_practices_modify.COOKIE_NAME,
best_practices_modify.PRODUCTION_BASE_URL,
best_practices_modify.STAGING_BASE_URL, and
best_practices_modify.LOCAL_BASE_URL.
"""

# Python2 is "officially" unsupported but actually in wide use,
# so we'll try to make it not hard to use Python2.
# We'll import print_function, and use "+" to concatenate strings.
# We haven't tested with Python2, so more changes are likely necessary.
from __future__ import print_function

import os, sys, re, json, urllib
import argparse
from urllib.request import urlopen

# Plausible base URLs.
LOCAL_BASE_URL = 'http://localhost:3000/'
STAGING_BASE_URL = 'https://staging.bestpractices.dev/'
PRODUCTION_BASE_URL = 'https://www.bestpractices.dev/'

COOKIE_NAME = '_BadgeApp_session'

def error(message):
    """Print error message to standard error."""
    print(message, file=sys.stderr)

def patch_project(base_url, id, updated_data,
                  auth_token, csrf_token, session_cookie):
    """
    Attempts to patch project id at base_url with dictionary updated_data.
    We require auth_token, csrf_token, and session_cookie to prove that
    we are authorized to cause this patch.
    This is a lower-level method; most users should invoke
    write_to_project() instead.
    """

    # Originally we tried to PATCH the JSON endpoint, but we never
    # got that working. So instead we PATCH the HTML endpoint:
    url = base_url + 'en/projects/' + str(id)

    # Convert updated_data hashes of form {'test_status': 'Unmet'}
    # into {'project[test_status]': 'Unmet'} because that's what the
    # HTML form submission format requires.
    updated_data_reformatted = {}
    for key, value in updated_data.items():
        updated_data_reformatted['project[' + key + ']'] = value
    # Add authentication_token
    updated_data_reformatted['authentication_token'] = auth_token

    # Encode data for urllib.request.html as described in
    # https://docs.python.org/3/library/urllib.request.html#request-objects
    updated_data_encoded = urllib.parse.urlencode(
            updated_data_reformatted).encode('utf-8')

    # Set up request.
    request = urllib.request.Request(url,
            data=updated_data_encoded, method='PATCH')
    # Provide authentication cookie to prove we're authorized to update.
    # Beware: add_header can only add *one* Cookie header
    request.add_header('Cookie', COOKIE_NAME + '=' + session_cookie)
    request.add_header('X-CSRF-Token', csrf_token)
    # Note: We don't send an origin; Rails considers that a valid origin.
    # Originally we tried to post JSON, but had trouble getting that working.
    # To do that you'd use the .json resource and add this header:
    # request.add_header('Content-Type', 'application/json')
    # request.add_header('Accepts', 'application/json') # Shouldn't matter

    # Attempt to send request.
    try:
        response = urlopen(request)
    except urllib.error.HTTPError as e:
        if e.code == 302 and e.headers['Location'] == url:
            # EXPECTED result - everything is fine!
            return 200
        error('Warning: Received HTTPError, code=' + str(e.code))
        error('This can happen on localhost if project badge status changes.')
        return 500

    error('Warning: No exception, even though we expected a redirect 302')
    error('There may be an invalid key or key value.')
    return 200

# To find the form's authenticity token we look for this pattern:
AUTH_TOKEN_HTML_PATTERN = re.compile(
    r'<input type="hidden" name="authenticity_token" value="([^"]+)"'
)

# To find the form's csrf token we look for this pattern:
CSRF_TOKEN_HTML_PATTERN = re.compile(
    r'<meta name="csrf-token" content="([^"]+)"'
)

def get_token(html, pattern):
    """Return string token in provided HTML that matches pattern."""
    result = pattern.search(html)
    if result:
        return result.group(1)
    else:
        error('Failed to find token')
        return None

def get_updated_cookie(headers, session_cookie):
    """Retrieve the updated session cookie"""
    # We should have received an HTTP header of this form:
    # Set-Cookie: _BadgeApp_session=VALUE; path=/; HttpOnly
    # We will try to return the VALUE part.
    set_cookie = headers['Set-Cookie']
    if set_cookie is None:
        error('Warning: No cookie updated')
        return session_cookie
    expected_prefix = COOKIE_NAME + '='
    if not set_cookie.startswith(expected_prefix):
        error('Warning: Wrong cookie set')
        return session_cookie
    leftover = set_cookie[len(expected_prefix):]
    new_session_cookie = leftover.split(';',1)[0]
    return new_session_cookie

def get_project_tokens(base_url, id, session_cookie):
    """Returns auth_token,csrf_token,session_cookie for project id."""
    # Try to get the "edit" page with our logged-in session cookie
    url = base_url + 'en/projects/' + str(id) + '/edit'
    request = urllib.request.Request(url)
    # Provide authentication cookie to prove we're authorized to get page.
    # Beware: add_header can only add *one* Cookie header
    request.add_header('Cookie', COOKIE_NAME + '=' + session_cookie)
    # Note: We don't send an origin; Rails considers that a valid origin.

    # Note: This will raise exception on open failure
    response = urlopen(request)

    redirected = (response.url != url)
    if redirected or response.code != 200:
        error('Error: Did not have permission to view edit page')
        return None, None, None

    html = str(response.read(), 'utf-8')
    auth_token = get_token(html, AUTH_TOKEN_HTML_PATTERN)
    csrf_token = get_token(html, CSRF_TOKEN_HTML_PATTERN)

    new_session_cookie = get_updated_cookie(response.headers, session_cookie)
    return auth_token, csrf_token, new_session_cookie

def write_to_project(base_url, id, updated_data, session_cookie):
    """Write to project #id the updated_data in json format -> true if ok.
    The base_url is the URL prefix; it will typically start with
    'http://' or 'https://' and must end in a slash, e.g.,
    'http://localhost:3000/'
    The id is the project id number (a positive integer).
    The update_data is a Python dictionary of updates to be made, e.g.,
    {"test_status": "Met"}, typically created by reading data in JSON format.
    The session_cookie is the _BadgeApp_session cookie value.
    """
    # First request the HTML edit form; it includes information we
    # must have to successfully patch a project.
    auth_token, csrf_token, updated_session_cookie = get_project_tokens(
            base_url, id, session_cookie)
    # Now request patching the project.
    # We have to send various other data, including an updated_session_cookie,
    # because we need them to be allowed to do an update.
    status = patch_project(base_url, id, updated_data,
            auth_token, csrf_token, updated_session_cookie)
    return status == 200

class CustomFormatter(argparse.ArgumentDefaultsHelpFormatter, argparse.RawDescriptionHelpFormatter):
    """
    Show the epilog in a way that preserves the linebreaks.
    Suggested at:
    https://bugs.python.org/issue13023
    """
    pass

def main():
    """Main entry for command line interface"""

    # Create argument parser, then parse command line arguments with it.
    parser = argparse.ArgumentParser(
            description='Modify project data on BadgeApp',
            formatter_class=CustomFormatter,
            epilog=__doc__
    )
    parser.add_argument('-C', '--cookie',
        help='Session cookie value, else uses env variable ' + COOKIE_NAME,
        dest='session_cookie', default=os.environ.get(COOKIE_NAME))
    # Make it easy to select base URL
    group_base = parser.add_mutually_exclusive_group()
    group_base.add_argument('-b', '--base', dest='base_url',
            default=None, help='Arbitrary base URL to modify')
    group_base.add_argument('-L', '--local', dest='base_url',
            action='store_const',
            const=LOCAL_BASE_URL, help='Store in local repo')
    group_base.add_argument('-S', '--staging', dest='base_url',
            action='store_const',
            const=STAGING_BASE_URL, help='Store in staging repo')
    group_base.add_argument('-P', '--production', dest='base_url',
            action='store_const',
            const=PRODUCTION_BASE_URL, help='Store in production (REAL) repo')
    parser.add_argument('project_id', help='Project id (number) to modify')
    parser.add_argument('updated_data', help='Updated data (JSON format)')

    # Process command line arguments.
    args = parser.parse_args()

    if (args.session_cookie is None or args.session_cookie == ''):
        error('Error: We MUST have a session cookie value to proceed.')
        error('Use --help for more information.')
        sys.exit(1)
    if not args.base_url:
        error('Error: We MUST have a base (-b/--base, -L, -S, or -P).')
        error('Use --help for more information.')
        sys.exit(1)

    # Convert JSON data into a Python dictionary.
    # This will fail & raise an exception if non-JSON provided.
    # Remember to use *double-quotes* around all strings in JSON;
    # the JSON data needs to look like this:
    # {"test_status": "Met"}
    # Note that status values can be "Met", "Unmet", or "?".
    updated_data_json = json.loads(args.updated_data)

    # Notify what we're doing.
    error("Writing data to project " + args.project_id +
          " at base URL " + args.base_url)

    # Now go do it!
    result = write_to_project(args.base_url,
            args.project_id, updated_data_json, args.session_cookie)
    sys.exit(not result)

if __name__ == '__main__':
    main()
