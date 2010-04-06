use strict;
use t::TestPlagger;

test_plugin_deps;
plan 'no_plan';
run_eval_expected;

__END__

=== Loading Filter::Atlassian::Confluence
--- input config
plugins:
  - module: Filter::Atlassian::Confluence
--- expected
ok 1, $block->name;
