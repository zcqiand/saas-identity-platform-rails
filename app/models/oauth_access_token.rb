# frozen_string_literal: true

# OAuth access token 持久行（public.oauth_access_token）。
class OauthAccessToken < ApplicationRecord
  self.table_name = 'oauth_access_token'

  has_many :oauth_refresh_tokens, foreign_key: :access_token_id, primary_key: :id
end
