# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Shows a stashed form submission after a forced re-login, so the submitter
# can resume it with one click instead of retyping it. See
# docs/login-session-implementation.md section 15.
#
# There is deliberately no :id/:token param this action itself reads: the
# only identifier #show consults is session[:pending_resubmission_token],
# written solely by SessionsController#successful_login, once, on a login
# that carried its own pending_resubmission_token request param (docs/
# login-session-18.md "Step 21"; ApplicationController#stash_pending_resubmission
# only creates the row and returns the token, it doesn't touch session at
# all). Reading the identifier to display from params instead would let
# anyone who guesses or enumerates it view another browser's stashed
# submission; do not add that. (Since step 18, the token itself is also no
# longer guessable even if it did leak into params somehow: it's 128 bits
# of SecureRandom, matched server-side only by its HMAC digest. But the
# session-only rule for *displaying* a stash stands regardless, unchanged
# from the original design.)
#
# #show deliberately does NOT destroy the row or clear the session key
# (docs/login-session-evaluation.md finding #4): the old single-use-on-view behavior meant a
# closed tab, dropped connection, or back-then-forward before clicking
# "Resume" lost the stashed edit for good, with no way back. Revisiting
# this page now just re-shows the same stash. A row is only ever consumed
# by ApplicationController#finalize_pending_resubmission, once the browser
# actually resubmits it and that resubmission's save succeeds (the hidden
# pending_resubmission_token field the view below adds carries the token
# forward for that); an abandoned one is
# swept up later by PendingResubmission.purge_stale (lib/tasks/default.rake's
# `daily` task), so nothing lingers forever.
class PendingResubmissionsController < ApplicationController
  # Supports `GET /pending_resubmissions`.
  # @return [void]
  def show
    pending_token = session[:pending_resubmission_token] # never params; read-only
    pending = PendingResubmission.find_by_token(pending_token)
    return redirect_expired unless pending

    flash.now[:warning] = t('.sensitive_fields_dropped') if pending.sensitive_fields_dropped?
    @pending_resubmission_token = pending_token
    @resubmit_path = pending.resubmit_path
    @resubmit_method = pending.resubmit_method
    @fields = JSON.parse(pending.params_json)
  end

  private

  # @return [void]
  def redirect_expired
    flash[:danger] = t('.expired')
    redirect_to root_url
  end
end
