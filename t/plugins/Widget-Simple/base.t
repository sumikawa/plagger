use strict;
use t::TestPlagger;

test_plugin_deps;
plan 'no_plan';

run {
    my $block = shift;
    my $context = $block->input;
    Plagger->set_context($context);
    my $entry = $context->update->feeds->[0]->entries->[0];
    is $entry->widgets->[0]->html($entry), $block->expected, $block->name;
}

__END__

=== static config
--- input config
plugins:
  - module: Subscription::Config
    config:
      feed:
        - file://$t::TestPlagger::BaseDirURI/t/samples/rss-full.xml
  - module: Widget::Simple
    config:
      link: http://www.example.com/
      content: Hello World
--- expected chomp
<a href="http://www.example.com/">Hello World</a>

=== add query
--- input config
plugins:
  - module: Subscription::Config
    config:
      feed:
        - file://$t::TestPlagger::BaseDirURI/t/samples/rss-full.xml
  - module: Widget::Simple
    config:
      link: http://www.example.com/add
      query:
        url: \$args->{entry}->link
        ver: 4
      content: Hello World
--- expected chomp
<a href="http://www.example.com/add?url=http%3A%2F%2Fsubtech.g.hatena.ne.jp%2Fmiyagawa%2F20060710%2F1152534733&amp;ver=4">Hello World</a>

=== dynamic content
--- input config
plugins:
  - module: Subscription::Config
    config:
      feed:
        - file://$t::TestPlagger::BaseDirURI/t/samples/rss-full.xml
  - module: Widget::Simple
    config:
      link: http://www.example.com/
      content_dynamic: "Entry from [% entry.author | html %]"
--- expected chomp
<a href="http://www.example.com/">Entry from miyagawa</a>

=== Use del.icio.us asset
--- input config
plugins:
  - module: Subscription::Config
    config:
      feed:
        - file://$t::TestPlagger::BaseDirURI/t/samples/rss-full.xml
  - module: Widget::Simple
    config:
      widget: delicious
--- expected chomp
<a href="http://del.icio.us/post?title=+%C3%A3%C2%82%C2%BF%C3%A3%C2%82%C2%A4%C3%A3%C2%83%C2%97%C3%A6%C2%95%C2%B0%C3%A3%C2%82%C2%AB%C3%A3%C2%82%C2%A6%C3%A3%C2%83%C2%B3%C3%A3%C2%82%C2%BF%C3%A3%C2%83%C2%BC%C3%A3%C2%82%C2%92%C3%A3%C2%83%C2%93%C3%A3%C2%82%C2%B8%C3%A3%C2%83%C2%A5%C3%A3%C2%82%C2%A2%C3%A3%C2%83%C2%AB%C3%A8%C2%A1%C2%A8%C3%A7%C2%A4%C2%BA&amp;url=http%3A%2F%2Fsubtech.g.hatena.ne.jp%2Fmiyagawa%2F20060710%2F1152534733"><img src="http://del.icio.us/static/img/delicious.small.gif" alt="del.icio.us it!" style="border:0;vertical-align:middle" /></a>

=== Use Hatena Bookmark asset
--- input config
plugins:
  - module: Subscription::Config
    config:
      feed:
        - file://$t::TestPlagger::BaseDirURI/t/samples/rss-full.xml
  - module: Widget::Simple
    config:
      widget: hatena_bookmark
--- expected chomp
<a href="http://b.hatena.ne.jp/append?http://subtech.g.hatena.ne.jp/miyagawa/20060710/1152534733"><img src="http://b.hatena.ne.jp/images/append.gif" alt="Post to Hatena Bookmark" style="border:0;vertical-align:middle" /></a>

=== Use Hatena Bookmark count asset
--- input config
plugins:
  - module: Subscription::Config
    config:
      feed:
        - file://$t::TestPlagger::BaseDirURI/t/samples/rss-full.xml
  - module: Widget::Simple
    config:
      widget: hatena_bookmark_users
--- expected chomp
<a href="http://b.hatena.ne.jp/entry/http://subtech.g.hatena.ne.jp/miyagawa/20060710/1152534733"><img src="http://b.hatena.ne.jp/entry/image/normal/http://subtech.g.hatena.ne.jp/miyagawa/20060710/1152534733" style="border:0;vertical-align:middle" /></a>
