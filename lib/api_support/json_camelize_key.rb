# frozen_string_literal: true

# snake_case -> camelCase(:lower)，Hash/Array 深变换（ApplicationController 渲染层专用）。
# 家族契约：@Nullable 字段序列化后 null 被 normalize 剔除 —— 此处 nil 值键直接丢弃，
# 镜像 springboot 响应 normalize（可选字段缺失即不出现在 JSON 里，不是 "field": null）。
# Zeitwerk 不扫 lib/，由 application.rb require_relative 加载。
module ApiSupport
  module JsonCamelizeKey
    module_function

    def call(obj)
      case obj
      when Hash
        obj.each_with_object({}) do |(k, v), out|
          next if v.nil?

          out[k.to_s.camelize(:lower)] = call(v)
        end
      when Array
        obj.map { |v| call(v) }
      else
        obj
      end
    end
  end
end
