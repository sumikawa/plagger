use t::TestPlagger;
use utf8;

test_plugin_deps;
test_requires_network;

plan 'no_plan';
run_eval_expected;

__END__

=== Test mrzine
--- input config
global:
  cache:
    class: Plagger::Cache::Null
plugins:
  - module: CustomFeed::Debug
    config:
      entry:
        - title: foo
          link: http://mrzine.monthlyreview.org/2010/schieder150610.html
  - module: Filter::EntryFullText
--- expected
is $context->update->feeds->[0]->entries->[0]->title, 'Chelsea Szendi Schieder, "Two, Three, Many 1960s"';
