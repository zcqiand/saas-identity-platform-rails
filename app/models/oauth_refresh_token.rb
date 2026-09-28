# frozen_string_literal: true

# OAuth refresh token（public.oauth_refresh_token）。
class OauthRefreshToken < ApplicationRecord
  self.table_name = 'oauth_refresh_token'
end
