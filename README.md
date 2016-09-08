# AdHocTemplate

AdHocTemplate is a template processor with simple but sufficent rules for some ad hoc tasks.

I conceived this template as a workaroud for some tasks in a working environment completely left behind the times (maybe 10-15 years or so?), where they don't seem to know what a database is.

And I hope this tool saves you from meaningless tasks when you have to face such a situation.

## Installation

Add this line to your application's Gemfile:

    gem 'ad_hoc_template'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ad_hoc_template

## Usage

The following is an example of template format:

```
a test string with tags (<%= key1 %> and <%= key2 %>) in it

<%#iteration_block
the value of sub_key1 is <%= sub_key1 %>
the value of sub_key2 is <%= sub_key2 %>

#%>
<%= block %>
```

And suppose you want to fill the template with sample data below:

```
key1: value1
key2: value2
key3: value3

///@#iteration_block

sub_key1: value1-1
sub_key2: value1-2

sub_key1: value2-1
sub_key2: value2-2

///@block

the first line of block
the second line of block

the second paragraph in block

```

1. Save the template and sample data above as 'template.txt' and 'sample\_data.txt' respectively.
2. Execute the following at the command line:

```
$ ad_hoc_template template.txt sample_data.txt
```

Then you will get the following result:

```
a test string with tags (value1 and value2) in it

the value of sub_key1 is value1-1
the value of sub_key2 is value1-2

the value of sub_key1 is value2-1
the value of sub_key2 is value2-2

the first line of block
the second line of block

the second paragraph in block

```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
