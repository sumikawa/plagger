use strict;
use t::TestPlagger;

test_plugin_deps;
plan 'no_plan';
run_eval_expected;

__END__

=== Loading Filter::Flicdotkr
--- input config
plugins:
  - module: CustomFeed::Debug
    config:
      title: foo
      entry:
        - title: bar
          body: http://www.flickr.com/photos/poppen/4038311631/
  - module: Filter::Flicdotkr
    config:
      be: short
--- expected
is $context->update->feeds->[0]->entries->[0]->body, "http://flic.kr/p/79RpmB"
