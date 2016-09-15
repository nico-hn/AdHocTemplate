#!/usr/bin/env ruby

describe AdHocTemplate do
  describe AdHocTemplate::DefaultTagFormatter::PseudoHikiFormatter do
    it 'with "ph" format label, you can use Hiki notation' do
      config_data = <<CONFIG
///@#iteration

key1: value1-1
key2: value2-1 with [[a link|http://www.example.org/]]

key1: value1-2
key2: value2-2

///@block

the ''first'' line of block
the second line of block

the second paragraph in block

CONFIG

      template = <<TEMPLATE
<ul>
<%#iteration:
  <li>
    <ul>
      <li><%ph key1 %></li>
      <li><%ph key2 %></li>
    </ul>
  </li>
#%>
</ul>

<%ph block %>
TEMPLATE

      expected_result = <<RESULT
<ul>
  <li>
    <ul>
      <li>value1-1</li>
      <li>value2-1 with <a href="http://www.example.org/">a link</a></li>
    </ul>
  </li>
  <li>
    <ul>
      <li>value1-2</li>
      <li>value2-2</li>
    </ul>
  </li>
</ul>

<p>
the <em>first</em> line of block
the second line of block
</p>
<p>
the second paragraph in block
</p>

RESULT

      result = AdHocTemplate.render(config_data, template)
      expect(result).to eq(expected_result)
    end
  end
end
