require 'spec_helper'
require 'ad_hoc_template'

describe AdHocTemplate do
  it 'should have a version number' do
    AdHocTemplate::VERSION.should_not be_nil
  end

  describe AdHocTemplate::Parser do
    it "returns a tree of TagNode and Leaf" do
      expect(AdHocTemplate::Parser.parse("a test string with tags (<% the first tag %> and <% the second tag %>) in it")).to eq([["a test string with tags ("],
                                                                                                                                 [[" the first tag "]],
                                                                                                                                 [" and "],
                                                                                                                                 [[" the second tag "]],
                                                                                                                                 [") in it"]])
    end

    it "allows to have a nested tag" do
      expect(AdHocTemplate::Parser.parse("a test string with a nested tag; <% an outer tag and <% an inner tag %> %>")).to eq([["a test string with a nested tag; "],
                                                                                                                                [[" an outer tag and "],
                                                                                                                                 [[" an inner tag "]],
                                                                                                                                 [" "]]])
    end
  end
end
