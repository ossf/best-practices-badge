# frozen_string_literal: true

# Copyright 2015-2017, the Linux Foundation, IDA, and the
# OpenSSF Best Practices badge contributors
# SPDX-License-Identifier: MIT

# Model class for additional rights data management.
#
# This model represents the many-to-many relationship between users and
# projects for granting additional editing permissions beyond project
# ownership. It serves as a join table that allows multiple users to have
# edit rights on a single project, and allows users to have edit rights
# on multiple projects they don't own.
#
# Currently mere *presence* is what matters; it gives the user edit rights
# to that project. In the future this *could* have 1+ additional fields
# identifying the specific additional rights of a user over a project.
#
# Database schema:
# - project_id: Foreign key to projects table
# - user_id: Foreign key to users table
# - created_at: When the right was granted
# - updated_at: When the record was last modified
#
# Indexes:
# - Unique index on [user_id, project_id] prevents duplicate rights
# - Individual indexes on project_id and user_id for query performance
class AdditionalRight < ApplicationRecord
  # Associates this additional right with a specific project.
  # When the project is destroyed, all associated additional rights are
  # deleted.
  # @return [Project] the project this right applies to
  belongs_to :project

  # Associates this additional right with a specific user.
  # When the user is destroyed, all their additional rights are deleted.
  # @return [User] the user who has this additional right
  belongs_to :user

  # Validates that both project and user exist and are valid.
  validates :project, presence: true
  validates :user, presence: true

  # Finds all additional rights for a specific project.
  # This scope can be used instead of AdditionalRight.where(project_id: id)
  # for better readability and consistency.
  # @param project_id [Integer] the ID of the project
  # @return [ActiveRecord::Relation<AdditionalRight>] rights for project
  scope :for_project, ->(project_id) { where(project_id: project_id) }
end
