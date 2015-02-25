require 'spec_helper'

describe AdHocTemplate do
  it 'should have a version number' do
    AdHocTemplate::VERSION.should_not be_nil
  end
end
