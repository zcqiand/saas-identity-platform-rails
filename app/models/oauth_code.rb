# frozen_string_literal: true

# OAuth 授权码（public.oauth_code）。一次性，过期作废。
class OauthCode < ApplicationRecord
  self.table_name = 'oauth_code'
end
