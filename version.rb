RELEASE_VERSION =
  # builds of release branches
  if ENV['GIT_BRANCH'] && ENV['GIT_BRANCH'].match(/^release[\/-](\d+\.\d+)$/i)
    ENV['GIT_BRANCH'].match(/^release[\/-](\d+\.\d+)$/i)[1]
  # other builds
  else '0'
  end

VERSION = Gem::Version.new("#{RELEASE_VERSION}.#{ENV['BUILD_NUMBER'] || '0'}.0")
