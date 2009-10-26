package Plagger::Plugin::Filter::FormatText;

use HTML::TreeBuilder;
use HTML::FormatText;
use HTML::WikiConverter;

use strict;
use warnings;
use base qw( Plagger::Plugin );
use utf8;

our $VERSION = 0.04; 

sub register {
    my($self, $context) = @_;
    $context->register_hook(
        $self,  
        'update.entry.fixup' => \&filter,
    );
}

sub filter {
    my($self, $context, $args) = @_;
    my $entry = $args->{entry};
    #if ($entry->body->is_html || $self->conf->{always}){
    if ($entry->body =~ /<\w+>/ || $self->conf->{always}){
        my $tree      = HTML::TreeBuilder->new()->parse($entry->body);
        my $formatter = HTML::FormatText->new( lm => 0, rm => 998 );

        my $body = $formatter->format($tree);
        $entry->body($body);
        $context->log(info => "format $entry->{link}") if $entry->{link};
    }
}

1;
