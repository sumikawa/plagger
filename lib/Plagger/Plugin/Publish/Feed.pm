package Plagger::Plugin::Publish::Feed;

use strict;
use base qw( Plagger::Plugin );

use XML::Feed;
use XML::Feed::Entry;
use XML::RSS::LibXML;
use File::Spec;
eval {
    require XML::Feed::RSS;
    require XML::Feed::Format::RSS;
};

sub register {
    my($self, $context) = @_;
    $context->autoload_plugin({ module => 'Filter::FloatingDateTime' });
    $context->register_hook(
        $self,
        'publish.feed' => \&publish_feed,
        'plugin.init'  => \&plugin_init,
    );
}

sub plugin_init {
    my($self, $context, $args) = @_;

    # check dir
    my $dir = $self->conf->{dir};
    unless (-e $dir && -d _) {
        mkdir $dir, 0755 or $context->error("mkdir $dir: $!");
    }

    unless (exists $self->conf->{full_content}) {
        $self->conf->{full_content} = 1;
    }
}

sub cleanup {
    my ($in) = @_;
    $in =~ s/&nbsp;/&#160;/g;
    return $in;
}

sub publish_feed {
    my($self, $context, $args) = @_;

    my $conf = $self->conf;
    my $f = $args->{feed};
    my $feed_format = $conf->{format} || 'Atom';

    # generate feed
    my $feed = XML::Feed->new($feed_format);
    $feed->title($f->title);
    $feed->link($f->link);
    $feed->modified(Plagger::Date->now);
    $feed->generator("Plagger/$Plagger::VERSION");
    $feed->description($f->description);
    $feed->copyright($f->meta->{copyright}) if $f->meta->{copyright};
    $feed->author( $self->make_author($f->author, $feed_format) )
        if $f->primary_author;

    my $taguri_base = $self->conf->{taguri_base} || do {
        require Sys::Hostname;
        Sys::Hostname::hostname();
    };

    if ($feed_format eq 'Atom') {
        $feed->{atom}->id("tag:$taguri_base,2006:" . $f->id); # XXX what if id is empty?
    }

    if ($self->conf->{hub} && $feed_format eq 'Atom') {
        $feed->{atom}->add_link({ rel => 'hub', href => $self->conf->{hub}, });
    }

    if ($self->conf->{self} && $feed_format eq 'Atom') {
        $feed->{atom}->add_link({ rel => 'self', href => $self->conf->{self}, });
    }

    # add entry
    for my $e ($f->entries) {
        my $entry = XML::Feed::Entry->new($feed_format);
        $entry->title($e->title);
        $entry->link($e->permalink);
        $entry->summary(cleanup($e->body_text)) if defined $e->body;

        # hack to bypass XML::Feed Atom 0.3 crufts (type="text/html")
        if ($self->conf->{full_content} && defined $e->body) {
            if ($feed_format eq 'RSS') {
                $entry->content(cleanup($e->body));
            } else {
                $entry->{entry}->content(cleanup($e->body->utf8));
            }
        }

        $entry->category(@{$e->tags}) if @{$e->tags};
        $entry->issued($e->date)   if $e->date;
        $entry->modified($e->date) if $e->date;

        if ($feed_format eq 'RSS') {
            my $author = 'nobody@example.com';
            $author .= ' (' . $e->author . ')' if $e->author;
            $entry->author($author);
        } else {
            unless ($feed->author) {
                $entry->author($e->author || 'nobody');
            }
        }

        $entry->id("tag:$taguri_base,2006:" . $e->id);

        if ($e->has_enclosure) {
            $XML::Feed::MULTIPLE_ENCLOSURES = 1;
            for my $enclosure (grep { defined $_->url && !$_->is_inline } $e->enclosures) {
                $entry->enclosure({
                    url    => $enclosure->url,
                    length => $enclosure->length,
                    type   => $enclosure->type,
                });

                # RSS 2.0 by spec doesn't allow multiple enclosures
                last if $feed_format eq 'RSS';
            }
        }

        $feed->add_entry($entry);
    }

    # generate file path
    my $tmpl = '%i.' . ($feed_format eq 'RSS' ? 'rss' : 'atom');
    my $file = Plagger::Util::filename_for($f, $self->conf->{filename} || $tmpl);
    my $filepath = File::Spec->catfile($self->conf->{dir}, $file);

    $context->log(info => "save feed for " . $f->link . " to $filepath");

    my $xml = $feed->as_xml;
    utf8::decode($xml) unless utf8::is_utf8($xml);
    open my $output, ">:utf8", $filepath or $context->error("$filepath: $!");
    print $output $xml;
    close $output;
}

sub make_author {
    my($self, $author, $feed_format) = @_;

    if ($feed_format eq 'RSS') {
        my $rfc822 = 'nobody@example.com';
        $rfc822 .= ' (' . $author . ')' if $author;
        return $rfc822;
    } else {
        return defined $author ? $author : 'nobody';
    }
}

1;

__END__

=head1

Plagger::Plugin::Publish::Feed - republish RSS/Atom feeds

=head1 SYNOPSIS

  - module: Publish::Feed
    config:
      format: RSS
      dir: /home/yoshiki/plagger/feed
      filename: my_%t.rss

=head1 CONFIG

=over 4

=item format

Specify the format of feed. C<Plagger::Plugin::Publish::Feed> supports
the following syndication feed formats:

=over 8

=item Atom (default)

=item RSS

=back

=item dir

Directory to save feed files in.

=item filename

Filename to be used to create feed files. It defaults to C<%i.rss> for
RSS and C<%i.atom> for Atom feed. It supports the following format
like printf():

=over 8

=item %u url

=item %l link

=item %t title

=item %i id

=back

=item full_content

Whether to publish full content feed. Defaults to 1.

=item taguri_base

Domain name to use with Tag URI base for Atom feed IDs. If it's not
set, the domain is grabbed using Sys::Hostname module Optional.

=back

=head1 AUTHOR

Tatsuhiko Miyagawa

=head1 CONTRIBUTORS

Yoshiki Kurihara

Gosuke Miyashita

=head1 SEE ALSO

L<Plagger>, L<XML::Feed>

=cut
