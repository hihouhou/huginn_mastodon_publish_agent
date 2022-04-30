require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::MastodonPublishAgent do
  before(:each) do
    @valid_options = Agents::MastodonPublishAgent.new.default_options
    @checker = Agents::MastodonPublishAgent.new(:name => "MastodonPublishAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
