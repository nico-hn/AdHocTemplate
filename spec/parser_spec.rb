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

    it("spaces at the head of a line should be preserved when the line is just after a start tag of IterationTagNode") do
      tree = AdHocTemplate::Parser.parse("<%#iteration\n  the second line\nthe third line")
      expect(tree).to eq([[["  the second line\nthe third line"]]])
    end

    it("should not add a newline at the head of IterationTagNode when the type of the node is not specified") do
      tree = AdHocTemplate::Parser.parse("a test string with tags\n<%#iteration_block\nthe value of sub_key1 is <%= sub_key1 %>.\n<%#\n  the value of sub_key2 is <%= sub_key2 %>.\n#%>\n#%>")
      expect(tree).to eq([["a test string with tags\n"], [["the value of sub_key1 is "], [["sub_key1 "]], [".\n"], [["  the value of sub_key2 is "], [["sub_key2 "]], [".\n"]]]])
    end

    describe "with the xml_like1 tag type" do
      it "returns a tree of TagNode and Leaf" do
        expect(AdHocTemplate::Parser.parse("a test string with tags (<!--% the first tag %--> and <!--% the second tag %-->) in it", :xml_like1)).to eq([["a test string with tags ("],
                                                                                                                                    [[" the first tag "]],
                                                                                                                                    [" and "],
                                                                                                                                    [[" the second tag "]],
                                                                                                                                    [") in it"]])
      end

      it "allows to have a nested tag" do
        expect(AdHocTemplate::Parser.parse("a test string with a nested tag; <!--% an outer tag and <!--% an inner tag %--> %-->", :xml_like1)).to eq([["a test string with a nested tag; "],
                                                                                                                                  [[" an outer tag and "],
                                                                                                                                    [[" an inner tag "]],
                                                                                                                                    [" "]]])
      end

      it "may have iteration tags." do
        tree = AdHocTemplate::Parser.parse("a test string with a nested tag: <iterate> an iteration tag and <!--% an inner tag %--> </iterate> and <!--% another tag %-->", :xml_like1)
        expect(tree).to eq([["a test string with a nested tag: "],
                             [[" an iteration tag and "],
                               [[" an inner tag "]],
                               [" "]],
                             [" and "],
                             [[" another tag "]]])
        expect(tree[1]).to be_a_kind_of(AdHocTemplate::Parser::IterationTagNode)
      end

      it "may contain lines that consist only of an iteration tag" do
        tree = AdHocTemplate::Parser.parse("<iterate>iterations
content
</iterate>
", :xml_like1)
        expect(tree).to eq([[["content\n"]]])
      end

      it "must return an empty array when template is an empty string" do
        tree = AdHocTemplate::Parser.parse("", :xml_like1)
        expect(tree).to eq([])
      end
    end

    it("spaces at the head of a line should be preserved when the line is just after a start tag of IterationTagNode") do
      tree = AdHocTemplate::Parser.parse("<iterate>iteration\n  the second line\nthe third line</iterate>", :xml_like1)
      expect(tree).to eq([[["  the second line\nthe third line"]]])
    end

    it("should not add a newline at the head of IterationTagNode when the type of the node is not specified") do
      tree = AdHocTemplate::Parser.parse("a test string with tags\n<iterate>iteration_block\nthe value of sub_key1 is <!--%= sub_key1 %-->.\n<iterate>\n  the value of sub_key2 is <!--%= sub_key2 %-->.\n</iterate>\n</iterate>", :xml_like1)
      expect(tree).to eq([["a test string with tags\n"], [["the value of sub_key1 is "], [["sub_key1 "]], [".\n"], [["  the value of sub_key2 is "], [["sub_key2 "]], [".\n"]]]])
    end
  end
end
