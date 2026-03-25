#!/usr/bin/env ruby
# frozen_string_literal: true

# Benchmark script for measuring individual C extension and compilation optimizations.
# Usage: bundle exec ruby benchmark/bench_internals.rb

$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'hamlit'
require 'benchmark/ips'

haml_code = <<~HAML
  %html
    %head
      %title Test
    %body
      %h1 Hello
      %p World
HAML

puts "=== Speed (iterations/second) ==="
puts

Benchmark.ips do |x|
  x.report("AttributeBuilder.build_data") do
    Hamlit::AttributeBuilder.build_data(true, '"', { "controller" => "app", "action_name" => "index" })
  end

  x.report("AttributeBuilder.build") do
    Hamlit::AttributeBuilder.build(true, '"', :html, ["disabled", "checked"], nil,
      { "class" => "btn", "id" => "submit", "data" => { "controller" => "app" } })
  end

  x.report("Compilation") do
    Hamlit::Engine.new.call(haml_code)
  end

  x.report("Render") do
    Hamlit::Engine.new.call(haml_code)
  end
end

puts
puts "=== Memory (object allocations per call) ==="
puts

def measure_allocs(label, n = 100)
  # Warmup
  3.times { yield }

  GC.disable
  before = ObjectSpace.count_objects
  n.times { yield }
  after = ObjectSpace.count_objects
  GC.enable

  total   = (after[:TOTAL] - before[:TOTAL]) / n
  strings = (after[:T_STRING] - before[:T_STRING]) / n
  arrays  = (after[:T_ARRAY] - before[:T_ARRAY]) / n
  hashes  = (after[:T_HASH] - before[:T_HASH]) / n

  printf "%-35s total: %4d  strings: %4d  arrays: %4d  hashes: %4d\n",
    label, total, strings, arrays, hashes
end

measure_allocs("AttributeBuilder.build_data") do
  Hamlit::AttributeBuilder.build_data(true, '"', { "controller" => "app", "action_name" => "index" })
end

measure_allocs("AttributeBuilder.build") do
  Hamlit::AttributeBuilder.build(true, '"', :html, ["disabled", "checked"], nil,
    { "class" => "btn", "id" => "submit", "data" => { "controller" => "app" } })
end

measure_allocs("Compilation") do
  Hamlit::Engine.new.call(haml_code)
end
