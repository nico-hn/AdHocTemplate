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
        expect(tree[1]).to be_a_kind_of(AdHocTemplate::Parser::IterationNode)
      end

      it "may contain lines that consist only of an iteration tag" do
        tree = AdHocTemplate::Parser.parse("<%#iterations:
content
#%>
")
        expect(tree).to eq([[["content\n"]]])
      end

      it "must return an empty array when template is an empty string" do
        tree = AdHocTemplate::Parser.parse("")
        expect(tree).to eq([])
      end


      it "does not remove indents from the lines which contain only iteration tag" do
        template_without_indent = <<TEMPLATE_WITHOUT_INDENT
A template with an iteration tag

<%#
    This part will be repeated with <!--% variable %-->
#%>

TEMPLATE_WITHOUT_INDENT

        template_with_indent = <<TEMPLATE
A template with an iteration tag

  <%#
    This part will be repeated with <!--% variable %-->
  #%>

TEMPLATE

        without_indent = AdHocTemplate::Parser.parse(template_without_indent)
        with_indent = AdHocTemplate::Parser.parse(template_with_indent)

        expect(with_indent).not_to eq(without_indent)
      end

      it "may contains nested tags and the first inner tag may not have preceding strings" do
        template = "main start <%#<%= var1 %> inner part <%= var2 %> inner end #%> main end"
        tree = AdHocTemplate::Parser.parse(template)
        expect(tree).to eq([
                             ["main start "],
                             [
                               [["var1 "]],
                               [" inner part "],
                               [["var2 "]],
                               [" inner end "]],
                             [" main end"]])
      end

      it "tags may be put side by side without any string in between" do
        template = "main start <%# inner start<%= var1 %><%= var2 %>inner end #%> main end"
        tree = AdHocTemplate::Parser.parse(template)
        expect(tree).to eq([
                             ["main start "],
                             [
                               [" inner start"],
                               [["var1 "]],
                               [["var2 "]],
                               ["inner end "]],
                             [" main end"]])
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
        expect(tree[1]).to be_a_kind_of(AdHocTemplate::Parser::IterationNode)
      end

      it "may contain lines that consist only of an iteration tag" do
        tree = AdHocTemplate::Parser.parse("[[#iterations:
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
        expect(tree[1]).to be_a_kind_of(AdHocTemplate::Parser::IterationNode)
      end

      it "may contain lines that consist only of an iteration tag" do
        tree = AdHocTemplate::Parser.parse("{{#iterations:
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

    it("spaces at the head of a line should be preserved when the line is just after a start tag of IterationNode") do
      tree = AdHocTemplate::Parser.parse("<%#iteration:\n  the second line\nthe third line")
      expect(tree).to eq([[["  the second line\nthe third line"]]])
    end

    it("should not add a newline at the head of IterationNode when the type of the node is not specified") do
      tree = AdHocTemplate::Parser.parse("a test string with tags\n<%#iteration_block:\nthe value of sub_key1 is <%= sub_key1 %>.\n<%#\n  the value of sub_key2 is <%= sub_key2 %>.\n#%>\n#%>")
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
        expect(tree[1]).to be_a_kind_of(AdHocTemplate::Parser::IterationNode)
      end

      it "may contain lines that consist only of an iteration tag" do
        tree = AdHocTemplate::Parser.parse("<iterate>iterations:
content
</iterate>
", :xml_like1)
        expect(tree).to eq([[["content\n"]]])
      end

      it "must return an empty array when template is an empty string" do
        tree = AdHocTemplate::Parser.parse("", :xml_like1)
        expect(tree).to eq([])
      end

      it("spaces at the head of a line should be preserved when the line is just after a start tag of IterationNode") do
        tree = AdHocTemplate::Parser.parse("<iterate>iteration:\n  the second line\nthe third line</iterate>", :xml_like1)
        expect(tree).to eq([[["  the second line\nthe third line"]]])
      end

      it("should not add a newline at the head of IterationNode when the type of the node is not specified") do
        tree = AdHocTemplate::Parser.parse("a test string with tags\n<iterate>iteration_block:\nthe value of sub_key1 is <!--%= sub_key1 %-->.\n<iterate>\n  the value of sub_key2 is <!--%= sub_key2 %-->.\n</iterate>\n</iterate>", :xml_like1)
        expect(tree).to eq([["a test string with tags\n"], [["the value of sub_key1 is "], [["sub_key1 "]], [".\n"], [["  the value of sub_key2 is "], [["sub_key2 "]], [".\n"]]]])
      end

      it "removes indents from the lines which contain only iteration tag" do
        template_without_indent = <<TEMPLATE_WITHOUT_INDENT
A template with an iteration tag

<iterate>
    This part will be repeated with <!--% variable %-->
</iterate>

TEMPLATE_WITHOUT_INDENT

        template_with_indent = <<TEMPLATE
A template with an iteration tag

  <iterate>
    This part will be repeated with <!--% variable %-->
  </iterate>

TEMPLATE

        without_indent = AdHocTemplate::Parser.parse(template_without_indent, :xml_like1)
        with_indent = AdHocTemplate::Parser.parse(template_with_indent, :xml_like1)

        expect(with_indent).to eq(without_indent)
      end
    end

    describe "with the xml_like2 tag type" do
      it "returns a tree of TagNode and Leaf" do
        expect(AdHocTemplate::Parser.parse("a test string with tags (<fill> the first tag </fill> and <fill> the second tag </fill>) in it", :xml_like2)).to eq([["a test string with tags ("],
                                                                                                                                    [[" the first tag "]],
                                                                                                                                    [" and "],
                                                                                                                                    [[" the second tag "]],
                                                                                                                                    [") in it"]])
      end

      it "allows to have a nested tag" do
        expect(AdHocTemplate::Parser.parse("a test string with a nested tag; <fill> an outer tag and <fill> an inner tag </fill> </fill>", :xml_like2)).to eq([["a test string with a nested tag; "],
                                                                                                                                  [[" an outer tag and "],
                                                                                                                                    [[" an inner tag "]],
                                                                                                                                    [" "]]])
      end

      it "may have iteration tags." do
        tree = AdHocTemplate::Parser.parse("a test string with a nested tag: <iterate> an iteration tag and <fill> an inner tag </fill> </iterate> and <fill> another tag </fill>", :xml_like2)
        expect(tree).to eq([["a test string with a nested tag: "],
                             [[" an iteration tag and "],
                               [[" an inner tag "]],
                               [" "]],
                             [" and "],
                             [[" another tag "]]])
        expect(tree[1]).to be_a_kind_of(AdHocTemplate::Parser::IterationNode)
      end

      it "may contain lines that consist only of an iteration tag" do
        tree = AdHocTemplate::Parser.parse("<iterate>iterations:
content
</iterate>
", :xml_like2)
        expect(tree).to eq([[["content\n"]]])
      end

      it "must return an empty array when template is an empty string" do
        tree = AdHocTemplate::Parser.parse("", :xml_like2)
        expect(tree).to eq([])
      end

      it("spaces at the head of a line should be preserved when the line is just after a start tag of IterationNode") do
        tree = AdHocTemplate::Parser.parse("<iterate>iteration:\n  the second line\nthe third line</iterate>", :xml_like2)
        expect(tree).to eq([[["  the second line\nthe third line"]]])
      end

      it("should not add a newline at the head of IterationNode when the type of the node is not specified") do
        tree = AdHocTemplate::Parser.parse("a test string with tags\n<iterate>iteration_block:\nthe value of sub_key1 is <fill>= sub_key1 </fill>.\n<iterate>\n  the value of sub_key2 is <fill>= sub_key2 </fill>.\n</iterate>\n</iterate>", :xml_like2)
        expect(tree).to eq([["a test string with tags\n"], [["the value of sub_key1 is "], [["sub_key1 "]], [".\n"], [["  the value of sub_key2 is "], [["sub_key2 "]], [".\n"]]]])
      end
    end

    describe "with the xml_comment_like tag type" do
      it "returns a tree of TagNode and Leaf" do
        expect(AdHocTemplate::Parser.parse("a test string with tags (<!--% the first tag %--> and <!--% the second tag %-->) in it", :xml_comment_like)).to eq([["a test string with tags ("],
                                                                                                                                    [[" the first tag "]],
                                                                                                                                    [" and "],
                                                                                                                                    [[" the second tag "]],
                                                                                                                                    [") in it"]])
      end

      it "allows to have a nested tag" do
        expect(AdHocTemplate::Parser.parse("a test string with a nested tag; <!--% an outer tag and <!--% an inner tag %--> %-->", :xml_comment_like)).to eq([["a test string with a nested tag; "],
                                                                                                                                  [[" an outer tag and "],
                                                                                                                                    [[" an inner tag "]],
                                                                                                                                    [" "]]])
      end

      it "may have iteration tags." do
        tree = AdHocTemplate::Parser.parse("a test string with a nested tag: <!--%iterate%--> an iteration tag and <!--% an inner tag %--> <!--%/iterate%--> and <!--% another tag %-->", :xml_comment_like)
        expect(tree).to eq([["a test string with a nested tag: "],
                             [[" an iteration tag and "],
                               [[" an inner tag "]],
                               [" "]],
                             [" and "],
                             [[" another tag "]]])
        expect(tree[1]).to be_a_kind_of(AdHocTemplate::Parser::IterationNode)
      end

      it "may contain lines that consist only of an iteration tag" do
        tree = AdHocTemplate::Parser.parse("<!--%iterate%-->iterations:
content
<!--%/iterate%-->
", :xml_comment_like)
        expect(tree).to eq([[["content\n"]]])
      end

      it "must return an empty array when template is an empty string" do
        tree = AdHocTemplate::Parser.parse("", :xml_comment_like)
        expect(tree).to eq([])
      end

      it("spaces at the head of a line should be preserved when the line is just after a start tag of IterationNode") do
        tree = AdHocTemplate::Parser.parse("<!--%iterate%-->iteration:\n  the second line\nthe third line<!--%/iterate%-->", :xml_comment_like)
        expect(tree).to eq([[["  the second line\nthe third line"]]])
      end

      it("should not add a newline at the head of IterationNode when the type of the node is not specified") do
        tree = AdHocTemplate::Parser.parse("a test string with tags\n<!--%iterate%-->iteration_block:\nthe value of sub_key1 is <!--%= sub_key1 %-->.\n<!--%iterate%-->\n  the value of sub_key2 is <!--%= sub_key2 %-->.\n<!--%/iterate%-->\n<!--%/iterate%-->", :xml_comment_like)
        expect(tree).to eq([["a test string with tags\n"], [["the value of sub_key1 is "], [["sub_key1 "]], [".\n"], [["  the value of sub_key2 is "], [["sub_key2 "]], [".\n"]]]])
      end

      it "removes indents from the lines which contain only iteration tag" do
        template_without_indent = <<TEMPLATE_WITHOUT_INDENT
A template with an iteration tag

<!--%iterate%-->
    This part will be repeated with <!--% variable %-->
<!--%/iterate%-->

TEMPLATE_WITHOUT_INDENT

        template_with_indent = <<TEMPLATE
A template with an iteration tag

  <!--%iterate%-->
    This part will be repeated with <!--% variable %-->
  <!--%/iterate%-->

TEMPLATE

        without_indent = AdHocTemplate::Parser.parse(template_without_indent, :xml_comment_like)
        with_indent = AdHocTemplate::Parser.parse(template_with_indent, :xml_comment_like)

        expect(with_indent).to eq(without_indent)
      end

      it "removes indents from the lines which contain only a labeled iteration tag" do
        template_without_indent = <<TEMPLATE_WITHOUT_INDENT
A template with an iteration tag

<!--%iterate%-->label:
    This part will be repeated with <!--% variable %-->
<!--%/iterate%-->

TEMPLATE_WITHOUT_INDENT

        template_with_indent = <<TEMPLATE
A template with an iteration tag

  <!--%iterate%-->label:
    This part will be repeated with <!--% variable %-->
  <!--%/iterate%-->

TEMPLATE

        without_indent = AdHocTemplate::Parser.parse(template_without_indent, :xml_comment_like)
        with_indent = AdHocTemplate::Parser.parse(template_with_indent, :xml_comment_like)

        expect(with_indent).to eq(without_indent)
      end
    end

    describe ".register_user_defined_tag_type" do
      it "allow to defined a tag type in YAML format" do
        tag_type_config = <<CONFIG
tag_name: xml_like3
tag: ["<!--%", "%-->"]
iteration_tag: ["<repeat>", "</repeat>"]
fallback_tag: ["<fallback>", "</fallback>"]
remove_indent: true
CONFIG
        iteration_tag_node = AdHocTemplate::Parser::IterationNode
        AdHocTemplate::Parser.register_user_defined_tag_type(tag_type_config)
        defined_tag_type = AdHocTemplate::Parser::TagType[:xml_like3]
        expect(defined_tag_type.head_of[iteration_tag_node]).to eq('<repeat>')
        expect(defined_tag_type.tail_of[iteration_tag_node]).to eq('</repeat>')
        expect(defined_tag_type.remove_iteration_indent).to eq(true)
      end

      it "raises an error if a given definition does not contain sufficient information" do
        tag_type_config = <<CONFIG
tag_name: 
tag: ["<!--%", "%-->"]
iteration_tag: ["<repeat>", "</repeat>"]
fallback_tag: ["<fallback>", "</fallback>"]
remove_indent: true
CONFIG
        expect {
          AdHocTemplate::Parser.register_user_defined_tag_type(tag_type_config)
        }.to raise_error(AdHocTemplate::Parser::UserDefinedTagTypeConfigError,
                         '"tag_name" should be defined.')
      end
    end

    describe "#contains_any_value_tag?" do
      it 'return true if any value tag is contained' do
        template_with_value_tag =<<TEMPLATE
main start

<%#
<%*
line without value tag
*%>
<%*
line with <%= value tag %>
*%>
#%>


main end
TEMPLATE
        parsed = AdHocTemplate::Parser.parse(template_with_value_tag)
        expect(parsed[1].contains_any_value_tag?).to be_truthy
      end

      it 'return false if no value tag is contained' do
        template_without_value_tag =<<TEMPLATE
main start

<%#
<%*
line without value tag
*%>
#%>


main end
TEMPLATE

        parsed = AdHocTemplate::Parser.parse(template_without_value_tag)

        expect(parsed[1].contains_any_value_tag?).to be_falsy
      end
    end

    describe "#inner_iteration_tag_labels" do
      it "returns labels of inner iteration tags" do
        template =<<TEMPLATE
<%#authors:
Name: <%= name %>
Birthplace: <%= birthplace %>
Works:
<%#works|name:
 * <%= title %>
<%#
<%#bio|name:
Born: <%= birth_date %>
#%>
#%>
#%>

#%>
TEMPLATE

        tree = AdHocTemplate::Parser.parse(template)
        expect(tree[0].inner_iteration_tag_labels).to eq (%w(#works|name #bio|name))
      end

          it "returns nil when there is no inner iteration tags" do
        template =<<TEMPLATE
<%#
Name: <%= name %>
Birthplace: <%= birthplace %>
Works:
 * <%= title %>
<%#
Born: <%= birth_date %>
#%>
#%>
TEMPLATE

        tree = AdHocTemplate::Parser.parse(template)
        expect(tree[0].inner_iteration_tag_labels).to be_nil
      end
    end

    describe AdHocTemplate::Parser::FallbackNode do
      it 'is expected to be parsed like IterationNode -- used inline' do
        source = 'main start <%# <%* content in fallback_tag <%= tag node in fallback tag %> fallback end *%> optional content with <%#iterations: in iteration tag <%= item %> #%> iteration part end  #%> main end'
        expected_tree = [
          ["main start "],
          [
            [" "],
            [
              [" content in fallback_tag "],
              [["tag node in fallback tag "]],
              [" fallback end "]
            ],
            [" optional content with "],
            [
              ["in iteration tag "],
              [["item "]],
              [" "]],
            [" iteration part end  "]],
          [" main end"]
        ]

        tree = AdHocTemplate::Parser.parse(source)
        fallback = tree[1][1]

        expect(tree).to eq(expected_tree)
        expect(fallback).to be_kind_of(AdHocTemplate::Parser::FallbackNode)
      end
    end
  end
end
