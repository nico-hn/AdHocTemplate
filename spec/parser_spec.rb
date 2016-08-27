#!/usr/bin/env ruby

require 'spec_helper'
require 'ad_hoc_template'

describe AdHocTemplate do
  describe AdHocTemplate::Parser do
    describe "with the default tag type" do
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

      it "may have iteration tags." do
        tree = AdHocTemplate::Parser.parse("a test string with a nested tag: <%# an iteration tag and <% an inner tag %> #%> and <% another tag %>")
        expect(tree).to eq([["a test string with a nested tag: "],
                             [[" an iteration tag and "],
                               [[" an inner tag "]],
                               [" "]],
                             [" and "],
                             [[" another tag "]]])
        expect(tree[1]).to be_a_kind_of(AdHocTemplate::Parser::IterationTagNode)
      end

      it "may contain lines that consist only of an iteration tag" do
        tree = AdHocTemplate::Parser.parse("<%#iterations
content
#%>
")
        expect(tree).to eq([[["content\n"]]])
      end

      it "must return an empty array when template is an empty string" do
        tree = AdHocTemplate::Parser.parse("")
        expect(tree).to eq([])
      end
    end

    describe "with the square brackets tag type" do
      it "returns a tree of TagNode and Leaf" do
        expect(AdHocTemplate::Parser.parse("a test string with tags ([[ the first tag ]] and [[ the second tag ]]) in it", :square_brackets)).to eq([["a test string with tags ("],
                                                                                                                                    [[" the first tag "]],
                                                                                                                                    [" and "],
                                                                                                                                    [[" the second tag "]],
                                                                                                                                    [") in it"]])
      end

      it "allows to have a nested tag" do
        expect(AdHocTemplate::Parser.parse("a test string with a nested tag; [[ an outer tag and [[ an inner tag ]] ]]", :square_brackets)).to eq([["a test string with a nested tag; "],
                                                                                                                                  [[" an outer tag and "],
                                                                                                                                    [[" an inner tag "]],
                                                                                                                                    [" "]]])
      end

      it "may have iteration tags." do
        tree = AdHocTemplate::Parser.parse("a test string with a nested tag: [[# an iteration tag and [[ an inner tag ]] #]] and [[ another tag ]]", :square_brackets)
        expect(tree).to eq([["a test string with a nested tag: "],
                             [[" an iteration tag and "],
                               [[" an inner tag "]],
                               [" "]],
                             [" and "],
                             [[" another tag "]]])
        expect(tree[1]).to be_a_kind_of(AdHocTemplate::Parser::IterationTagNode)
      end

      it "may contain lines that consist only of an iteration tag" do
        tree = AdHocTemplate::Parser.parse("[[#iterations
content
#]]
", :square_brackets)
        expect(tree).to eq([[["content\n"]]])
      end

      it "must return an empty array when template is an empty string" do
        tree = AdHocTemplate::Parser.parse("", :square_brackets)
        expect(tree).to eq([])
      end
    end

    describe "with the curly brackets tag type" do
      it "returns a tree of TagNode and Leaf" do
        expect(AdHocTemplate::Parser.parse("a test string with tags ({{ the first tag }} and {{ the second tag }}) in it", :curly_brackets)).to eq([["a test string with tags ("],
                                                                                                                                    [[" the first tag "]],
                                                                                                                                    [" and "],
                                                                                                                                    [[" the second tag "]],
                                                                                                                                    [") in it"]])
      end

      it "allows to have a nested tag" do
        expect(AdHocTemplate::Parser.parse("a test string with a nested tag; {{ an outer tag and {{ an inner tag }} }}", :curly_brackets)).to eq([["a test string with a nested tag; "],
                                                                                                                                  [[" an outer tag and "],
                                                                                                                                    [[" an inner tag "]],
                                                                                                                                    [" "]]])
      end

      it "may have iteration tags." do
        tree = AdHocTemplate::Parser.parse("a test string with a nested tag: {{# an iteration tag and {{ an inner tag }} #}} and {{ another tag }}", :curly_brackets)
        expect(tree).to eq([["a test string with a nested tag: "],
                             [[" an iteration tag and "],
                               [[" an inner tag "]],
                               [" "]],
                             [" and "],
                             [[" another tag "]]])
        expect(tree[1]).to be_a_kind_of(AdHocTemplate::Parser::IterationTagNode)
      end

      it "may contain lines that consist only of an iteration tag" do
        tree = AdHocTemplate::Parser.parse("{{#iterations
content
#}}
", :curly_brackets)
        expect(tree).to eq([[["content\n"]]])
      end

      it "must return an empty array when template is an empty string" do
        tree = AdHocTemplate::Parser.parse("", :curly_brackets)
        expect(tree).to eq([])
      end
    end
  end
end