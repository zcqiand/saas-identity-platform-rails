# frozen_string_literal: true

require 'json'
require 'fileutils'

module Harness
  # 单次运行 trace 适配器 —— java-spring HarnessTraceListener 的 Ruby 镜像。
  #
  # 仅当 ENV["TRACE_MAP"]=="1" 时由 test/helper.rb 挂载：普通 rake test
  # 不写 .state/trace.json（不脏工作树）。suite 的 load_trace 校验存在性 +
  # mtime 新鲜度，所以 report 阶段必须无条件落盘 —— 测试全红 / 空跑也要写。
  #
  # Rails 仓注意：并行测试多进程会竞写 trace.json，TRACE_MAP=1 时必须
  # parallelize(workers: 1)（见 profiles/rails.toml 注释）。
  #
  # 产物契约（scripts/lib/harness.py）：{"schema":1,"tests":[{"test","fns","inert"}]}
  # inert=true 的行 fns 必须为空 —— 假绿在适配器源头被抹掉。
  class TraceReporter < Minitest::AbstractReporter
    def initialize
      super
      @results = []
    end

    def record(result)
      @results << result
    end

    def report
      tests = @results.map { |r| build_entry(r) }
      out = File.join(Dir.pwd, '.state', 'trace.json')
      FileUtils.mkdir_p(File.dirname(out))
      File.write(out, "#{JSON.pretty_generate({ 'schema' => 1, 'tests' => tests })}\n")
    end

    private

    # 单条 trace 记录。skipped? 可能返回 nil（minitest 5.25 实证）——契约要求布尔。
    def build_entry(result)
      inert = result.skipped? || false
      reg = FN_REGISTRY[result.name]
      fns = inert || reg.nil? ? [] : reg[:fns].sort.uniq
      file = source_file(result) || reg&.dig(:file) || result.name
      { 'test' => "#{relativize(file)}::#{result.name}", 'fns' => fns, 'inert' => inert }
    end

    # rake/rails 以绝对路径加载测试文件；trace 条目按 suite 惯例用仓内相对路径
    def relativize(path)
      pwd = Dir.pwd
      path.start_with?(pwd) ? path.delete_prefix("#{pwd}/").delete_prefix("#{pwd}\\") : path
    end

    def source_file(result)
      return result.source_location.first if result.respond_to?(:source_location) && result.source_location

      result.method(result.name).source_location.first
    rescue StandardError
      nil
    end
  end
end
