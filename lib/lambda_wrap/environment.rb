require 'active_support/core_ext/hash'

module LambdaWrap
  ##
  # Environment class to pass to the deploy and teardown
  class Environment
    attr_accessor :name
    attr_accessor :description
    attr_accessor :variables
    def initialize(name, variables = {}, description = '')
      @name = name
      @variables = variables
      @description = description
    end
  end
end
