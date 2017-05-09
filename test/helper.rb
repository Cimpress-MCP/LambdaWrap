def silence_output
  # Store the original stdout in order to restore later
  @original_stdout = $stdout

  # Redirect stdout
  $stdout = File.new('out.txt', 'w')
end

# Replace stdout so anything else is output correctly
def enable_output
  $stdout = @original_stdout
  @original_stdout = nil
end
