require './test/helper.rb'

class TestEnvironment < Minitest::Test
  describe LambdaWrap::Environment do
    def setup
      silence_output
    end

    def teardown
      enable_output
    end

    describe ' When constructing the environment ' do
      it ' should be constructed successfully when supplying all values. ' do
        env_under_test = LambdaWrap::Environment.new('ValidName', { foo: 'bar' }, 'Valid Description')
        env_under_test.must_be_instance_of(LambdaWrap::Environment)
        # Can access values
        env_under_test.name.must_equal('ValidName')
        env_under_test.variables[:foo].must_equal('bar')
        env_under_test.description.must_equal('Valid Description')

        # Can't assing values
        proc { env_under_test.name = 'test' }.must_raise(NoMethodError)
        proc { env_under_test.variables = { fiz: 'buzz' } }.must_raise(NoMethodError)
        proc { env_under_test.description = 'test' }.must_raise(NoMethodError)
      end

      it ' should be constructed successfully when supplying some values. ' do
        env_under_test = LambdaWrap::Environment.new('ValidName')
        env_under_test.must_be_instance_of(LambdaWrap::Environment)
      end

      it ' should throw an error with bad values. ' do
        proc { LambdaWrap::Environment.new }.must_raise(ArgumentError)
        proc { LambdaWrap::Environment.new('4') }.must_raise(ArgumentError)
        proc { LambdaWrap::Environment.new(4) }.must_raise(ArgumentError)
        proc { LambdaWrap::Environment.new('Bad Name') }.must_raise(ArgumentError)
        proc { LambdaWrap::Environment.new(true) }.must_raise(ArgumentError)
        proc { LambdaWrap::Environment.new('looooooooooooooooooooooooooooooooooooooooooooooooooongname') }
          .must_raise(ArgumentError)
        proc { LambdaWrap::Environment.new('s') }.must_raise(ArgumentError)
        proc {
          LambdaWrap::Environment.new(
            'validname',
            { baaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa: 'variable' },
            'desc'
          )
        }.must_raise(ArgumentError)
      end
    end
  end
end
