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
          body: http://www.example.com/
  - module: Filter::Flicdotkr
--- expected
is $context->update->feeds->[0]->entries->[0]->body, "http://www.example.com/"
