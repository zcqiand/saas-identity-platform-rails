# frozen_string_literal: true

# 家族契约底座：camelCase JSON 渲染 + 错误体 {code,message} 映射。
# 映射表镜像 springboot GlobalExceptionHandler（ADR-0020 错误契约）：
#   NSEE→404 NOT_FOUND / InvalidCredentials→401 INVALID_CREDENTIALS
#   IAE→400 BAD_REQUEST / AccessDenied→403 FORBIDDEN / FK 违反→400
class ApplicationController < ActionController::API
  class AccessDenied < StandardError; end
  class InvalidCredentials < StandardError; end

  rescue_from ActiveRecord::RecordNotFound do |e|
    # 镜像 springboot UUID.fromString：路径段声称是 uuid 但格式非法 -> 400（IAE 语义），
    # 合法格式但查无 -> 404
    if bad_uuid_param
      render_error(:bad_request, 'BAD_REQUEST', "malformed uuid: #{bad_uuid_param}")
    else
      render_error(:not_found, 'NOT_FOUND', e.message || 'resource not found')
    end
  end

  rescue_from InvalidCredentials do |e|
    render_error(:unauthorized, 'INVALID_CREDENTIALS', e.message || 'invalid credentials')
  end

  rescue_from ArgumentError do |e|
    render_error(:bad_request, 'BAD_REQUEST', e.message || 'invalid argument')
  end

  rescue_from AccessDenied do |e|
    render_error(:forbidden, 'FORBIDDEN', e.message || 'access denied')
  end

  # NotNullViolation 并入同组（镜像 springboot DataIntegrityViolationException → 400
  # "constraint violation"；I64 空 body 创 client 走这个口子，500 是分叉）
  rescue_from ActiveRecord::RecordInvalid, ActiveRecord::InvalidForeignKey,
              ActiveRecord::NotNullViolation do |e|
    render_error(:bad_request, 'BAD_REQUEST', "constraint violation: #{e.message}")
  end

  rescue_from ActionController::ParameterMissing do
    render_error(:bad_request, 'BAD_REQUEST', 'malformed request body')
  end

  # JSON.parse 失败 = 请求体不可解析（镜像 HttpMessageNotReadableException → 400）
  rescue_from ActionDispatch::Http::Parameters::ParseError do
    render_error(:bad_request, 'BAD_REQUEST', 'malformed request body')
  end

  protected

  # snake_case → camelCase(:lower) 深变换：家族 DTO 形状是 camelCase，DB 列是 snake_case
  def render_camel(data, status: :ok)
    render json: ApiSupport::JsonCamelizeKey.call(data), status: status
  end

  def render_error(status, code, message)
    render json: { code: code, message: message }, status: status
  end

  UUID_RE = /\A[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\z/

  def bad_uuid_param
    %i[id tenant_id user_id role_id menu_id].filter_map do |key|
      v = params[key]
      v if v.present? && v !~ UUID_RE
    end.first
  end

  def page_params
    page = params.fetch(:page, 0).to_i
    page_size = params.fetch(:pageSize, 20).to_i
    raise ArgumentError, 'page must be >= 0' if page.negative?
    raise ArgumentError, 'pageSize must be >= 1' if page_size < 1

    [page, page_size]
  end

  # oauth 链手动 decode（springboot SecurityConfig 独立 permitAll 链的镜像）：
  # 无/坏 Bearer 或无 tenant_id claim -> 401 INVALID_CREDENTIALS。放 ApplicationController
  # 是因为 oauth 控制器不挂 TenantGuard（public 链），但 decode 语义两侧共用。
  def decode_bearer!
    header = request.headers['Authorization'].to_s
    token = header.delete_prefix('Bearer ').strip
    raise ApplicationController::InvalidCredentials, 'missing bearer token' if token.empty? || header == token

    payload = Auth::JwtVerifier.new.verify!(token)
    raise ApplicationController::InvalidCredentials, 'missing tenant_id claim' if payload['tenant_id'].blank?

    payload
  rescue JWT::ExpiredSignature, JWT::DecodeError => e
    raise ApplicationController::InvalidCredentials, e.message
  end

  # 家族分页信封 { items, page, pageSize, total }，page=0/pageSize=20 缺省（contract-test 约定）
  def render_paginated(scope, &)
    page, page_size = page_params
    total = scope.count
    items = scope.limit(page_size).offset(page * page_size).map(&)
    render_camel({ items: items, page: page, page_size: page_size, total: total })
  end
end
