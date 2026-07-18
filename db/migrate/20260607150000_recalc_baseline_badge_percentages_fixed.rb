# frozen_string_literal: true

# Copyright the Linux Foundation and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# INTENTIONAL NO-OP, kept only so its version records and it stops
# re-running. Originally this migration recalculated every project's baseline
# badge percentages after the OSPS baseline standard was bumped from
# v2025.10.10 to v2026.02.19 (#2726), which added new baseline criteria.
#
# WHY IT WAS NEUTERED (a lesson worth keeping):
#
# It called Project.update_all_badge_percentages inside the single transaction
# that Rails wraps around a migration by default. That method walks every
# project (find_each) and saves each under with_lock. Within one transaction,
# ActiveRecord retains every touched record in the transaction's
# commit/rollback bookkeeping until it commits. A projects row is very wide
# (~400 columns, about half of them text), so memory grew linearly with the
# number of projects processed, exceeded the dyno limit, and triggered an
# R14/R15 SIGKILL (exit 137). Because the whole recalc was one transaction,
# that silent kill rolled it all back: the migration never recorded, stayed
# "pending", and re-ran (and re-died) on every deploy for weeks. Bounding
# find_each's batch size (#2864) was necessary but NOT sufficient; it caps
# the loop's working set, not the single transaction's ever-growing list of
# retained records.
#
# WHAT SHOULD HAVE HAPPENED (guidance for future migrations):
# A whole-table data migration that saves every row must not run inside one
# transaction. Either declare `disable_ddl_transaction!` so each row's own
# short transaction commits and releases (bounded memory); or, better for a
# large, slow, or policy-sensitive backfill, do the work OUTSIDE a migration
# entirely, in a rake task that is run deliberately.
#
# WHY A PLAIN NO-OP (rather than just adding disable_ddl_transaction! here):
# Completing this recalc immediately REVOKES baseline badges that projects
# earned validly under the previous baseline version. The goalpost moved;
# the projects did not regress, so their owners deserve advance warning and
# a grace period. The recalc is therefore deferred to an operational step,
# run only after owners have been warned: the rake task
# `recalc_baseline_and_notify_losses`, which runs the same recalc
# non-transactionally, when we choose to.
class RecalcBaselineBadgePercentagesFixed < ActiveRecord::Migration[8.1]
  def change
    # Intentionally empty; see the explanation above.
  end
end
