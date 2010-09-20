package Plagger::Plugin::CustomFeed::Config;
use strict;
use base qw( Plagger::Plugin );

use DirHandle;
use Encode;
use File::Spec;
use List::Util qw(first);
use Plagger::Date; # for metadata in plugins
use Plagger::Util qw( decode_content );
use Plagger::UserAgent;

our $VERSION = 0.02;

sub register {
    my($self, $context) = @_;
    $context->register_hook(
        $self,
        'customfeed.handle'  => \&handle,
    );
}

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    $self->load_plugins();

    $self->{ua} = Plagger::UserAgent->new;
}

sub load_plugins {
    my $self = shift;
    my $context = Plagger->context;

    $self->load_assets('*.yaml', sub { $self->load_plugin_yaml(@_) });
    $self->load_assets('*.pl',   sub { $self->load_plugin_perl(@_) });
}

sub load_plugin_perl {
    my($self, $file, $base) = @_;

    Plagger->context->log(debug => "Load plugin $file");

    open my $fh, '<', $file or Plagger->context->error("$file: $!");
    (my $pkg = $base) =~ s/\.pl$//;
    my $plugin_class = "Plagger::Plugin::CustomFeed::Config::Site::$pkg";

    if ($plugin_class->can('new')) {
        Plagger->context->log(warn => "$plugin_class is already defined. skip compiling code");
        return $plugin_class->new;
    }

    my $code = join '', <$fh>;
    unless ($code =~ /^\s*package/s) {
        $code = join "\n",
            ( "package $plugin_class;",
              "use strict;",
              "use base qw( Plagger::Plugin::CustomFeed::Config::Site );",
              "sub site_name { '$pkg' }",
              $code,
              "1;" );
    }

    eval $code;
    Plagger->context->error($@) if $@;

    push @{ $self->{plugins} }, $plugin_class->new;
}

sub load_plugin_yaml {
    my($self, $file, $base) = @_;

    Plagger->context->log(debug => "Load YAML $file");
    my @data = YAML::LoadFile($file);

    push @{ $self->{plugins} },
        map { Plagger::Plugin::CustomFeed::Config::YAML->new($_, $base) } @data;
}

sub handle {
    my($self, $context, $args) = @_;

    # NoNetwork: don't connect for 3 hours
    my $res = $self->{ua}->fetch( $args->{feed}->url, $self, { NoNetwork => 60 * 60 * 3 } );
    if (!$res->status && $res->is_error) {
        $context->log(debug => "Fetch " . $args->{feed}->url . " failed");
        return;
    }

    $args->{content} = decode_content($res);

    # if the request was redirected, set it as feed url
    if ($res->http_response) {
        my $base = $res->http_response->request->uri;
        if ( $base ne $args->{feed}->url ) {
            $context->log(info => "rewrite url to $base");
            $args->{feed}->url($base);
        }
    }

    my $handler = first { $_->custom_feed_handle($args) } @{ $self->{plugins} };
    if ($handler && $args->{feed}->url !~ /output=(?:rss|atom)/) {
        $context->log(debug => $args->{feed}->url . " custom_feed_handle by " . $handler->site_name);
        return $handler->aggregate($context, $args);
    }
    return;
}


package Plagger::Plugin::CustomFeed::Config::Site;
sub new { bless {}, shift }
sub custom_feed_handle { 0 }
sub custom_feed_follow_link { }
sub custom_feed_follow_xpath { }

package Plagger::Plugin::CustomFeed::Config::YAML;
use Encode;
use List::Util qw(first);
use Plagger::Util qw( decode_content extract_title );

sub new {
    my($class, $data, $base) = @_;

    # old version compatible
    for my $key ( qw(match) ) {
        next unless defined $data->{$key};
        $data->{custom_feed_handle} = $data->{$key};
    }
    for my $key ( qw(extract extract_date_format extract_date_timezone extract_capture extract_xpath extract_after_hook) ) {
        next unless defined $data->{$key};
        if (ref $data->{$key} && ref $data->{$key} eq 'ARRAY') {
            $data->{'custom_feed_' . $key} = [ map $_, @{$data->{$key}} ];
        } else {
            $data->{'custom_feed_' . $key} = $data->{$key};
        }
    }

    # add ^ if handle method starts with http://
    for my $key ( qw(custom_feed_handle) ) {
        next unless defined $data->{$key};
        $data->{$key} = "^$data->{$key}" if $data->{$key} =~ m!^https?://!;
    }

    # decode as UTF-8
    for my $key ( qw(custom_feed_extract custom_feed_extract_date_format custom_feed_extract_after_hook) ) {
        next unless defined $data->{$key};
        if (ref $data->{$key} && ref $data->{$key} eq 'ARRAY') {
            $data->{$key} = [ map decode("UTF-8", $_), @{$data->{$key}} ];
        } else {
            $data->{$key} = decode("UTF-8", $data->{$key});
        }
    }

    bless {%$data, base => $base }, $class;
}

sub site_name {
    my $self = shift;
    $self->{base};
}

sub custom_feed_handle {
    my($self, $args) = @_;
    $self->{custom_feed_handle} ?
        $args->{feed}->url =~ /$self->{custom_feed_handle}/ : 0;
}

sub xml_escape {
    for my $x (@_) {
        $x = Plagger::Util::encode_xml($x);
    }
}

sub aggregate {
    my($self, $context, $args) = @_;

    unless ($self->{custom_feed_extract} || $self->{custom_feed_extract_xpath}) {
        $context->log(error => "YAML doesn't have either 'custom_feed_extract' nor 'custom_feed_extract_xpath'");
        return;
    }

    my $feed = Plagger::Feed->new;
    $feed->title($args->{feed}->title || extract_title($args->{content}));
    $feed->link($args->{feed}->url);

    my $prev_pos = 0;
    my $cur_pos = 0;
    my %nodes = ();

    if ($self->{custom_feed_extract_xpath}) {
        eval { require HTML::TreeBuilder::XPath };
        if ($@) {
            $context->log(error => "HTML::TreeBuilder::XPath is required. $@");
            return;
        }

        my $tree = HTML::TreeBuilder::XPath->new;
        $tree->parse($args->{content});
        $tree->eof;

        for my $capture (keys %{$self->{custom_feed_extract_xpath}}) {
            @{%nodes->{$capture}} = $tree->findnodes($self->{custom_feed_extract_xpath}->{$capture});
            unless (@{%nodes->{$capture}}) {
                $context->log(error => "Can't find node matching $self->{custom_feed_extract_xpath}->{$capture}");
            }
        }
    }

    while (1) {
        my $data;

        if ($self->{custom_feed_extract}) {
            my $extract = decode_content($self->{custom_feed_extract});
            if ($args->{content} =~ /$extract/sg) {
                $cur_pos = pos $args->{content};
                my $str = substr($args->{content}, $prev_pos, length($args->{content}));
                if (my @match = $str =~ /$extract/s) {
                    my @capture = split /\s+/, $self->{custom_feed_extract_capture};
                    for my $m (@match) {
                        my $val = shift @capture;
                        $data->{$val} = $data->{$val} . $m;
                    }
                }
                $prev_pos = $cur_pos;
            }
        }

        if (%nodes) {
            for my $capture (keys %{$self->{custom_feed_extract_xpath}}) {
                no warnings 'redefine';
                local *HTML::Element::_xml_escape = \&xml_escape;
                my $children = shift @{%nodes->{$capture}};
                if ($children) {
                    $data->{$capture} = $children->isElementNode
                    ? $children->as_XML
                    : $children->getValue;;
                }
            }
        }

        unless ($data) {
            last;
        }

        if ($self->{custom_feed_extract_after_hook}) {
            eval $self->{custom_feed_extract_after_hook};
            $context->error($@) if $@;
        }
        
        unless ($data->{title} || $data->{link}) {
            $context->log(error => "doesn't have either 'title' nor 'link'");
            return;
        }
        
        if ($data->{date}) {
            if (my $format = $self->{custom_feed_extract_date_format}) {
                $format = [ $format ] unless ref $format;
                $data->{date} = (map { Plagger::Date->strptime($_, $data->{date}) } @$format)[0];
                if ($data->{date} && $self->{custom_feed_extract_date_timezone}) {
                    $data->{date}->set_time_zone($self->{custom_feed_extract_date_timezone});
                }
            } else {
                $data->{date} = Plagger::Date->parse_dwim($data->{date});
            }
        }

        my $entry = Plagger::Entry->new;

        $entry->id($data->{link});
        $entry->link($data->{link});
        $entry->title($data->{title});
        $entry->body($data->{body}) if $data->{body};
        $entry->author($data->{author}) if $data->{author};
        $entry->icon({ url => $data->{icon} }) if $data->{icon};
        $entry->summary($data->{summary}) if $data->{summary};

        # extract date using found one
        if ($data->{date}) {
            $entry->date($data->{date});
        }

        $feed->add_entry($entry);

        $context->log(info => "Add $data->{link} ($data->{title})");
    }

    $context->update->add($feed);

    return 1;
}

1;

__END__

=head1 NAME

Plagger::Plugin::CustomFeed::Config - Configurable way to create title and link only custom feeds

=head1 SYNOPSIS

  - module: Subscription::Config
    config:
      feed:
        - http://www.softantenna.com/index.html

  - module: CustomFeed::Config

=head1 DESCRIPTION

This plugin creates a custom feed off of HTML pages.
Use with EntryFullText plugin to get full content and accurate
datetime of articles.

You can write custom feed handler by putting C<.pl> or C<.yaml>
files under assets plugin directory.

=head1 AUTHOR

Kazushi Tominaga

=head1 SEE ALSO

L<Plagger>
