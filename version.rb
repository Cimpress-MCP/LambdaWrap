RELEASE_VERSION = case
  # builds of release branches
  when ENV['GIT_BRANCH'] && ENV['GIT_BRANCH'].match(/^release[\/-](\d+\.\d+)$/i) then ENV['GIT_BRANCH'].match(/^release[\/-](\d+\.\d+)$/i)[1]
  # other builds
  else '0'
end
VERSION = Gem::Version.new("#{RELEASE_VERSION}.#{ENV['BUILD_NUMBER'] || '0'}.0")