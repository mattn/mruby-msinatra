MRuby::Gem::Specification.new('mruby-msinatra') do |spec|
  spec.license = 'MIT'
  spec.authors = 'mattn'
  spec.add_dependency('mruby-socket')
  spec.add_dependency('mruby-io')
  spec.add_dependency('mruby-http')
end
