require "ad_hoc_template/version"
require "pseudohiki/inlineparser"

module AdHocTemplate
  class Parser < TreeStack
    class TagNode < Parser::Node; end
    class Leaf < Parser::Leaf; end

    HEAD, TAIL = {}, {}

    [[TagNode, "<%", "%>"]].each do |type, head, tail|
      HEAD[head] = type
      TAIL[tail] = type
    end

    TOKEN_PAT = PseudoHiki.compile_token_pat(HEAD.keys, TAIL.keys)

    def self.split_into_tokens(str)
      tokens = []
      while m = TOKEN_PAT.match(str)
        tokens.push m.pre_match unless m.pre_match.empty?
        tokens.push m[0]
        str = m.post_match
      end
      tokens.push str unless str.empty?
      tokens
    end

    def self.parse(str)
      new(str).parse.tree
    end

    def initialize(str)
      @tokens = Parser.split_into_tokens(str)
      super()
    end

    def parse
      while token = @tokens.shift
        next if TAIL[token] == current_node.class and self.pop
        next if HEAD[token] and self.push HEAD[token].new
        self.push Leaf.create(token)
      end
      self
    end
  end
end
