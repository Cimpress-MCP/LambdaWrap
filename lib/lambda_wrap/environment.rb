module LambdaWrap
  # Environment class to pass to the deploy and teardown
  #
  # @!attribute [r] name
  #   @return [String] The descriptive name of the environment.
  #
  # @!attribute [r] description
  #   @return [String] The description of the environment.
  #
  # @!attribute [r] variables
  #   @return [Hash] The Hash of environment variables to deploy with the environment.
  #
  # @since 1.0
  class Environment
    attr_reader :name
    attr_reader :description
    attr_reader :variables

    # Constructor
    #
    # @param name [String] Name of the environment. Corresponds to the Lambda Alias and API Gateway Stage.
    #  Must be at least 3 characters, and no more than 20 characters.
    # @param variables [Hash] Environment variables to pass to the API Gateway stage. Must be a flat hash.
    #  Each key must be Alphanumeric (underscores allowed) and no more than 64 characters. Values can have
    #  most special characters, and no more than 512 characters.
    # @param description [String] Description of the environment for Stage & Alias descriptions. Must not
    #  exceed 256 characters.
    def initialize(name, variables = {}, description = 'Managed by LambdaWrap')
      raise ArgumentError, 'name must be provided (String)!' unless name && name.is_a?(String)
      # Max Alias Name length is 20 characters.
      raise ArgumentError, "Invalid name format: #{name}" unless /^[a-zA-Z0-9\-\_]{3,20}$/ =~ name
      @name = name

      raise ArgumentError, 'Variables must be a Hash!' unless variables.is_a?(Hash)
      variables.each do |key, value|
        next if /^[0-9a-zA-Z\_]{1,64}$/ =~ key && /^[A-Za-z0-9\-.\_~:\/?#&=,]{1,512}$/ =~ value && value.is_a?(String)
        raise ArgumentError, "Invalid Format of variables hash: #{key} => #{value}"
      end

      variables[:environment] = name unless variables[:environment]
      @variables = variables

      raise ArgumentError, 'Description must be a String!' unless description.is_a?(String)
      raise ArgumentError, 'Description too long (Max 256)' unless description.length < 256
      @description = description
    end
  end
end
