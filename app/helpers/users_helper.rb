# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

module UsersHelper
  # Returns avatar image tag for the given user.
  # We use 'referrerpolicy' to try to give our users additional privacy,
  # by not revealing exactly what page the user is merely viewing
  # when retrieving this avatar.
  # Officially 'referrerpolicy' is experimental, see:
  # https://developer.mozilla.org/en-US/docs/Web/HTML/Element/img
  # However, as of 2019-08-28 'referrerpolicy' in an HTMLImageElement
  # is supported by Chrome 51, Firefox 50, Opera 38, Safari 11.1,
  # Android webview 51, Chrome for Android 51, Firefox for Android 50,
  # and Opera for Android 41; thus, this is widely supported. See:
  # https://developer.mozilla.org/en-US/docs/Web/API/HTMLImageElement/
  # referrerPolicy
  # We don't necessarily mind reporting where a user came from when they
  # *choose* to navigate to a link, but we want to try to provide
  # additional privacy when the user is viewing information they may not
  # realize is being transcluded (because they did not actively select it).
  # @param user [User] the user whose avatar to render
  # @return [ActiveSupport::SafeBuffer] img tag HTML
  def avatar_for(user)
    image_tag(
      user.avatar_url, alt: user.name, class: 'avatar', size: '80x80',
                       referrerpolicy: 'no-referrer'
    )
  end
end
